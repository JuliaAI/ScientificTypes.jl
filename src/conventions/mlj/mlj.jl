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
function coerce(y::AbstractVector{<:Union{Missing,AbstractFloat}}, T::Type{Continuous};
                verbosity=1)
    eltype(y) >: Missing && verbosity > 0 && _coerce_missing_warn(T)
    return y
end

function coerce(y::AbstractVector{<:Union{Missing,Real}}, T::Type{Continuous}; verbosity=1)
    eltype(y) >: Missing && verbosity > 0 && _coerce_missing_warn(T)
    return float(y)
end

# NOTE: case where the data may have been badly encoded and resulted in an Any[] vector
# a user should proceed with caution here in particular:
# - if at one point it encounters a type for which there is no AbstractFloat such
# as a String, it will error.
# - if at one point it encounters a Char it will **not** error but return a float
# corresponding to the Char (e.g. 65.0  for 'A') whence the warning
function coerce(y::AbstractVector, T::Type{Continuous}; verbosity=1)
    has_missings = findfirst(ismissing, y) !== nothing
    has_missings && verbosity > 0 && _coerce_missing_warn(T)
    has_chars    = findfirst(e->isa(e,Char), y) !== nothing
    has_chars && verbosity > 0 && @warn "Char values will be coerced to " *
                                        "AbstractFloat (e.g. 'A' to 65.0)."
    return float.(y)
end


## COERCE VECTOR TO COUNT

_int(::Missing)  = missing
_int(x::Integer) = x
_int(x) = Int(x) # may throw InexactError

# no-op case
function coerce(y::AbstractVector{<:Union{Missing,Integer}}, T::Type{Count}; verbosity=1)
    eltype(y) >: Missing && verbosity > 0 && _coerce_missing_warn(T)
    return y
end

# NOTE: this will error if it encounters things like 1.5 or 1//2 (InexactError)
function coerce(y::AbstractVector{<:Union{Missing,Real}}, T::Type{Count}; verbosity=1)
    eltype(y) >: Missing && verbosity > 0 && _coerce_missing_warn(T)
    return _int.(y)
end

# NOTE: case where the data may have been badly encoded and resulted in an Any[] vector
# a user should proceed with caution here (see comment earlier)
function coerce(y::AbstractVector, T::Type{Count}; verbosity=1)
    has_missings = findfirst(ismissing, y) !== nothing
    has_missings && verbosity > 0 && _coerce_missing_warn(T)
    has_chars    = findfirst(e->isa(e,Char), y) !== nothing
    has_chars && verbosity > 0 && @warn "Char values will be coerced to Integer " *
                                        "(e.g. 'A' to 65)."
    return _int.(y)
end
