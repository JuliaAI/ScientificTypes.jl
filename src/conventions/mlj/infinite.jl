#=
Functionalities to coerce to T <: Union{Missing,<:Infinite}
=#

## ARRAYS

# Arr{Int} -> {Count} is no-op
function coerce(y::Arr{T}, T2::Type{<:Union{Missing,Count}};
                verbosity::Int=1, tight::Bool=false
                ) where T <: Union{Missing,Integer}
    y = _check_tight(y, T, tight)
    _check_eltype(y, T2, verbosity)
    return y
end

# Arr{Real \ Int} -> {Count} via `_int`, may throw InexactError
function coerce(y::Arr{T}, T2::Type{<:Union{Missing,Count}};
                verbosity::Int=1, tight::Bool=false
                ) where T <: Union{Missing,Real}
    y = _check_tight(y, T, tight)
    _check_eltype(y, T2, verbosity)
    return _int.(y)
end

# Arr{Float} -> Float is no-op
function coerce(y::Arr{T}, T2::Type{<:Union{Missing,Continuous}};
                verbosity::Int=1, tight::Bool=false
                ) where T <: Union{Missing,AbstractFloat}
    y = _check_tight(y, T, tight)
    _check_eltype(y, T2, verbosity)
    return y
end

# Arr{Real \ {Float}} -> Float via `float`
function coerce(y::Arr{T}, T2::Type{<:Union{Missing,Continuous}};
                verbosity::Int=1, tight::Bool=false
                ) where T <: Union{Missing,Real}
    y = _check_tight(y, T, tight)
    _check_eltype(y, T2, verbosity)
    return float(y)
end

## CATEGORICAL ARRAYS

# CArr -> Count/Continuous via `_int` or `float(_int)`
function coerce(y::CArr, T2::Type{<:Union{Missing,C}};
                verbosity::Int=1, tight::Bool=false
                ) where C <: Union{Count,Continuous}
    # here we broadcast and so we don't need to tighten
    iy = _int.(y)
    _check_eltype(iy, T2, verbosity)
    C == Count && return iy
    return float(iy)
end

## ARRAY OF ANY
# Note: in the categorical case, we don't care, because we broadcast anyway.
# see CArr --> C above.
#
# this is the case where the data may have been badly encoded and resulted
# in an Any[] array a user should proceed with caution here in particular:
#   - if at one point it encounters a type for which there is no AbstractFloat
#     such as a String, it will error.
#   - if at one point it encounters a Char it will **not** error but return a
#     float corresponding to the Char (e.g. 65.0 for 'A') whence the warning
# Also the performances of this should not be expected to be great as we're
# broadcasting an operation on the full vector.
function coerce(y::Arr{Any}, T::Type{<:Union{Missing,C}};
                verbosity=1, tight::Bool=false
                ) where C <: Union{Count,Continuous}
    op, num   = ifelse(C == Count, (_int, "65"), (_float, "65.0"))
    has_chars = findfirst(e -> isa(e, Char), y) !== nothing
    if has_chars && verbosity > 0
        @warn "Char value encountered, such value will be coerced according to the corresponding numeric value (e.g. 'A' to $num)."
    end
    # broadcast the operation
    c = op.(y)
    # if the container type has  missing but not target, warn
    if (eltype(c) >: Missing) && !(T >: Missing) && verbosity > 0
        @warn "Trying to coerce from `Any` to `$T` but encountered missing values.\nCoerced to `Union{Missing,$T}` instead."
    end
    return c
end
