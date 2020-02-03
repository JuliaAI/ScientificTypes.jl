module ScientificTypes

# Type exports
export Convention
# re-export-able types and methods
export Scientific, Found, Unknown, Known, Finite, Infinite,
       OrderedFactor, Multiclass, Count, Continuous, Textual,
       Binary, ColorImage, GrayImage, Image, Table
export scitype, scitype_union, elscitype, nonmissing, trait

# utils (should not be re-exported)
export TRAIT_FUNCTION_GIVEN_NAME, set_convention

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

abstract type   Infinite <: Known end
abstract type  Finite{N} <: Known end
abstract type Image{W,H} <: Known end
struct           Textual <: Known end
struct          Table{K} <: Known end

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

Set the current convention to `C`.
"""
set_convention(C::Convention) = (CONVENTION[] = C; nothing)

"""
    convention()

Return the current convention.
"""
function convention()::Convention
    C = CONVENTION[]
    if C isa NoConvention
        @warn "No convention specified. Did you forget to use the " *
              "`set_convention` function?"
    end
    return C
end

# -------------------------------------------------------------------
# trait & info

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

# -----------------------------------------------------------------
# nonmissing

if VERSION < v"1.3"
    # see also discourse.julialang.org/t/get-non-missing-type-in-the-case-of-parametric-type/29109
    """
        nonmissingtype(TT)

    Return the type `T` if `TT = Union{Missing,T}` for some `T` and return `TT`
    otherwise.
    """
    function nonmissingtype(::Type{T}) where T
        return T isa Union ? ifelse(T.a == Missing, T.b, T.a) : T
    end
end
nonmissing = nonmissingtype

# -----------------------------------------------------------------
# Constructor for table scientific type

"""
Table(...)

Constructor for the `Table` scientific type with:

```
Table(S1, S2, ..., Sn) <: Table
```

where  `S1, ..., Sn` are the scientific type of the table's columns which
are expected to be represented by abstract vectors.
"""
Table(Ts::Type{<:Scientific}...) = Table{<:Union{(Arr{<:T,1} for T in Ts)...}}

# -----------------------------------------------------------------
# scitype

include("scitype.jl")

end # module
