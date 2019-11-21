TRAIT_FUNCTION_GIVEN_NAME[:table] = Tables.istable

function scitype(X, ::Val, ::Val{:table})
    Xcol = Tables.columns(X)
    col_names = propertynames(Xcol)
    types = map(col_names) do name
        scitype(getproperty(Xcol, name))
    end
    return Table{Union{types...}}
end

function _nrows(X)
    if !Tables.columnaccess(X)
        return length(collect(X))
    else
        cols = Tables.columntable(X)
        !isempty(cols) || return 0
        return length(cols[1])
    end
end

function schema(X, ::Val{:table})
    s = Tables.schema(X)
    Xcol = Tables.columntable(X)
    names = s.names
    types = Tuple{s.types...}
    scitypes = Tuple{(scitype_union(getproperty(Xcol, name))
                              for name in names)...}
    return Schema(names, types, scitypes, _nrows(X))
end


## TABLE TYPE COERCION

function _coerce_col(X, name, types; args...)
    Xcol = Tables.columntable(X)
    y = getproperty(X, name)
    if haskey(types, name)
        # HACK isa LazyArrays.ApplyArray, see issue #49
        if startswith("$(typeof(y))", "LazyArrays.")
            y = convert(Vector, y)
        end
        return coerce(y, types[name]; args...)
    else
        return y
    end
end

"""
    coerce(X, col1=>scitype1, col2=>scitype2, ... ; verbosity=1)
    coerce(X, d::AbstractDict; verbosity=1)

Return a copy of the table `X` with the scitypes of the specified
columns coerced to those specified, or to missing-value versions of
these scitypes, with warnings issued (for positive `verbosity`).
Alternatively, the specifications can be wrapped in a dictionary.


### Example

```julia
using CategoricalArrays, DataFrames, Tables
X = DataFrame(name=["Siri", "Robo", "Alexa", "Cortana"],
              height=[152, missing, 148, 163],
              rating=[1, 5, 2, 1])
coerce(X, :name=>Multiclass, :height=>Continuous, :rating=>OrderedFactor)

See also [`scitype`](@ref), [`schema`](@ref).
```

"""
function coerce(X, pairs::Pair{Symbol}...; verbosity=1)
    trait(X) == :table ||
        error("Non-tabular data encountered or Tables pkg not loaded.")
    names = Tables.schema(X).names
    coltable = NamedTuple{names}(_coerce_col(X, name, Dict(pairs);
                                             verbosity=verbosity)
                                 for name in names)
    return Tables.materializer(X)(coltable)
end
coerce(X, types::Dict; kw_args...) = coerce(X, (p for p in types)...)


# code removed because some tables are AbstractVector:

# Attempt to coerce a vector using a dictionary with a single key (corner case):
# function coerce(types::Dict, v::AbstractVector; verbosity=1)
#     kys = keys(types)
#     length(kys) == 1 || error("Cannot coerce a vector using a multi-keyed dictionary of types. ")
#     key = first(kys)
#     return coerce(types[key], v; verbosity=verbosity)
# end
