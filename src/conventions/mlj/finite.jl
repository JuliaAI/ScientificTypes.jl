nlevels(c::CategoricalValue) = length(levels(c.pool))
nlevels(c::CategoricalString) = length(levels(c.pool))

scitype(c::CategoricalValue, ::MLJ) =
    c.pool.ordered ? OrderedFactor{nlevels(c)} : Multiclass{nlevels(c)}
scitype(c::CategoricalString, ::MLJ) =
    c.pool.ordered ? OrderedFactor{nlevels(c)} : Multiclass{nlevels(c)}

# for temporary hack below:
get_(x) = get(x)
get_(::Missing) = missing

# v is already categorical here, but may need `ordering` changed
function _finalize_finite_coerce(v, verbosity, T2)
    elst = elscitype(v)
    if elst >: Missing && !(T2 >: Missing)
        verbosity > 0 && _coerce_missing_warn(T2)
    end
    if elst <: T2
        return v
    end
    return categorical(v, true, ordered=nonmissing(T2)<:OrderedFactor)
end

# if v is not a CategoricalArray:
function coerce(v::Arr{T}, ::Type{T2}; verbosity=1
                ) where T where T2<:Union{Missing,Finite}
    if T >: Missing && !(has_missings(v))
        # if there are no true missing, form a tight `v`
        v = identity.(v)
    end
    vcat = categorical(v, true, ordered=nonmissing(T2)<:OrderedFactor)
    return _finalize_finite_coerce(vcat, verbosity, T2)
end

# if v is a CategoricalArray except CategoricalArray{Any}:
function coerce(v::CategoricalArray, ::Type{T2}; verbosity=1
                ) where T2<:Union{Missing,Finite}
    return _finalize_finite_coerce(v, verbosity, T2)
end

# if v is a CategoricalArray{Any} (a bit of a hack):
function coerce(v::CategoricalArray{Any}, ::Type{T2}; verbosity=1
                ) where T2<:Union{Missing,Finite}
    levels_    = levels(v)
    isordered_ = isordered(v)
    vraw       = broadcast(get_, v)
    v_         = categorical(vraw, true, ordered=isordered_)
    levels!(v_, levels_)
    return _finalize_finite_coerce(v_, verbosity, T2)
end


## PERFORMANT SCITYPES FOR ARRAYS

const CatArr{T,N,V} = CategoricalArray{T,N,<:Any,V}

function scitype(A::CatArr{T,N,V}, ::MLJ) where {T,N,V}
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
