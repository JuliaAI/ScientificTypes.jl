scitype(::AbstractFloat, ::Val{:mlj}) = Continuous
scitype(::Integer, ::Val{:mlj}) = Count

_coerce_missing_warn(T) =
    @warn "Missing values encountered coercing scitype to $T.\n"*
          "Coerced to Union{Missing,$T} instead. "


## COERCE VECTOR TO CONTINUOUS

"""
    coerce(v::AbstractVector, T; verbosity=1)

Coerce the julia types of elements of `v` to ensure the returned
vector has `T` or `Union{Missing,T}` as the union of its element
scitypes.

A warning is issued if missing values are encountered, unless
`verbosity` is `0` or less.

    julia> v = coerce([1, missing, 5], Continuous)
    3-element Array{Union{Missing, Float64},1}:
     1.0
     missing
     5.0

    julia> scitype(v)
    AbstractArray{Union{Missing,Continuous}, 1}

See also [`scitype`](@ref), [`scitype_union`](@ref).

"""
coerce(y::AbstractVector{<:Number}, T::Type{Continuous}; verbosity=1) = float(y)
function coerce(y::V, T::Type{Continuous}; verbosity=1) where {N<:Number,
                                         V<:AbstractVector{Union{N,Missing}}}
    verbosity > 0 && _coerce_missing_warn(T)
    return float(y)
end
function coerce(y::AbstractVector{S}, T::Type{Continuous}; verbosity=1) where S
    for el in y
        if ismissing(el)
            verbosity > 0 && _coerce_missing_warn(T)
            break
        end
    end
    return float.(y)
end

## COERCE VECTOR TO COUNT

_int(::Missing) = missing
_int(x) = Int(x)

coerce(y::AbstractVector{<:Integer}, T::Type{Count}; verbosity=1) = y
function coerce(y::V, T::Type{Count}; verbosity=1) where {R<:Real,
                                             V<:AbstractVector{Union{R,Missing}}}
    verbosity > 0 &&_coerce_missing_warn(T)
    return convert(Vector{Union{Missing,Int}}, y)
end
function coerce(y::V, T::Type{Count}; verbosity=1) where {S,
                                            V<:AbstractVector{S}}
    for el in y
        if ismissing(el)
            verbosity > 0 && _coerce_missing_warn(T)
            break
        end
    end
    return _int.(y)
end

include("auto_types.jl")
