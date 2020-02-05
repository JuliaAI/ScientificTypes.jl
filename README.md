# ScientificTypes

| [MacOS/Linux] | Coverage |
| :-----------: | :------: |
| [![Build Status](https://travis-ci.org/alan-turing-institute/ScientificTypes.jl.svg?branch=master)](https://travis-ci.org/alan-turing-institute/ScientificTypes.jl) | [![codecov.io](http://codecov.io/github/alan-turing-institute/ScientificTypes.jl/coverage.svg?branch=master)](http://codecov.io/github/alan-turing-institute/ScientificTypes.jl?branch=master) |

A light-weight, dependency-free Julia interface for implementing
conventions about the scientific interpretation of data.  This package
should only be used by developers who intend to define their own
scientific type convention.  The
[MLJScientificTypes.jl](https://github.com/alan-turing-institute/MLJScientificTypes.jl)
packages implements such a convention used in the
[MLJ](https://github.com/alan-turing-institute/MLJ.jl) universe.

### Contents

 - [Who is this repository for?](#who-is-this-repo-for)
 - [What's provided here?](#what-is-provided-here)
 - [Defining a new convention](#defining-a-new-convention)

*Note:* This component of the [MLJ
  stack](https://github.com/alan-turing-institute/MLJ.jl#the-mlj-universe)
  applies to MLJ versions 0.8.0 and higher. Prior to 0.8.0, tuning
  algorithms resided in
  [MLJ](https://github.com/alan-turing-institute/MLJ.jl).

## Who is this repository for?

The package makes the distinction between **machine type** and
**scientific type**:

* the _machine type_ is a Julia type the data is currently encoded as (e.g., `Float64`)
* the _scientific type_ is a type defined by this package which
  encapsulates how the data should be _interpreted_ (e.g., `Continuous` or `Multiclass`)

The distinction is useful because the same machine type is often used
to represent data with *differing* scientific interpretations - `Int`
is used for product numbers (a factor) but also for a person's weight
(a continuous variable) - while the same scientific
type is frequently represented by *different* machine types - both
`Int` and `Float64` are used to represent weights, for example.

The purpose of this package is to provide a mechanism for articulating
conventions around the scientific interpretation of data. With such a
convention in place, a numerical algorithm declares its data
requirements in terms of scientific types, the user has a convenient
way to check compliance of his data with that requirement, and the
developer understands precisely the constraints his data specification
places on the actual machine type of the data supplied.

## What is provided here?

**I.** ScientificTypes provides a hierarchy of Julia types
representing data types for use in method dispatch (e.g., for trait
values). Instances of the types play no role.

```
Found
├─ Known
│  ├─ Finite
│  │  ├─ Multiclass
│  │  └─ OrderedFactor
│  ├─ Infinite
│  │  ├─ Continuous
│  │  └─ Count
│  ├─ Image
│  │  ├─ ColorImage
│  │  └─ GrayImage
│  ├─ Table
│  └─ Textual
└─ Unknown
```

Some of these types are [parametric](#type-parameters).

The julia native `Missing` type is also regarded as a scientific
type. 

**II.** ScientificTypes provides a method `scitype` for articulating a
particular convention: `scitype(X)` is the scientific type of object
`X`.

For example, in the `MLJ` convention, implemented by
[MLJScientificTypes](https://github.com/alan-turing-institute/MLJScientificTypes.jl),
one has `scitype(3.14) = Continuous` and `scitype(42) = Count`.

The developer implementing a particular scientific type convention
[overloads](#defining-a-new-convention) the `scitype` method
appropriately. However, this package provides certain rudimentary
fallback behaviour, of which only the first should be altered by the
developer:

**Property 1.** `scitype(X) = Unknown`, unless `X` is a tuple, an
abstract array, or `missing`.

**Property 2.** The scitype of a `k`-tuple is `Tuple{S1, S2, ...,
Sk}` where `Sj` is the scitype of the `j`th element.

For example, in the `MLJ` convention:

```julia
julia> scitype((1, 4.5))
Tuple{Count, Continuous}
```

**Property 3.** The scitype of an `AbstractArray`, `A`, is
always`AbstractArray{U}` where `U` is the union of the scitypes of the
elements of `A`, with one exception: If `typeof(A) <:
AbstractArray{Union{Missing,T}}` for some `T` different from `Any`,
then the scitype of `A` is `AbstractArray{Union{Missing, U}}`, where
`U` is the union over all non-missing elements, **even if `A` has no
missing elements.**

The exception is made for performance reasons. 

```julia
julia> v = [1.3, 4.5, missing]
julia> scitype(v)
AbstractArray{Union{Missing, Continuous},1}
```

```julia
julia> scitype(v[1:2])
AbstractArray{Union{Missing, Continuous},1}
```


**III.** Scientific types exports two convenience methods,
`scitype_union` and `elscitype`, which act on arrays - query the
doc-strings for details - and exports the method stub `schema`f, for
defining the schema associated with tabular data.

### Type parameters

The types `Finite{N}`, `Multiclass{N}` and `OrderedFactor{N}` are all
parametrised by the number of levels `N`, while `Image{W,H}`,
`GrayImage{W,H}` and `ColorImage{W,H}` are all parametrised by the
image width and height dimensions, `(W, H)`. 

An object of scitype `Table{K}` is expected to have a notion of
"columns", which are `AbstractVector`s, and the intention of the type
parameter `K` is to encode the scientific type(s) of its
columns. Specifically, developers are requested to adhere to the
following:

**Tabular data convention.** If $scitype(X) <: Table$, then in fact

```julia
scitype(X) == Table{Union{scitype(c1), ..., scitype(cn)}}
```

where `c1`, `c2`, ..., `cn` are the columns of `X`. With this
definition, common type checks can be performed with tables.  For
instance, you could check that each column of `X` has an element
scitype that is either `Continuous` or `Finite`:

```@example 5
scitype(X) <: Table{<:Union{AbstractVector{<:Continuous}, AbstractVector{<:Finite}}}
```

A built-in `Table` constructor provides a shorthand for the right-hand side:

```@example 5
scitype(X) <: Table(Continuous, Finite)
```

Note that `Table(Continuous,Finite)` is a *type* union and not a `Table` *instance*.


## Defining a new convention

If you want to implement your own convention, you can consider the
[MLJScientificTypes.jl](https://github.com/alan-turing-institute/MLJScientificTypes.jl)
as a blueprint.

The steps below summarise the possible steps in defining such a convention:

* declare a new convention,
* add new scientific types,
* register any traits needed to define scitypes,
* add explicit `scitype` and `Scitype` definitions,
* optionally define `coerce` functions.

Each step is explained below taking the MLJ convention as an example.

### Naming the convention

In the module, define a

```julia
struct MyConvention <: ScientificTypes.Convention end
```

and add an init function with:

```julia
function __init__()
  ScientificTypes.set_convention(MyConvention())
end
```

Subsequently you will have functions dispatching over `::MyConvention` for
instance in the MLJ case:

```julia
ScientificTypes.scitype(::Integer, ::MLJ) = Count
```

### Adding explicit `scitype` declarations.

The `scitype` function declares the scientific type to be associated
with any given object, under the convention. Note this is not a
mapping of types to types but from *instances* to types. This is
because one may want to distinguish the scientific type of objects
having the same machine type. For example, in the `MLJ` convention,
some `CategoricalArrays.CategoricalValue` objects have the scitype
`OrderedFactor` but others are `Multiclass`. In CategoricalArrays.jl
the `ordered` attribute is not a type parameter and so can only be
extracted from instances.


**Property 1.** The fallback in every convention is `scitype(X) =
Unknown`, unless `X` is a tuple, an abstract array, or `missing`.

The scitype of `missing` is always `Missing` (the only machine type
also regarded as a scientific type. For the built-in definition of the
scitypes of tuples and arrays, see
[below](#the-scitype-of-tuples-and-arrays).


Here's a sample declaration from the `MLJ` convention to overide this
behaviour:

```julia
ScientificType.scitype(::Integer, ::MLJ) = Count
```


### Scientific types depending on traits

The scientific type to be attributed to an object might depend on the
evaluation of a boolean-valued trait function. There is a mechanism for
"registering" such traits to streamline trait-based dispatch of the
`scitype` method. This is best illustrated with an example.

In the MLJ convention, all containers that meet the
[`Tables.jl`](https://github.com/JuliaData/Tables.jl) interface are
deemed to have scitype `Table`. These are detected using the Tables.jl
trait `istable`. Our first step is to choose a name for the trait, in
	this case `:table`. Our `scitype` declaration then reads:

```
function ST.scitype(X, ::MLJ, ::Val{:table}; kw...)
   K = <some type depending on columns of X>
   return Table{K}
end
```

For this to work we need to register the trait, which means adding to
the `TRAIT_FUNCTION_GIVEN_NAME` dictionary, which should be performed
within the init function of the defining package:

```julia
function __init__()
    ScientificTypes.set_convention(MLJ())
    ScientificTypes.TRAIT_FUNCTION_GIVEN_NAME[:table] = Tables.istable
end
```

### Defining a `coerce` function

It may be very useful to define a function to coerce machine types so
as to correct an unintended scientific interpretation, according to a
given convention.  In the MLJ convention, this is implemented by the
`coerce` function.

For instance consider the simplified:

```julia
function coerce(y::AbstractArray{T}, T2::Type{<:Union{Missing,Continuous}}
                ) where T <: Union{Missing,Real}
    return float(y)
end
```

This maps an array of Real to an array of `AbstractFloat` (which are mapped to
`Continuous` in the MLJ convention).

In the case of tabular data, one might additionally define `coerce`
methods to selectively coerce data in specified columns. See
[MLJScientificType](https://github.com/alan-turing-institute/MLJScientificTypes.jl) for examples.


### The scitype of tuple and abstract arrays

**Property 2.** *Under any convention, the scitype of a `k`-tuple is a
`Tuple{S1, S2, ..., Sk}` where `Sj` is the scitype of the `j`th
element.

For example, in the `MLJ` convention:

```julia
julia> scitype((1, 4.5))
Tuple{Count, Continuous}
```

**Property 3.** *The scitype of an `AbstractArray`, `A`, is
always`AbstractArray{U}` where `U` is the union of the scitypes of the
elements of `A`, with one exception: If `typeof(A) <:
AbstractArray{Union{Missing,T}}` for some `T` different from `Any`,
then the scitype of `A` is `AbstractArray{Union{Missing, U}}`, where
`U` is the union over all non-missing elements,* **even if `A` has no
missing elements.**

This exception is made for performance reasons. If one wants to override it,
one uses `scitype(A, tight=true)`. In `MLJ` one has:

```julia
julia> v = [1.3, 4.5, missing]
julia> scitype(v)
AbstractArray{Union{Missing, Continuous},1}
```

```julia
julia> scitype(v[1:2])
AbstractArray{Union{Missing, Continuous},1}
```

```julia
julia> scitype(v[1:2], tight=true)
AbstractArray{Continuous,1}
```

**Performance note.** Computing type unions over large arrays is
expensive and, depending on the convention's implementation and the
array eltype, computing the scitype can be slow. In the common case
that the scitype of an array (according to the above definition) can
be determined from the machine type of the object alone, the
implementer of a new connvention can speed up compututations by
implementing a `Scitype` method.  Do `?ScientificTypes.Scitype` for
details.

In the case of array of eltype `Any` performance cannot be
improved. To speed up performance, replace `A` with
`broadcast(identity, A)` before computing its scitype.

