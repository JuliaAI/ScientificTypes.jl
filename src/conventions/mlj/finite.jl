nlevels(c::CategoricalElement) = length(levels(c.pool))

scitype(c::CategoricalElement, ::MLJ) =
    c.pool.ordered ? OrderedFactor{nlevels(c)} : Multiclass{nlevels(c)}

# v is already categorical here, but may need `ordering` changed
function _finalize_finite_coerce(v, verbosity, T)
    elst = elscitype(v)
    if elst >: Missing && !(T >: Missing)
        verbosity > 0 && _coerce_missing_warn(T)
    end
    if elst <: T
        return v
    end
    return categorical(v, ordered=nonmissing(T)<:OrderedFactor)
end

# if v is an Array (not a CategoricalArray):
# NOTE: if Arr{Any} then categorical will  have eltype Union{Missing,T} even
# if there are no missing values
function coerce(v::Arr{T}, ::Type{T2}; verbosity=1
                ) where T where T2 <: Union{Missing,Finite}
    vcat = categorical(v, ordered=nonmissing(T2)<:OrderedFactor)
    return _finalize_finite_coerce(vcat, verbosity, T2)
end

# if v is a CategoricalArray except CategoricalArray{Any}:
function coerce(v::CArr{T}, ::Type{T2}; verbosity=1
                ) where T where T2 <: Union{Missing,Finite}
    return _finalize_finite_coerce(v, verbosity, T2)
end

## PERFORMANT SCITYPES FOR ARRAYS

function scitype(A::CArr{T,N}, ::MLJ) where {T,N}
    nlevels = length(levels(A))
    if isordered(A)
        S = OrderedFactor{nlevels}
    else
        S = Multiclass{nlevels}
    end
    T >: Missing && (S = Union{S,Missing})
    return AbstractArray{S,N}
end
