scitype(::AbstractFloat,  ::MLJ) = Continuous
scitype(::Integer,        ::MLJ) = Count
scitype(::AbstractString, ::MLJ) = Textual

# ## IMPLEMENT PERFORMANCE BOOSTING FOR ARRAYS

Scitype(::Type{<:Integer}, ::MLJ)        = Count
Scitype(::Type{<:AbstractFloat}, ::MLJ)  = Continuous
Scitype(::Type{<:AbstractString}, ::MLJ) = Textual

## UTILS FOR COERCION TO INT

_int(::Missing)  = missing
_int(x::Integer) = x
_int(x::CategoricalElement) = CategoricalArrays.order(x.pool)[x.level]
_int(x) = Int(x) # NOTE: may throw InexactError

## COERCE ARRAY TO COUNT

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

## COERCE ARRAY TO CONTINUOUS

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

## COERCE CATEGORICAL ARRAY TO COUNT OR CONTINUOUS

# CArr -> Float via `float(_int)`
# NOTE: the CArr{Any} case is treated separately below
function coerce(y::CArr{T}, T2::Type{<:Union{Missing,C}};
                verbosity::Int=1, tight::Bool=false
                ) where T where C <: Union{Count,Continuous}
    # here we broadcast and so we don't need to tighten
    iy = _int.(y)
    _check_eltype(iy, T2, verbosity)
    C == Count && return iy
    return float(iy)
end

## COERCION OF (CATEGORICAL) ARRAY OF {ANY} TO COUNT OR CONTINUOUS

_float(y::CategoricalElement) = float(_int(y))
_float(y) = float(y)

# NOTE: case where the data may have been badly encoded and resulted
# in an Any[] array a user should proceed with caution here in particular:
#   - if at one point it encounters a type for which there is no AbstractFloat
#     such as a String, it will error.
#   - if at one point it encounters a Char it will **not** error but return a
#     float corresponding to the Char (e.g. 65.0 for 'A') whence the warning
# Also the performances of this should not be expected to be great.
function coerce(y::Union{CArr{Any},Arr{Any}}, T::Type{<:Union{Missing,C}};
                verbosity=1) where C <: Union{Count,Continuous}
    has_missings = findfirst(ismissing, y) !== nothing
    has_missings && verbosity > 0 && _coerce_missing_warn(T, Any)
    has_chars    = findfirst(e -> isa(e, Char), y) !== nothing
    # Count case
    if C == Count
        has_chars && verbosity > 0 && @warn "Char values will be coerced to " *
                                            "Integer (e.g. 'A' to 65)."
        return _int.(y)
    end
    # Continuous case
    has_chars && verbosity > 0 && @warn "Char values will be coerced to " *
                                        "AbstractFloat (e.g. 'A' to 65.0)."
    return _float.(y)
end
