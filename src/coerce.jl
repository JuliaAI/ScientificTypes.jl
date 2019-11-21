function _coerce_col(X, name, types; args...)
    y = getproperty(X, name)
    if haskey(types, name)
        # HACK isa LazyArrays.ApplyArray, see issue #49
        if is_type(y, :LazyArrays, :ApplyArray)
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
    names  = Tables.schema(X).names
    dpairs = Dict(pairs)
    X_ct   = Tables.columntable(X)
    ct_new = (_coerce_col(X_ct, col, dpairs; verbosity=verbosity) for col in names)
    return Tables.materializer(X)(NamedTuple{names}(ct_new))
end
coerce(X, types::Dict; kw_args...) = coerce(X, (p for p in types)...; kw_args...)


"""
coerce!(X, ...)

Same as [`coerce`](@ref) except it does the modification in place provided `X`
supports in-place modification (at the moment, only the DataFrame! does).
An error is thrown otherwise. The arguments are the same as `coerce`.
"""
function coerce!(X, args...; kwargs...)
    # DataFrame --> coerce_dataframe! (see convention)
    is_type(X, :DataFrames, :DataFrame) && return coerce_df!(X, args...; kwargs...)
    # Everything else
    throw(ArgumentError("In place coercion not supported for $(typeof(X)). Try `coerce` instead."))
end
coerce!(X, types::Dict; kwargs...) = coerce!(X, (p for p in types)..., kwargs...)

function coerce_df!(df, pairs::Pair{Symbol}...; verbosity=1)
    names = Tables.schema(df).names
    types = Dict(pairs)
    for name in names
        name in keys(types) || continue
        df[!, name] = coerce(df[!, name], types[name])
    end
    return df
end
