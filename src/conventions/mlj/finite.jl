nlevels(c::CategoricalValue) = length(levels(c.pool))
nlevels(c::CategoricalString) = length(levels(c.pool))

scitype(c::CategoricalValue, ::Val{:mlj}) =
    c.pool.ordered ? OrderedFactor{nlevels(c)} : Multiclass{nlevels(c)}
scitype(c::CategoricalString, ::Val{:mlj}) =
    c.pool.ordered ? OrderedFactor{nlevels(c)} : Multiclass{nlevels(c)}

function coerce(v, ::Type{T2}; verbosity=1) where T2 <: Union{Missing,Finite}
    su = scitype_union(v)
    if su >: Missing && !(T2 >: Missing)
        verbosity > 0 && _coerce_missing_warn(T2)
    end
    if su <: T2
        return v
    end
    return categorical(v, true, ordered=T2 <: Union{Missing,OrderedFactor})
end

## PERFORMANT SCITYPES FOR ARRAYS

const CatArr{T,N,V} = CategoricalArray{T,N,<:Any,V}

function scitype(A::CatArr{T,N,V}, ::Val{:mlj}) where {T,N,V}
    nlevels = length(levels(A))
    if isordered(A)
        S = OrderedFactor{nlevels}
    else
        S = Multiclass{nlevels}
    end
    if T != V # missing values
        Atight = broadcast(identity, A)
        if !(Atight isa CatArr{V,N,V}) # missings remain
            S = Union{S,Missing}
        end
    end
    return AbstractArray{S,N}
end
