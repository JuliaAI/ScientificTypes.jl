using .CategoricalArrays

nlevels(c::CategoricalValue) = length(levels(c.pool))
nlevels(c::CategoricalString) = length(levels(c.pool))

scitype(c::CategoricalValue, ::Val{:mlj}) =
    c.pool.ordered ? OrderedFactor{nlevels(c)} : Multiclass{nlevels(c)}
scitype(c::CategoricalString, ::Val{:mlj}) =
    c.pool.ordered ? OrderedFactor{nlevels(c)} : Multiclass{nlevels(c)}

# coerce vector to Multiclass or OrderedFactor
for (T, ordered) in ((Multiclass, false), (OrderedFactor, true))
    @eval function coerce(y, ::Type{$T}; verbosity=1)
        su = scitype_union(y)
        if su >: Missing
            verbosity > 0 && _coerce_missing_warn($T)
        end
        if su <: $T
            return y
        else
            return categorical(y, true, ordered = $ordered)
        end
    end
end

# 
# function coerce(v::AbstractVector{<:Real}, T::Type{OrderedFactor{N}}) where N
#     su = scitype_union(y)
#     if su >: Missing
#         verbosity > 0 && _coerce_missing_warn(OrderedFactor{N})
#     end
#     if su <: OrderedFactor
# end
