scitype(::AbstractFloat,  ::MLJ) = Continuous
scitype(::Integer,        ::MLJ) = Count
scitype(::AbstractString, ::MLJ) = Textual

nlevels(c::Cat) = length(levels(c.pool))

function scitype(c::Cat, ::MLJ)
    nc = nlevels(c)
    return ifelse(c.pool.ordered, OrderedFactor{nc}, Multiclass{nc})
end

function scitype(A::CArr{T,N}, ::MLJ) where {T,N}
    nlevels = length(levels(A))
    S = ifelse(isordered(A), OrderedFactor{nlevels}, Multiclass{nlevels})
    T >: Missing && (S = Union{S,Missing})
    return AbstractArray{S,N}
end

Scitype(::Type{<:Integer},        ::MLJ) = Count
Scitype(::Type{<:AbstractFloat},  ::MLJ) = Continuous
Scitype(::Type{<:AbstractString}, ::MLJ) = Textual

## Helper functions

_int(::Missing)  = missing
_int(x::Integer) = x
_int(x::Cat)     = CategoricalArrays.order(x.pool)[x.level]
_int(x)          = Int(x) # NOTE: may throw InexactError

_float(y::Cat) = float(_int(y))
_float(y)      = float(y)

function _coerce_missing_warn(::Type{T}, from::Type) where T
    T >: Missing && return
    if from == Any
        @warn "Trying to coerce from `Any` to `$T` with categoricals.\n" *
              "Coerced to `Union{Missing,$T}` instead."
    else
        @warn "Trying to coerce from `$from` to `$T`.\n" *
              "Coerced to `Union{Missing,$T}` instead."
    end
    return
end

function _check_eltype(y, T, verb)
    E = eltype(y)
    E >: Missing && verb > 0 && _coerce_missing_warn(T, E)
end

function _check_tight(v::Arr, T, tight)
    if T >: Missing && tight && findfirst(ismissing, v) === nothing
        v = identity.(v)
    end
    return v
end

function _check_tight(v::CArr, T, tight)
    if T >: Missing && tight && findfirst(ismissing, v) === nothing
        v = get.(v)
    end
    return v
end
