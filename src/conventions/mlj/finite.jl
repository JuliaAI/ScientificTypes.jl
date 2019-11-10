nlevels(c::CategoricalValue) = length(levels(c.pool))
nlevels(c::CategoricalString) = length(levels(c.pool))

scitype(c::CategoricalValue, ::Val{:mlj}) =
    c.pool.ordered ? OrderedFactor{nlevels(c)} : Multiclass{nlevels(c)}
scitype(c::CategoricalString, ::Val{:mlj}) =
    c.pool.ordered ? OrderedFactor{nlevels(c)} : Multiclass{nlevels(c)}

# for temporary hack below:
get_(x) = get(x)
get_(::Missing) = missing

# v is already categorical here, but may need `ordering` changed
function _finalize_finite_coerce(v, verbosity, T2)
    su = scitype_union(v)
    if su >: Missing && !(T2 >: Missing)
        verbosity > 0 && _coerce_missing_warn(T2)
    end
    if su <: T2
        return v
    end
    return categorical(v, true, ordered=T2<:Union{Missing,OrderedFactor})
end

# if v is not a CategoricalArray:
function coerce(v::AbstractArray,
                ::Type{T2}; verbosity=1) where T2<:Union{Missing,Finite}
    vtight = broadcast(identity, v)
    vcat = categorical(vtight, true, ordered=T2<:Union{Missing,OrderedFactor})
    return _finalize_finite_coerce(vcat, verbosity, T2)
end

# if v is a CategoricalArray except CategoricalArray{Any}:
coerce(v::CategoricalArray,
       ::Type{T2}; verbosity=1) where T2<:Union{Missing,Finite} =
           _finalize_finite_coerce(v, verbosity, T2)

# if v is a CategoricalArray{Any}
function coerce(v::CategoricalArray{Any},
                ::Type{T2}; verbosity=1)  where T2<:Union{Missing,Finite}

    # AFTER CategoricalArrays 0.7.2 IS RELEASED:
    # return _finalize_finite_coerce(broadcast(identity, v), verbosity, T2)

    # TEMPORARY HACK:
    levels_ = levels(v)
    isordered_ = isordered(v)
    vraw = broadcast(get_, v)
    v_ = categorical(vraw, true, ordered=isordered_)
    levels!(v_, levels_)
    return _finalize_finite_coerce(v_, verbosity, T2)
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
