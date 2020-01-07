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
function coerce(y::Arr{<:Union{Missing,Integer}},
                T::Type{<:Union{Missing,Count}}; verbosity=1)
    _check_eltype(y, T, verbosity)
    return y
end

# Arr{Real \ Int} -> {Count} via `_int`, may throw InexactError
function coerce(y::Arr{<:Union{Missing,Real}},
                T::Type{<:Union{Missing,Count}}; verbosity=1)
    _check_eltype(y, T, verbosity)
    return _int.(y)
end

## COERCE ARRAY TO CONTINUOUS

# Arr{Float} -> Float is no-op
function coerce(y::Arr{<:Union{Missing,AbstractFloat}},
                T::Type{<:Union{Missing,Continuous}};
                verbosity=1)
    _check_eltype(y, T, verbosity)
    return y
end

# Arr{Real \ {Float}} -> Float via `float`
function coerce(y::Arr{<:Union{Missing,Real}},
                T::Type{<:Union{Missing,Continuous}}; verbosity=1)
    _check_eltype(y, T, verbosity)
    return float(y)
end

## COERCE CATEGORICAL ARRAY TO COUNT OR CONTINUOUS

# CArr -> Float via `float(_int)`
# NOTE: the CArr{Any} case is treated separately below
function coerce(y::CArr, T::Type{<:Union{Missing,C}}; verbosity=1
                ) where C <: Union{Count,Continuous}
    _check_eltype(y, T, verbosity)
    iy = _int.(y)
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
    has_missings && verbosity > 0 && _coerce_missing_warn(T)
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
