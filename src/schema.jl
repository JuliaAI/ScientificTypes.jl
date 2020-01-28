struct Schema{names, types, scitypes, nrows} end

"""
    Schema(names, types, scitypes, nrows)

Constructor for a `Schema` object.
"""
function Schema(names::Tuple{Vararg{Symbol}}, types::Type{T},
                scitypes::Type{S}, nrows::Integer) where {T<:Tuple,S<:Tuple}
    return Schema{names, T, S, nrows}()
end

Schema(names, types, scitypes, nrows) =
    Schema{Tuple(Symbol.(names)), Tuple{types...}, Tuple{scitypes...}, nrows}()

if VERSION < v"1.1"
    fieldtypes(t) = Tuple(fieldtype(t, i) for i = 1:fieldcount(t))
end

function Base.getproperty(sch::Schema{names, types, scitypes, nrows},
                          field::Symbol) where {names, types, scitypes, nrows}
    if field === :names
        return names
    elseif field === :types
        return types === nothing ? nothing : fieldtypes(types)
    elseif field === :scitypes
        return scitypes === nothing ? nothing : fieldtypes(scitypes)
    elseif field === :nrows
        return nrows === nothing ? nothing : nrows
    else
        throw(ArgumentError("unsupported property for ScientificTypes.Schema"))
    end
end

Base.propertynames(sch::Schema) = (:names, :types, :scitypes, :nrows)

"""
    schema(X)

Inspect the column types and scitypes of an object.

```
julia> X = (ncalls=[1, 2, 4], mean_delay=[2.0, 5.7, 6.0])
julia> schema(X)
(names = (:ncalls, :mean_delay),
 types = (Int64, Float64),
 scitypes = (Count, Continuous))
```
"""
schema(X; kw...) = schema(X, Val(trait(X)); kw...)

# Fallback
schema(X, ::Val{:other}; kw...) =
    throw(ArgumentError("Cannot inspect the internal scitypes of "*
                        "an object with trait `:other`."))

# See MLJScientificTypes for a definition of schema specific for Tables.
# For those who develop their own convention and extension of
# TRAIT_FUNCTION_GIVEN_NAME, they need to ensure that `schema` is defined
# for all keys of that dictionary.

Base.show(io::IO, s::Schema) = print(io, "Schema{...}()")
