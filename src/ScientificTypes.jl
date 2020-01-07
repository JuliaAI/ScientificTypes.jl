module ScientificTypes

export Scientific, Found, Unknown, Finite, Infinite
export OrderedFactor, Multiclass, Count, Continuous, Textual
export Binary, Table
export ColorImage, GrayImage
export scitype, scitype_union, elscitype, coerce, coerce!, schema
export info
export autotype

# re-export from CategoricalArrays:
export categorical

using Tables, CategoricalArrays, ColorTypes, PrettyTables

const CategoricalElement{U} =
    Union{CategoricalValue{<:Any,U},CategoricalString{U}}


# ## FOR DETECTING OBJECTS BASED ON TRAITS

# We define a "dynamically" extended function `trait`:

const TRAIT_FUNCTION_GIVEN_NAME = Dict()
function trait(X)
    for (name, f) in TRAIT_FUNCTION_GIVEN_NAME
        f(X) && return name
    end
    return :other
end

# Explanation: For example, if Tables.jl is loaded and one does
# `TRAIT_FUNCTION_GIVEN_NAME[:table] = Tables.is_table` then
# `trait(X)` returns `:table` on any Tables.jl table. There is an
# understanding here that no two trait functions added to the
# dictionary values can be simultaneously true on two julia objects.

# External packages should extend the dictionary
# TRAIT_FUNCTION_GIVEN_NAME in their __init__ function.


"""

    info(object)

Returns metadata associated with some object, typically a named tuple
keyed on a set of object traits.

*Notes on overloading:* If the class of objects is detected by its
type, `info` can be overloaded in the usual way.  If the class of
objects is detected by the value of `ScientificTypes.trait(object)` -
say if this value is `:some_symbol` - then one should define a method
`info(object, ::Val{:some_symbol})`.

"""
info(object) = info(object, Val(ScientificTypes.trait(object)))


# ## CONVENTIONS

abstract type Convention end
struct MLJ <: Convention end

const CONVENTION=[MLJ(),]
convention() = CONVENTION[1]

function set_convention(C)
    CONVENTION[1] = C()
    return nothing
end


# ## THE SCIENTIFIC TYPES

abstract type Found          end
abstract type Known <: Found end
struct      Unknown <: Found end

struct Textual <: Known end

abstract type Infinite <: Known    end
struct      Continuous <: Infinite end
struct           Count <: Infinite end

abstract type Finite{N} <: Known     end
struct    Multiclass{N} <: Finite{N} end
struct OrderedFactor{N} <: Finite{N} end

abstract type Image{W,H} <: Known      end
struct    GrayImage{W,H} <: Image{W,H} end
struct   ColorImage{W,H} <: Image{W,H} end

# aliases:
const Binary     = Finite{2}
const Scientific = Union{Missing,Found}

"""
    MLJScientificTypes.Table{K}

The scientific type for tabular data (a container `X` for which
`Tables.is_table(X)=true`).

If `X` has columns `c1, c2, ..., cn`, then, by definition,

    scitype(X) = Table{Union{scitype(c1), scitype(c2), ..., scitype(cn)}}

A special constructor of `Table` types exists:

    `Table(T1, T2, T3, ..., Tn) <: Table`

has the property that

    scitype(X) <: Table(T1, T2, T3, ..., Tn)

if and only if `X` is a table *and*, for every column `col` of `X`,
`scitype(col) <: AbstractVector{<:Tj}`, for some `j` between `1` and
`n`. Note that this constructor constructs a *type* not an instance,
as instances of scientific types play no role (except for missing).

    julia> X = (x1 = [10.0, 20.0, missing],
                x2 = [1.0, 2.0, 3.0],
                x3 = [4, 5, 6])

    julia> scitype(X) <: MLJBase.Table(Continuous, Count)
    false

    julia> scitype(X) <: MLJBase.Table(Union{Continuous, Missing}, Count)
    true

"""
struct Table{K} <: Known end
function Table(Ts...)
    Union{Ts...} <: Scientific ||
        error("Arguments of Table scitype constructor "*
              "must be scientific types. ")
    return Table{<:Union{[AbstractVector{<:T} for T in Ts]...}}
end

"""
is_type(obj, spkg, stype)

This is a way to check that an object `obj` is of a given type that may come
from a package that is not loaded in the current environment.
For instance, say `DataFrames` is not loaded in the current environment, a
function from some package could still return a DataFrame in which case you
can check this with

```
is_type(obj, :DataFrames, :DataFrame)
```
"""
function is_type(obj, spkg::Symbol, stype::Symbol)
    # If the package is loaded, then it will just be `stype`
    # otherwise it will be `spkg.stype`
    rx = Regex("^($spkg\\.)?$stype")
    match(rx, "$(typeof(obj))") === nothing || return true
    return false
end


include("scitype.jl")
include("schema.jl")
include("coerce.jl")
include("autotype.jl")

## ACTIVATE DEFAULT CONVENTION

# and include code not requiring optional dependencies:

include("conventions/mlj/mlj.jl")
include("conventions/mlj/finite.jl")
include("conventions/mlj/images.jl")

end # module
