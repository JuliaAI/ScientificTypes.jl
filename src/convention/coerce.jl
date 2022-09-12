# ------------------------------------------------------------------------

# fallback method for coercing `AbstractArrays` to instances of a given
# scitype `T<:Union{Missing, <:ST.Known}`.
# This fallback fixes issue #39
coerce(X::AbstractArray,
       ::Type{T}; kw...) where {T<:Union{Missing,Nothing,ST.Known}} =
    throw(CoercionError(
        "Coercion of eltype `$(eltype(X))` to element scitype "*
        "`$T` is not supported. "))

# general fallback method for coercing `AbstractArrays` to scitype `T`
coerce(X::AbstractArray, ::Type{T}; kw...) where {T} =
    throw(CoercionError(
        "Coercion of eltype `$(eltype(X))` to element scitype "*
        "`$T` is not supported. Indeed, `$T` does not appear to be a "*
        "scientific type. "))


# ------------------------------------------------------------------------
# FINITE

# Supported types for CategoricalArray{T} under CategoricalArrays 0.9:
const SupportedTypes = Union{Char,AbstractString,Number}

# Arr{T} -> Finite for supported raw label types:
function coerce(v::Arr{T},
                ::Type{T2};
                verbosity::Int=1, tight::Bool=false
                ) where T <: Union{SupportedTypes, Missing} where T2 <: Union{Missing,Finite}
    v1    = _tighten_if_needed(v, T, tight)
    vcat = categorical(v1, ordered=nonmissing(T2)<:OrderedFactor)
    return _finalize_finite_coerce(vcat, verbosity, T2, T)
end

# Arr{T} -> Finite for all other types:
function coerce(v::Arr{T}, ::Type{T2};
                verbosity::Int=1, tight::Bool=true
                ) where T where T2 <: Union{Missing,Finite}
    tight || verbosity < 0 ||
        @warn "Forcing `tight=true`, as `$T` unsupported by "*
        "CategoricalArrays. "
    v1 = _tighten_if_needed(v, T, true)
    if v1 isa Arr{<:Union{SupportedTypes, Missing}}
        vcat = categorical(v1, ordered=nonmissing(T2)<:OrderedFactor)
        return _finalize_finite_coerce(vcat, verbosity, T2, T)
    end
    verbosity < 0 || @warn "Converting array elements to strings before "*
        "wrapping in a `CategoricalArray`, as `$T` unsupported by "*
        "CategoricalArrays. "
#   error("######################## GOT YOU ##########################")
    v_str = string.(v1)
    vcat = categorical(v_str, ordered=nonmissing(T2)<:OrderedFactor)
    return _finalize_finite_coerce(vcat, verbosity, T2, T)
end

# CArr{T} -> Finite
function coerce(v::CArr{T}, ::Type{T2};
                verbosity::Int=1, tight::Bool=false
                ) where T where T2 <: Union{Missing,Finite}
    v = _tighten_if_needed(v, T, tight)
    return _finalize_finite_coerce(v, verbosity, T2, T)
end

# ------------------------------------------------------------------------
# INFINITE

# Arr{Int} -> {Count} is no-op
function coerce(y::Arr{T}, T2::Type{<:Union{Missing,Count}};
                verbosity::Int=1, tight::Bool=false
                ) where T <: Union{Missing,Integer}
    y = _tighten_if_needed(y, T, tight)
    _check_eltype(y, T2, verbosity)
    return y
end

# Arr{Real \ Int} -> {Count} via `_int`, may throw InexactError
function coerce(y::Arr{T}, T2::Type{<:Union{Missing,Count}};
                verbosity::Int=1, tight::Bool=false
                ) where T <: Union{Missing,Real}
    y = _tighten_if_needed(y, T, tight)
    _check_eltype(y, T2, verbosity)
    return _int.(y)
end

# Arr{Float} -> Float is no-op
function coerce(y::Arr{T}, T2::Type{<:Union{Missing,Continuous}};
                verbosity::Int=1, tight::Bool=false
                ) where T <: Union{Missing,AbstractFloat}
    y = _tighten_if_needed(y, T, tight)
    _check_eltype(y, T2, verbosity)
    return y
end

# Arr{Real \ {Float}} -> Float via `float`
function coerce(y::Arr{T}, T2::Type{<:Union{Missing,Continuous}};
                verbosity::Int=1, tight::Bool=false
                ) where T <: Union{Missing,Real}
    y = _tighten_if_needed(y, T, tight)
    _check_eltype(y, T2, verbosity)
    return float(y)
end

# CArr -> Count/Continuous via `_int` or `float(_int)`
function coerce(y::CArr{T}, T2::Type{<:Union{Missing,C}};
                verbosity::Int=1, tight::Bool=false
                ) where T where C <: Infinite
    # here we broadcast and so we don't need to tighten
    iy = _int.(y)
    _check_eltype(iy, T2, verbosity)
    nonmissing(T2) == Count && return iy
    return float(iy)
end

const MaybeNumber = Union{Missing,AbstractChar,AbstractString}

