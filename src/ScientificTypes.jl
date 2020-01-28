module ScientificTypes

# Type exports
export Scientific, Found, Unknown, Known, Finite, Infinite,
       OrderedFactor, Multiclass, Count, Continuous, Textual,
       Binary, ColorImage, GrayImage
export Convention, Schema

export scitype, scitype_union, elscitype, schema, info, nonmissing
export convention, set_convention, trait, TRAIT_FUNCTION_GIVEN_NAME

# -------------------------------------------------------------------
# Scientific Types
#
# Found
# ├─ Known
# │  ├─ Finite
# │  │  ├─ Multiclass
# │  │  └─ OrderedFactor
# │  ├─ Infinite
# │  │  ├─ Continuous
# │  │  └─ Count
# │  ├─ Image
# │  │  ├─ ColorImage
# │  │  └─ GrayImage
# │  └─ Textual
# └─ Unknown
#

abstract type Found          end
abstract type Known <: Found end
struct      Unknown <: Found end

abstract type Infinite   <: Known end
abstract type Finite{N}  <: Known end
abstract type Image{W,H} <: Known end
struct         Textual   <: Known end

struct Continuous <: Infinite end
struct      Count <: Infinite end

struct    Multiclass{N} <: Finite{N} end
struct OrderedFactor{N} <: Finite{N} end

struct    GrayImage{W,H} <: Image{W,H} end
struct   ColorImage{W,H} <: Image{W,H} end

# aliases:
const Binary     = Finite{2}
const Scientific = Union{Missing,Found}

# convenience alias
const Arr = AbstractArray

# -------------------------------------------------------------------
# Convention

abstract type Convention end
struct NoConvention <: Convention end

const CONVENTION = Ref{Convention}(NoConvention())

"""
    set_convention(C)

Set the current convention to  `C`.
"""
set_convention(C::Type{<:Convention}) = (CONVENTION[] = C(); nothing)

"""
    convention()

Return the current convention.
"""
function convention()
    conv = CONVENTION[]
    if conv isa NoConvention
        @warn "No convention specified. Did you forget to use the " *
              "`set_convention` function?"
    end
    return conv
end

# -------------------------------------------------------------------
# trait & info
#
# Note that for every new trait, a corresponding `schema` function should
# be implemented, see schema.jl

const TRAIT_FUNCTION_GIVEN_NAME = Dict{Symbol,Function}()

"""
    trait(X)

Check `X` against traits specified in `TRAIT_FUNCTION_GIVEN_NAME` and returns
a symbol corresponding to the matching trait, or `:other` if `X` didn't match
any of the trait functions.
"""
function trait(X)::Symbol
    for (name, f) in TRAIT_FUNCTION_GIVEN_NAME
        f(X) && return name
    end
    return :other
end

"""
    info(X)

Return the metadata associated with some object `X`, typically a named tuple
keyed on a set of object traits.

*Notes on overloading:*: If the class of objects is detected by its type,
`info` can be overloaded in the usual way.  If the class of objects is detected
by the value of `ScientificTypes.trait(object)` - say if this value is
`:some_symbol` - then one should define a method
`info(object, ::Val{:some_symbol})`.
"""
info(X) = info(X, Val(trait(X)))

# -----------------------------------------------------------------
# nonmissing

if VERSION < v"1.3"
    # see also discourse.julialang.org/t/get-non-missing-type-in-the-case-of-parametric-type/29109
    """
        nonmissingtype(TT)

    Return the type `T` if the type is a `Union{Missing,T}` or `T`.
    """
    function nonmissingtype(::Type{T}) where T
        return T isa Union ? ifelse(T.a == Missing, T.b, T.a) : T
    end
end
nonmissing = nonmissingtype

# -----------------------------------------------------------------
# includes

include("scitype.jl")
include("schema.jl")

end # module
