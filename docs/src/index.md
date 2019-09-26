# ScientificTypes.jl

A light-weight Julia interface for implementing conventions about the scientific interpretation of data, and for performing type coercions enforcing those conventions.

The package makes the distinction between between **machine type** and **scientific type**:

* the _machine type_ is a Julia type the data is currently encoded as (for instance: `Float64`)
* the _scientific type_ is a type defined by this package which encapsulates how the data should be _interpreted_ in the rest of the code (for instance: `Continuous` or `Multiclass`)

As a motivating example, the data might contain a column corresponding to a _number of transactions_, the machine type in that case could be an `Int` whereas the scientific type would be a `Count`.

The usefulness of this machinery becomes evident when the machine type does not directly connect with a scientific type; taking the previous example, the data could have been encoded as a `Float64` whereas the meaning should still be a `Count`.

## Features

The package  `ScientificTypes` provides:

- A hierarchy of new Julia types representing scientific data types for use in method dispatch (eg, for trait values). Instances of the types play no role:

```@example 0
using ScientificTypes, AbstractTrees
ScientificTypes.tree()
```

- A single method `scitype` for articulating a convention about what scientific type each Julia object can represent. For example, one might declare `scitype(::AbstractFloat) = Continuous`.

- A default convention called *mlj*, based on optional dependencies `CategoricalArrays`, `ColorTypes`, and `Tables`, which includes a convenience method `coerce` for performing scientific type coercion on `AbstractVectors` and columns of tabular data (any table implementing the [Tables.jl](https://github.com/JuliaData/Tables.jl) interface).

- A `schema` method for tabular data, based on the optional Tables dependency, for inspecting the machine and scientific types of tabular data, in addition to column names and number of rows.

### Dependencies

The only dependencies are [`Requires.jl`](https://github.com/MikeInnes/Requires.jl) and `InteractiveUtils` (from stdlib).

## Quick start

The package is registered and can be installed via the package manager with `add ScientificTypes`.

To get the scientific type of a Julia object according to the convention in use, call `scitype`:

```@example 1
using ScientificTypes # hide
scitype(3.14)
```

For a vector, you can use `scitype` or `scitype_union` (which will give you a scitype corresponding to the elements):

```@example 1
scitype([1,2,3,missing])
```

```@example 1
scitype_union([1,2,3,missing])
```

### Type coercion work-flow for tabular data

The standard workflow involves the following two steps:

1. inspect the `schema` of the data and the `scitypes` in particular
1. provide pairs or a dictionary with column names and scitypes for any changes you may want and coerce the data to those scitypes

```@example 2
using ScientificTypes # hide
using DataFrames, Tables
X = DataFrame(
     name=["Siri", "Robo", "Alexa", "Cortana"],
     height=[152, missing, 148, 163],
     rating=[1, 5, 2, 1])
schema(X)
```

inspecting the scitypes:

```@example 2
schema(X).scitypes
```

but in this case you may want to map the names to `Multiclass`, the height to `Continuous` and the ratings to `OrderedFactor`; to do so:

```@example 2
Xfixed = coerce(X, :name=>Multiclass,
                   :height=>Continuous,
                   :rating=>OrderedFactor)
schema(Xfixed).scitypes
```

Note that, as it encountered missing values in `height` it coerced the type to `Union{Missing,Continuous}`.


## Notes

- We regard the built-in julia type `Missing` as a scientific type. The new scientific types introduced in the current package are rooted in the abstract type `Found` (see tree above) and you export the alias `Scientific = Union{Missing, Found}`.

- `Finite{N}`, `Muliticlass{N}` and `OrderedFactor{N}` are all parameterized by the number of levels `N`. We export the alias `Binary = Finite{2}`.

- `Image{W,H}`, `GrayImage{W,H}` and `ColorImage{W,H}` are all parameterized by the image width and height dimensions, `(W, H)`.

- The function `scitype` has the fallback value `Unknown`.

- Since Tables is an optional dependency, the `scitype` of a [`Tables.jl`](https://github.com/JuliaData/Tables.jl) supported table is `Unknown` unless Tables has been imported.

- Developers can define their own conventions using the code in `src/conventions/mlj/` as a template. The active convention is controlled by the value of `ScientificTypes.CONVENTION[1]`.


## Detailed usage examples

```@example 3
using ScientificTypes
# activate a convention
mlj() # redundant as it's the default

scitype((2.718, 42))
```

Let's try with categorical valued objects:

```@example 3
using CategoricalArrays
v = categorical(['a', 'c', 'a', missing, 'b'], ordered=true)
scitype(v[1])
```

and

```@example 3
scitype_union(v)
```

you could coerce this to `Multiclass`:

```@example 3
w = coerce(v, Multiclass)
scitype_union(w)
```

### Working with tables

```@example 4
using ScientificTypes # hide
using Tables
data = (x1=rand(10), x2=rand(10), x3=collect(1:10))
scitype(data)
```

you can also use `schema`:

```@example 4
schema(data)
```

and use `<:` for type checks:

```@example 4
scitype(data) <: Table(Continuous)
```

```@example 4
scitype(data) <: Table(Infinite)
```

or specify multiple types directly:

```@example 4
data = (x=rand(10), y=collect(1:10), z = [1,2,3,1,2,3,1,2,3,1])
data = coerce(data, :z=>OrderedFactor)
scitype(data) <: Table(Continuous,Count,OrderedFactor)
```

### The scientific type of tuples, arrays and tables

Under any convention, the scitype of a tuple is a `Tuple` type parameterized by scientific types:

```@example 5
using ScientificTypes # hide
scitype((1, 4.5))
```

Similarly, the scitype of an `AbstractArray` is `AbstractArray{U}` where `U` is the union of the element scitypes:

```@example 5
scitype([1.3, 4.5, missing])
```

Provided the [Tables.jl](https://github.com/JuliaData/Tables.jl) package is loaded, any table implementing the Tables interface has a scitype encoding the scitypes of its columns:

```@example 5
using CategoricalArrays, Tables
X = (x1=rand(10),
     x2=rand(10),
     x3=categorical(rand("abc", 10)),
     x4=categorical(rand("01", 10)))
scitype(X)
```

Sepcifically, if `X` has columns `c1, ..., cn`, then, by definition,

```julia
scitype(X) == Table{Union{scitype(c1), ..., scitype(cn)}}
```

With this definition, common type checks can be performed with tables.
For instance, you could check that each column of `X` has an element scitype that is either
`Continuous` or `Finite`:

```@example 5
scitype(X) <: Table{<:Union{AbstractVector{<:Continuous}, AbstractVector{<:Finite}}}
```

A built-in `Table` constructor provides a shorthand for the right-hand side:

```@example 5
scitype(X) <: Table(Continuous, Finite)
```

Note that `Table(Continuous,Finite)` is a *type* union and not a `Table` *instance*.

## The MLJ convention

The table below summarizes the *mlj* convention for representing
scientific types:

Type `T`        | `scitype(x)` for `x::T`           | package required
:-------------- | :-------------------------------- | :------------------------
`Missing`       | `Missing`                         |
`AbstractFloat` | `Continuous`                      |
`Integer`       |  `Count`                          |
`CategoricalValue` | `Multiclass{N}` where `N = nlevels(x)`, provided `x.pool.ordered == false`  | CategoricalArrays
`CategoricalString` | `Multiclass{N}` where `N = nlevels(x)`, provided `x.pool.ordered == false`  | CategoricalArrays
`CategoricalValue` | `OrderedFactor{N}` where `N = nlevels(x)`, provided `x.pool.ordered == true`| CategoricalArrays
`CategoricalString` | `OrderedFactor{N}` where `N = nlevels(x)` provided `x.pool.ordered == true` | CategoricalArrays
`AbstractArray{<:Gray,2}` | `GrayImage{W,H}` where `(W, H) = size(x)`                                   | ColorTypes
`AbstractArrray{<:AbstractRGB,2}` | `ColorImage{W,H}` where `(W, H) = size(x)`                                  | ColorTypes
any table type `T` supported by Tables.jl | `Table{K}` where `K=Union{column_scitypes...}`                      | Tables

Here `nlevels(x) = length(levels(x.pool))`.


## Automatic type conversion

The `autotype` function allows to use specific rules in order to guess appropriate scientific types for the data. Such rules would typically be more constraining than the ones implied by the active convention. When `autotype` is used, a dictionary of suggested types is returned for each column in the data; if none of the specified rule applies, the ambient convention is used as "fallback".

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

### Available rules

Rule symbol               | scitype suggestion
:------------------------ | :---------------------------------
`:few_to_finite`          | an appropriate `Finite` subtype for columns with few distinct values
`:discrete_to_continuous` | if not `Finite`, then `Continuous` for any `Count` or `Integer` scitypes/types
`:string_to_class`        | `Multiclass` for any string-like column

Autotype can be used in conjunction with `coerce`:

```
X_coerced = coerce(X, autotype(X))
```

### Examples

By default it only applies the `:few_to_many` rule

```@example auto
using ScientificTypes, Tables # hide
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
