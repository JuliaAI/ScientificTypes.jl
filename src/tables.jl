using .Tables

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
    scitypes = Tuple{[scitype_union(getproperty(Xcol, name))
                              for name in names]...}
    return Schema(names, types, scitypes, _nrows(X))
end


## TABLE TYPE COERCION

function _coerce_col(X, name, types; args...)
    Xcol = Tables.columntable(X)
    y = getproperty(X, name)
    if haskey(types, name)
        return coerce(types[name], y; args...)
    else
        return y
    end
end

"""
    coerce(d::Dict, X)

Return a copy of the table `X` with each column `col` named in the
keys of `d` replaced with `coerce(d[col], col)`. A warning is issued
if missing values are encountered, unless `verbosity` is `0` or less.


"""
function coerce(types::Dict, X; verbosity=1)
    trait(X) == :table || error("Non-tabular data encountered or Tables pkg not loaded.")
    names = Tables.schema(X).names
    coltable = NamedTuple{names}(_coerce_col(X, name, types; verbosity=verbosity)
                                 for name in names)
    return Tables.materializer(X)(coltable)
end

# Attempt to coerce a vector using a dictionary with a single key (corner case):
function coerce(types::Dict, v::AbstractVector; verbosity=1)
    kys = keys(types)
    length(kys) == 1 || error("Cannot coerce a vector using a multi-keyed dictionary of types. ")
    key = first(kys)
    return coerce(types[key], v; verbosity=verbosity)
end
