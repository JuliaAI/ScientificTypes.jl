# ScientificTypes.jl

This package makes a distinction between **machine type** and
**scientific type** of a Julia object:

* The _machine type_ refers to the Julia type being used to represent
  the object (for instance, `Float64`).

* The _scientific type_ is one of the types defined in
  [ScientificTypesBase.jl](https://github.com/alan-turing-institute/ScientificTypesBase.jl)
  reflecting how the object should be _interpreted_ (for instance,
  `Continuous` or `Multiclass`).

A *scientific type convention* is an assignment of a scientific type
to every Julia object, articulated by overloading the `scitype`
method.  The `DefaultConvention` convention is the convention used
in various Julia ecosystems.

This package additionally defines tools for type coercion (the
`coerce` method) and scientific type "guessing" (the `autotype`
method).

Developers interested in implementing a different convention will
instead import [Scientific
TypesBase.jl](https://github.com/alan-turing-institute/ScientificTypesBase.jl),
following the documentation there, possibly using this repo as a
template.

## Type hierarchy

The supported scientific types have the following hierarchy:

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

PersistenceDiagram

Unknown
```


Additionally, we regard the Julia native types `Missing` and `Nothing`
as scientific types as well.


## Getting started

This documentation focuses on properties of the `scitype` method
specific to the default convention. The `scitype` method satisfies certain
universal properties, with respect to its operation on tuples, arrays
and tables, set out in the ScientificTypes
[readme](https://github.com/JuliaAI/ScientificTypesBase.jl#2-the-scitype-and-scitype-methods),
but only implicitly described here.

To get the scientific type of a Julia object defined by the default
convention, call `scitype`:

```@repl 1
using ScientificTypes
scitype(3.14)
```

For a vector, you can use `scitype` or `elscitype` (which will give you a
scitype corresponding to the elements):

```@repl 1
scitype([1,2,3,missing])
```

```@repl 1
elscitype([1,2,3,missing])
```

Occasionally, you may want to find the union of all scitypes of
elements of an arbitrary iterable, which you can do with
`scitype_union`:

```@repl 1
scitype_union((ifelse(isodd(i), i, missing) for i in 1:5))
```

Note calling `scitype_union` on a large array, for example, is
typically much slower than calling `scitype` or `elscitype`.

## Summary of the default convention

The table below summarizes the default convention for representing
scientific types:

Type `T`        | `scitype(x)` for `x::T`           | package required
:-------------- | :-------------------------------- | :------------------------
`Missing`       | `Missing`                         |
`Nothing`       | `Nothing`                         |
`AbstractFloat` | `Continuous`                      |
`Integer`       |  `Count`                          |
`String`        | `Textual`                         |
`CategoricalValue` | `Multiclass{N}` where `N = nlevels(x)`, provided `x.pool.ordered == false`  | CategoricalArrays
`CategoricalString` | `Multiclass{N}` where `N = nlevels(x)`, provided `x.pool.ordered == false`  | CategoricalArrays
`CategoricalValue` | `OrderedFactor{N}` where `N = nlevels(x)`, provided `x.pool.ordered == true`| CategoricalArrays
`CategoricalString` | `OrderedFactor{N}` where `N = nlevels(x)` provided `x.pool.ordered == true` | CategoricalArrays
`Date`          | `ScientificDate`     | Dates
`Time`          | `ScientificTime`     | Dates
`DateTime`      | `ScientificDateTime` | Dates
`AbstractArray{<:Gray,2}` | `GrayImage{W,H}` where `(W, H) = size(x)`                                   | ColorTypes
`AbstractArrray{<:AbstractRGB,2}` | `ColorImage{W,H}` where `(W, H) = size(x)`                                  | ColorTypes
`PersistenceDiagram` | `PersistenceDiagram` | PersistenceDiagramsBase
any table type `T` supported by Tables.jl | `Table{K}` where `K=Union{column_scitypes...}`                      | Tables

Here `nlevels(x) = length(levels(x.pool))`.

## Notes

- We regard the built-in Julia types `Missing` and `Nothing` as scientific types.
- `Finite{N}`, `Multiclass{N}` and `OrderedFactor{N}` are all parameterized by the number of levels `N`. We export the alias `Binary = Finite{2}`.
- `Image{W,H}`, `GrayImage{W,H}` and `ColorImage{W,H}` are all parameterized by the image width and height dimensions, `(W, H)`.
- On objects for which the default convention has nothing to say, the
  `scitype` function returns `Unknown`.


### Special note on binary data

ScientificTypes does not define a separate "binary" scientific
type. Rather, when binary data has an intrinsic "true" class (for
example pass/fail in a product test), then it should be assigned an
`OrderedFactor{2}` scitype, while data with no such class (e.g.,
gender) should be assigned a `Multiclass{2}` scitype. In the
`OrderedFactor{2}` case we adopt the convention that the "true" class
come *after* the "false" class in the ordering (corresponding to the
usual assignment "false=0" and "true=1"). Of course, `Finite{2}`
covers both cases of binary data.


## Type coercion for tabular data

A common two-step work-flow is:

1. Inspect the `schema` of some table, and the column `scitypes` in particular.

1. Provide pairs of column names and scitypes (or a dictionary) that
   change the column machine types to reflect the desired scientific
   interpretation (scitype).

```@example 2
using ScientificTypes # hide
using DataFrames, Tables
X = DataFrame(
	 name=["Siri", "Robo", "Alexa", "Cortana"],
	 height=[152, missing, 148, 163],
	 rating=[1, 5, 2, 1])
schema(X)
```

In some further analysis of the data in `X`, a more likely
interpretation is that `:name` is `Multiclass`, the `:height` is
`Continuous`, and the `:rating` an `OrderedFactor`. Correcting the
types with `coerce`:

```@example 2
Xfixed = coerce(X, :name=>Multiclass,
                   :height=>Continuous,
                   :rating=>OrderedFactor)
schema(Xfixed).scitypes
```

Note that because missing values were encountered in `height`, an
"imperfect" type coercion to `Union{Missing,Continuous}` has been
performed, and a warning issued.  To avoid the warning, coerce to
`Union{Missing,Continuous}` instead.

"Global" replacements based on existing scientific types are also
possible, and can be mixed with the name-based replacements:

```@example 2
X  = (x = [1, 2, 3],
      y = ['A', 'B', 'A'],
      z = [10, 20, 30])
Xfixed = coerce(X, Count=>Continuous, :y=>OrderedFactor)
schema(Xfixed).scitypes
```

Finally there is a `coerce!` method that does in-place coercion provided the
data structure supports it.

## Type coercion for image data

To have a scientific type of `Image` a julia object must be a
two-dimensional array whose element type is subtype of `Gray` or
`AbstractRGB` (color types from the
[ColorTypes.jl](https://github.com/JuliaGraphics/ColorTypes.jl)
package). And models typically expect *collections* of images
to be vectors of such two-dimensional arrays. Implementations of
`coerce` allow the conversion of some common image formats into one of
these. The eltype in these other formats can be any subtype of `Real`,
which includes the `FixedPoint` type from the
[FixedPointNumbers.jl](https://github.com/JuliaMath/FixedPointNumbers.jl)
package.

### Coercing a single image

Coercing a **gray** image, represented as a `Real` matrix (W x H format):

```@example 2
using ScientificTypes # hide
img = rand(10, 10)
coerce(img, GrayImage) |> scitype
```
Coercing a **color** image, represented as a `Real` 3-D array (W x H x C format):

```@example 2
img = rand(10, 10, 3)
coerce(img, ColorImage) |> scitype
```

### Coercing collections of images

Coercing a **collection** of **gray** images, represented as a `Real` 3-D array
(W x H x N format):

```@example 2
imgs = rand(10, 10, 3)
coerce(imgs, GrayImage) |> scitype
```
Coercing a **collection** of **gray** images, represented as a `Real` 4-D array
(W x H x {1} x N format):

```@example 2
imgs = rand(10, 10, 1, 3)
coerce(imgs, GrayImage) |> scitype
```

Coercing a **collection** of **color** images, represented as a `Real`
4-D array (W x H x C x N format):

```@example 2
imgs = rand(10, 10, 3, 5)
coerce(imgs, ColorImage) |> scitype
```


## Detailed usage examples

### Basics

```@example 3
using ScientificTypes # hide
using CategoricalArrays
scitype((2.718, 42))
```

In the default convention, to construct arrays with categorical scientific
element type one needs to use `CategorialArrays`:

```@example 3
v = categorical(['a', 'c', 'a', missing, 'b'], ordered=true)
scitype(v[1])
```

```@example 3
elscitype(v)
```

Coercing to `Multiclass`:

```@example 3
w = coerce(v, Union{Missing,Multiclass})
elscitype(w)
```

### Working with tables

While `schema` is convenient for inspecting the column scitypes of a
table, there is also a scitype for the tables themselves:

```@example 4
using ScientificTypes # hide
data = (x1=rand(10), x2=rand(10))
schema(data)
```

```@example 4
scitype(data)
```

Similarly, any table implementing the Tables interface has scitype
`Table{K}`, where `K` is the union of the scitypes of its columns.

Table scitypes are useful for dispatch and type checks, as shown here,
with the help of a constructor for `Table` scitypes provided by [Scientific
Types.jl](https://github.com/alan-turing-institute/ScientificTypes.jl):


```julia
Table(Continuous, Count)
```

```julia
Table{<:Union{AbstractArray{<:Continuous},AbstractArray{<:Count}}}
```

```@example 4
scitype(data) <: Table(Continuous)
```

```@example 4
scitype(data) <: Table(Infinite)
```

```@example 4
data = (x=rand(10), y=collect(1:10), z = [1,2,3,1,2,3,1,2,3,1])
data = coerce(data, :z=>OrderedFactor)
scitype(data) <: Table(Continuous,Count,OrderedFactor)
```

Note that `Table(Continuous,Finite)` is a *type* union and not a
`Table` *instance*.

### Tuples and arrays

The behavior of `scitype` on tuples is as you would expect:

```@example 5
using ScientificTypes #hide
scitype((1, 4.5))
```

For performance reasons, the behavior of `scitype` on arrays has some
wrinkles, in the case of missing values:

**The scitype of an array.** The scitype of an `AbstractArray`, `A`, is
always`AbstractArray{U}` where `U` is the union of the scitypes of the
elements of `A`, with one exception: If `typeof(A) <:
AbstractArray{Union{Missing,T}}` for some `T` different from `Any`,
then the scitype of `A` is `AbstractArray{Union{Missing, U}}`, where
`U` is the union over all non-missing elements, **even if `A` has no
missing elements.**

```julia
julia> v = [1.3, 4.5, missing]
julia> scitype(v)
AbstractArray{Union{Missing, Continuous},1}
```

```julia
julia> scitype(v[1:2])
AbstractArray{Union{Missing, Continuous},1}
```

## Automatic type conversion

The `autotype` function allows to use specific rules in order to guess
appropriate scientific types for *tabular* data. Such rules would typically be
more constraining than the ones implied by the active convention. When
`autotype` is used, a dictionary of suggested types is returned for each column
in the data; if none of the specified rule applies, the ambient convention is
used as "fallback".

The function is called as:

```julia
autotype(X)
```

If the keyword `only_changes` is passed set to `true`, then only the column names for which the suggested type is different from that provided by the convention are returned.

```julia
autotype(X; only_changes=true)
```

To specify which rules are to be applied, use the `rules` keyword  and specify a tuple of symbols referring to specific rules; the default rule is `:few_to_finite` which applies a heuristic for columns which have relatively few values, these columns are then encoded with an appropriate `Finite` type.
It is important to note that the order in which the rules are specified matters; rules will be applied in that order.

```julia
autotype(X; rules=(:few_to_finite,))
```

Finally, you can also use the following shorthands:

```julia
autotype(X, :few_to_finite)
autotype(X, (:few_to_finite, :discrete_to_continuous))
```

### Available rules

Rule symbol               | scitype suggestion
:------------------------ | :---------------------------------
`:few_to_finite`          | an appropriate `Finite` subtype for columns with few distinct values
`:discrete_to_continuous` | if not `Finite`, then `Continuous` for any `Count` or `Integer` scitypes/types
`:string_to_multiclass`        | `Multiclass` for any string-like column

Autotype can be used in conjunction with `coerce`:

```
X_coerced = coerce(X, autotype(X))
```

### Examples

By default it only applies the `:few_to_finite` rule

```@example auto
using ScientificTypes # hide
n = 50
X = (a = rand("abc", n),         # 3 values, not number        --> Multiclass
     b = rand([1,2,3,4], n),     # 4 values, number            --> OrderedFactor
     c = rand([true,false], n),  # 2 values, number but only 2 --> Multiclass
     d = randn(n),               # many values                 --> unchanged
     e = rand(collect(1:n), n))  # many values                 --> unchanged
autotype(X, only_changes=true)
```

For example, we could first apply the `:discrete_to_continuous` rule,
followed by `:few_to_finite` rule. The first rule will apply to `b` and `e`
but the subsequent application of the second rule will mean we will
get the same result apart for `e` (which will be `Continuous`)

```@example auto
autotype(X, only_changes=true, rules=(:discrete_to_continuous, :few_to_finite))
```

One should check and possibly modify the returned dictionary
before passing to `coerce`.

## API reference

```@docs
ScientificTypes.scitype
ScientificTypes.elscitype
ScientificTypes.scitype_union
coerce
autotype
```