# Textual => Count / Continuous via parse
function coerce(y::Arr{T}, T2::Type{<:Union{Missing,C}};
                verbosity::Int=1, tight::Bool=false
                ) where T <: MaybeNumber where C <: Infinite
    y = _tighten_if_needed(y, T, tight)
    _check_eltype(y, T2, verbosity)
    nonmissing(T2) == Count && return _int.(y)
    return _float.(y)
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
    # to float or to count?
    C2 = nonmissing(T)
    op, num   = ifelse(C2 == Count, (_int, "65"), (float, "65.0"))
    has_chars = findfirst(e -> isa(e, Char), y) !== nothing
    if has_chars && verbosity > 0
        @info "Char value encountered, such value will be coerced "*
            "according to the corresponding numeric value (e.g. 'A' to $num)."
    end
    # broadcast the operation
    c = op.(y)
    # if the container type has  missing but not target, warn
    if (eltype(c) >: Missing) && !(T >: Missing) && verbosity > 0
        @info "Trying to coerce from `Any` to `$T` "*
            "but encountered missing values.\n"*
            "Coerced to `Union{Missing,$T}` instead."
    end
    return c
end

# ------------------------------------------------------------------------
# UTILITIES

# If trying to  coerce to a non-union type `T` from a type that >: Missing
# for instance  coerce([missing,1,2], Continuous) will throw a warning
# to avoid that do coerce([missing,1,2], Union{Missing,Continuous})
# Special case with Any which is >: Missing depending on categorical case
function _coerce_missing_warn(::Type{T}, from::Type) where T
    T >: Missing && return
    if from == Any
        @info "Trying to coerce from `Any` to `$T` with categoricals.\n" *
              "Coerced to `Union{Missing,$T}` instead."
    else
        @info "Trying to coerce from `$from` to `$T`.\n" *
              "Coerced to `Union{Missing,$T}` instead."
    end
    return
end

# v is already categorical here, but may need `ordering` changed
function _finalize_finite_coerce(v, verbosity, T, fromT)
    elst = elscitype(v)
    if (elst >: Missing) && !(T >: Missing)
        verbosity > 0 && _coerce_missing_warn(T, fromT)
    end
    if elst <: T
        return v
    end
    return categorical(v, ordered=nonmissing(T)<:OrderedFactor)
end

_int(::Missing)  = missing
_int(x::Integer) = x
_int(x::Cat)     = levelcode(x)
_int(x)          = Int(x)                # NOTE: may throw InexactError

_int(x::AbstractString)   = Int(Meta.parse(x))    # NOTE: may fail
_float(x::AbstractString) = float(Meta.parse(x))
_float(x::Missing) = missing

function _check_eltype(y, T, verb)
    E = eltype(y)
    E >: Missing && verb > 0 && _coerce_missing_warn(T, E)
end

function _tighten_if_needed(v::Arr, T, tight)
    if T >: Missing && tight && findfirst(ismissing, v) === nothing
        v = identity.(v)
    end
    return v
end

function _tighten_if_needed(v::CArr, T, tight)
    if T >: Missing && tight && findfirst(ismissing, v) === nothing
        v = CategoricalArrays.DataAPI.unwrap.(v)
    end
    return v
end


## Images
F = Real
_2d{C} =AbstractArray{C} where C<:Union{ColorTypes.AbstractRGB, ColorTypes.Gray}

# Single Image

"""
    coerce(image::AbstractArray{<:Real, N}, I)

Given an array called `image` representing one or more images,
return a transformed version of the data so as to enforce an
appropriate scientific interpretation `I`:

single or collection ? | N | I                  | `scitype` of result
-----------------------|---|--------------------|----------------------------
single                 | 2 | `GrayImage`        | `GrayImage{W,H}`
single                 | 3 | `ColorImage`       | `ColorImage{W,H}`
collection             | 3 | `GrayImage`        | `AbstractVector{<:GrayImage}`
collection             | 4 (W x H x {1} x C)| `GrayImage` | `AbstractVector{<:GrayImage}`
collection             | 4 | `ColorImage`       | `AbstractVector{<:ColorImage}`

```
imgs = rand(10, 10, 3, 5)
v = coerce(imgs, ColorImage)

julia> typeof(v)
Vector{Matrix{ColorTypes.RGB{Float64}}}

julia> scitype(v)
AbstractVector{ColorImage{10, 10}}

```

"""
function coerce(y::Arr{<:F, 2}, T2::Type{GrayImage})
    return ColorTypes.Gray.(y)
end

function coerce(y::Arr{<:F, 3}, T2::Type{ColorImage})
    return broadcast(ColorTypes.RGB, y[:,:,1], y[:,:,2], y[:,:,3])
end

# Collection

_3Dcollection = AbstractArray{<:F, 3}       #for b/w images
_4Dcollection = AbstractArray{<:F, 4}       #for color images

function coerce(y::_3Dcollection, T2::Type{GrayImage})
    return [ColorTypes.Gray.(y[:,:,idx]) for idx=1:size(y,3)]
end

function coerce(y::_4Dcollection, T2::Type{GrayImage})
    size(y, 3) == 1 || error("Multiple color channels encountered. "*
                      "Perhaps you want to use `coerce(image_collection, ColorImage)`.")
    y = dropdims(y, dims=3)
    return [ColorTypes.Gray.(y[:,:,idx]) for idx=1:size(y,3)]
end

function coerce(y::_4Dcollection, T2::Type{ColorImage})
    return [broadcast(ColorTypes.RGB, y[:,:,1, idx], y[:,:,2,idx], y[:,:,3, idx]) for idx=1:size(y,4)]
end
