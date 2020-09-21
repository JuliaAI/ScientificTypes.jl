# ScientificTypes

| [MacOS/Linux] | Coverage |
| :-----------: | :------: |
| [![Build Status](https://travis-ci.org/alan-turing-institute/ScientificTypes.jl.svg?branch=master)](https://travis-ci.org/alan-turing-institute/ScientificTypes.jl) | [![codecov.io](http://codecov.io/github/alan-turing-institute/ScientificTypes.jl/coverage.svg?branch=master)](http://codecov.io/github/alan-turing-institute/ScientificTypes.jl?branch=master) |

A light-weight, dependency-free, Julia interface defining a collection
of types (without instances) for implementing conventions about the
scientific interpretation of data.

This package makes a distinction between **machine type** and
**scientific type** of a Julia object:

* The _machine type_ refers to the Julia type being used to represent
  the object (for instance, `Float64`).

* The _scientific type_ is one of the types defined in this package
  reflecting how the object should be _interpreted_ (for instance,
  `Continuous` or `Multiclass`).

The distinction is useful because the same machine type is often used
to represent data with *differing* scientific interpretations - `Int`
is used for product numbers (a factor) but also for a person's weight
(a continuous variable) - while the same scientific type is frequently
represented by *different* machine types - both `Int` and `Float64`
are used to represent weights, for example.

For implementation of a concrete convention assigning specific
scientific types (interpretations) to julia objects, see instead the
[MLJScientificTypes](https://github.com/alan-turing-institute/MLJScientificTypes.jl)
package.

```
Finite{N}
├─ Multiclass{N}
└─ OrderedFactor{N}

Infinite
├─ Continuous
└─ Count

Image{W,H}
├─ ColorImage{W,H}
└─ GrayImage{W,H}

ScientificTimeType
├─ ScientificDate
├─ ScientificTime
└─ ScientificDateTime

Table{K}

Textual

ManifoldPoint{MT}

Unknown
```

> Figure 1. The type hierarchy defined in ScientificTypes.jl (The Julia native `Missing` type is also regarded as a scientific type).

#### Contents

 - [Who is this repository for?](#who-is-this-repository-for)
 - [What's provided here?](#what-is-provided-here)
 - [Defining a new convention](#defining-a-new-convention)


## Who is this repository for?

This package should only be used by developers who intend to define
their own scientific type convention.  The
[MLJScientificTypes.jl](https://github.com/alan-turing-institute/MLJScientificTypes.jl)
package implements such a convention, first adopted in the
[MLJ](https://github.com/alan-turing-institute/MLJ.jl) universe, but
which can be adopted by other statistical and scientific software.

The purpose of this package is to provide a mechanism for articulating
conventions around the scientific interpretation of data. With such a
convention in place, a numerical algorithm declares its data
requirements in terms of scientific types, the user has a convenient
way to check compliance of his data with that requirement, and the
developer understands precisely the constraints his data specification
places on the actual machine type of the data supplied.

## What is provided here?

#### 1. Scientific types

ScientificTypes provides the new julia types appearing in Figure 1
above, signifying "scientific type" for use in method dispatch (e.g.,
for trait values). Instances of the types play no role.

The types `Finite{N}`, `Multiclass{N}` and `OrderedFactor{N}` are all
parametrised by the number of levels `N`, while `Image{W,H}`,
`GrayImage{W,H}` and `ColorImage{W,H}` are all parametrised by the
image width and height dimensions, `(W, H)`. The type
`ManifoldPoint{MT}`, intended for points lying on a manifold, is
parameterized by the type `MT` of the manifold to which the points
belong.

The scientific type `ScientificDate` is for representing dates (for
example, the 23rd of April, 2029), `ScientificTime` represents time
within a 24-hour day, while `ScientificDateTime` represents both a
time of day and date. These types mirror the types `Date`, `Time` and
`DateTime` from the Julia standard library Dates (and indeed, in the
[MLJ
convention](https://github.com/alan-turing-institute/MLJScientificTypes.jl)
the difference is only a formal one).

The type parameter `K` in `Table{K}` is for conveying the scientific
type(s) of a table's columns. See [More on the `Table`
type](#more-on-the-table-type).

The julia native types `Missing` and `Nothing` are also regarded as scientific
types. 

#### 2. The `scitype` and `Scitype` methods

ScientificTypes provides a method `scitype` for articulating a
particular convention: `scitype(X)` is the scientific type of object
`X`. For example, in the `MLJ` convention, implemented by
[MLJScientificTypes](https://github.com/alan-turing-institute/MLJScientificTypes.jl),
one has `scitype(3.14) = Continuous` and `scitype(42) = Count`.

> *Aside.* `scitype` is *not* a mapping of types to types but from
> *instances* to types. This is because one may want to distinguish
> the scientific type of objects having the same machine type. For
> example, in the `MLJ` convention, some
> `CategoricalArrays.CategoricalValue` objects have the scitype
> `OrderedFactor` but others are `Multiclass`. In CategoricalArrays.jl
> the `ordered` attribute is not a type parameter and so it can only
> be extracted from instances. 

The developer implementing a particular scientific type convention
[overloads](#defining-a-new-convention) the `scitype` method
appropriately. However, this package provides certain rudimentary
fallback behaviour; only Property 1 below should be altered by the
developer:

**Property 0.** `scitype(missing) = Missing` and `scitype(nothing) =
Nothing` (regarding `Missing` and `Nothing` as native scientific
types).

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

The exception is made for performance reasons. In `MLJ`:

```julia
julia> v = [1.3, 4.5, missing]
julia> scitype(v)
AbstractArray{Union{Missing, Continuous},1}
```

```julia
julia> scitype(v[1:2])
AbstractArray{Union{Missing, Continuous},1}
```

> *Performance note.* Computing type unions over large arrays is
> expensive and, depending on the convention's implementation and the
> array eltype, computing the scitype can be slow. In the common case
> that the scitype of an array can be determined from the machine type
> of the object alone, the implementer of a new connvention can speed
> up compututations by implementing a `Scitype` method.  Do
> `?ScientificTypes.Scitype` for details.


#### 3. Trait dictionary

Scientific types provides a dictionary `TRAIT_FUNCTION_GIVEN_NAME` for
registering names (symbols) for boolean-value trait functions used to
dispatch `scitype` in cases that direct type-dispatch is
inadequate. See [below](#adding-explicit-scitype-declarations) for
details.

#### 4. Convenience methods

Scientific provides the following convenience functions:

- `trait(X)` - return the trait name associated with the trait holding for `X`

- `set_convention(C)` - activate the convention named `C`

- `set_convention()` - inspect the active convention

- `scitype_union(A)` - return the union of the scitypes of all elements of iterable `A`

- `elscitype(A)` - return the "element scitype" of array `A`

Query the doc-strings for details.


#### More on the `Table` type

An object of scitype `Table{K}` is expected to have a notion of
"columns", which are `AbstractVector`s, and the intention of the type
parameter `K` is to encode the scientific type(s) of its
columns. Specifically, developers are requested to adhere to the
following:

**Tabular data convention.** If `scitype(X) <: Table`, then in fact

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
* add explicit `scitype` (and `Scitype`) definitions,
* register any traits that were needed to define scitypes,
* optionally define `coerce` methods for your convention

Each step is explained below, taking the MLJ convention as an example.

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

### Adding explicit `scitype` declarations.

When overloading `scitype` one needs to dipatch over the convention,
as in this example:

```julia
ScientificTypes.scitype(::Integer, ::MLJ) = Count
```

In some cases, however, the scientific type to be attributed to an
object might depend on the evaluation of a boolean-valued trait
function. There is a mechanism for "registering" such traits to
streamline trait-based dispatch of the `scitype` method. This is best
illustrated with an example.

In the MLJ convention, all containers that meet the
[`Tables.jl`](https://github.com/JuliaData/Tables.jl) interface are
deemed to have scitype `Table`. These are detected using the Tables.jl
trait `istable`. Our first step is to choose a name for the trait, in
	this case `:table`. Our `scitype` declaration then reads:

```
function ScientificTypes.scitype(X, ::MLJ, ::Val{:table})
   K = <some type depending on columns of X>
   return Table{K}
end
```

For this to work we now need to register the trait, which means adding
to the `TRAIT_FUNCTION_GIVEN_NAME` dictionary, which should be
performed within the init function of the defining package:

```julia
function __init__()
    ScientificTypes.set_convention(MLJ())
    ScientificTypes.TRAIT_FUNCTION_GIVEN_NAME[:table] = Tables.istable
end
```

**Important limitation.** One may not add a trait function to
the `TRAIT_FUNCTION_GIVEN_NAME` dictionary if it holds `true` on some
object `X` for which an existing trait already holds true.


### Defining a `coerce` function

It may be very useful to define a function to coerce machine types so
as to correct an unintended scientific interpretation, according to a
given convention.  In the `MLJ` convention, this is implemented by
defining `coerce` methods (no stub provided by `ScientificTypes`)

For instance consider the simplified:

```julia
function coerce(y::AbstractArray{T}, T2::Type{<:Union{Missing,Continuous}}
                ) where T <: Union{Missing,Real}
    return float(y)
end
```

Under this definition, `coerce([1, 2, 4], Continuous)` is mapped to
`[1.0, 2.0, 4.0]`, which has scitype `AbstractVector{Continuous}`.

In the case of tabular data, one might additionally define `coerce`
methods to selectively coerce data in specified columns. See
[MLJScientificType](https://github.com/alan-turing-institute/MLJScientificTypes.jl)
for examples.



