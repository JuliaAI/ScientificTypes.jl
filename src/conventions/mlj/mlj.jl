scitype(::AbstractFloat, ::Val{:mlj}) = Continuous
scitype(::Integer, ::Val{:mlj}) = Count

_coerce_missing_warn(T) =
    @warn "Missing values encountered coercing scitype to $T.\n"*
          "Coerced to Union{Missing,$T} instead. "


# ## IMPLEMENT PERFORMANCE BOOSTING FOR ARRAYS

Scitype(::Type{<:Integer}, ::Val{:mlj}) = Count
Scitype(::Type{<:AbstractFloat}, ::Val{:mlj}) = Continuous


## COERCE ARRAY TO CONTINUOUS

function coerce(y::AbstractArray{<:Union{Missing,AbstractFloat}},
                T::Type{<:Union{Missing,Continuous}};
                verbosity=1)
    eltype(y) >: Missing && verbosity > 0 && _coerce_missing_warn(T)
    return y
end

function coerce(y::AbstractArray{<:Union{Missing,Real}},
                T::Type{<:Union{Missing,Continuous}}; verbosity=1)
    eltype(y) >: Missing && verbosity > 0 && _coerce_missing_warn(T)
    return float(y)
end

# NOTE: case where the data may have been badly encoded and resulted
# in an Any[] array a user should proceed with caution here in
# particular: - if at one point it encounters a type for which there
# is no AbstractFloat such as a String, it will error.  - if at one
# point it encounters a Char it will **not** error but return a float
# corresponding to the Char (e.g. 65.0 for 'A') whence the warning
function coerce(y::AbstractArray, T::Type{<:Union{Missing,Continuous}}; verbosity=1)
    has_missings = findfirst(ismissing, y) !== nothing
    has_missings && verbosity > 0 && _coerce_missing_warn(T)
    has_chars    = findfirst(e->isa(e,Char), y) !== nothing
    has_chars && verbosity > 0 && @warn "Char values will be coerced to " *
                                        "AbstractFloat (e.g. 'A' to 65.0)."
    return float.(y)
end


## COERCE ARRAY TO COUNT

_int(::Missing)  = missing
_int(x::Integer) = x
_int(x) = Int(x) # may throw InexactError

# no-op case
function coerce(y::AbstractArray{<:Union{Missing,Integer}},
                T::Type{<:Union{Missing,Count}}; verbosity=1)
    eltype(y) >: Missing && verbosity > 0 && _coerce_missing_warn(T)
    return y
end

# NOTE: this will error if it encounters things like 1.5 or 1//2 (InexactError)
function coerce(y::AbstractArray{<:Union{Missing,Real}},
                T::Type{<:Union{Missing,Count}}; verbosity=1)
    eltype(y) >: Missing && verbosity > 0 && _coerce_missing_warn(T)
    return _int.(y)
end

# NOTE: case where the data may have been badly encoded and resulted
# in an Any[] array a user should proceed with caution here (see
# comment earlier)
function coerce(y::AbstractArray, T::Type{<:Union{Missing,Count}}; verbosity=1)
    has_missings = findfirst(ismissing, y) !== nothing
    has_missings && verbosity > 0 && _coerce_missing_warn(T)
    has_chars    = findfirst(e->isa(e,Char), y) !== nothing
    has_chars && verbosity > 0 && @warn "Char values will be coerced to Integer " *
                                        "(e.g. 'A' to 65)."
    return _int.(y)
end
