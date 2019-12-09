function _coerce_col(X, name, types_dict::Dict; args...)
    y = getproperty(X, name)
    if haskey(types_dict, name)
        return coerce(y, types_dict[name]; args...)
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

```julia
using CategoricalArrays, DataFrames, Tables
X = DataFrame(name=["Siri", "Robo", "Alexa", "Cortana"],
              height=[152, missing, 148, 163],
              rating=[1, 5, 2, 1])
coerce(X, :name=>Multiclass, :height=>Continuous, :rating=>OrderedFactor)
```

If a scientific type `T` is specified in place of a column name, then
*all* columns with scientific element type subtyping `Union{T,Missing}`
will be coerced to the new specified scitype:

```julia
X  = (x = [1, 2, 3],
      y = rand(3),
      z = [10, 20, 30])
Xfixed = coerce(X, Count=>Continuous)
schema(Xfixed).scitypes # (Continuous, Continuous, Continuous)
```

See also [`scitype`](@ref), [`schema`](@ref).

"""
function coerce(X, types_dict::Dict; verbosity=1)
    isempty(types_dict) && return X
    trait(X) == :table ||
        error("Non-tabular data encountered or Tables pkg not loaded.")
    names  = schema(X).names
    X_ct   = Tables.columntable(X)
    ct_new = (_coerce_col(X_ct, col, types_dict; verbosity=verbosity) for col in names)
    return Tables.materializer(X)(NamedTuple{names}(ct_new))
end

# allow passing pairs like :feature1=>Continuous
coerce(X, types_pairs::Pair{Symbol,<:Type}...; kw...) = coerce(X, Dict(types_pairs); kw...)

# allow passing rules like Count=>Continuous
function coerce(X, types_pairs::Pair{<:Type,<:Type}...; kw...)
    from_types = [tp.first  for tp in types_pairs]
    to_types   = [tp.second for tp in types_pairs]
    types_dict = Dict{Symbol,Type}()
    # retrieve the names that match the from_types
    sch = schema(X)
    for (name, st) in zip(sch.names, sch.scitypes)
        j   = findfirst(ft -> Union{Missing,ft} >: st, from_types)
        j === nothing && continue
        # if here then `name` is concerned by the change
        tt = to_types[j]
        types_dict[name] = ifelse(st >: Missing, Union{Missing,tt}, tt)
    end
    coerce(X, types_dict; kw...)
end

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
        # for DataFrames >= 0.19 df[!, name] = coerce(df[!, name], types(name))
        # but we want something that works more robustly... even for older DataFrames
        # the only way to do this is to use the `df.name = something` but we cannot use
        # setindex! which will throw a deprecation warning...
        name_str = "$name"
        ex = quote
            $df.$name = coerce($df.$name, $types[Symbol($name_str)])
        end
        eval(ex)
    end
    return df
end
