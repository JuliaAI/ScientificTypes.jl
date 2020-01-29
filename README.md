# ScientificTypes

| [MacOS/Linux] | Coverage |
| :-----------: | :------: |
| [![Build Status](https://travis-ci.org/alan-turing-institute/ScientificTypes.jl.svg?branch=master)](https://travis-ci.org/alan-turing-institute/ScientificTypes.jl) | [![codecov.io](http://codecov.io/github/alan-turing-institute/ScientificTypes.jl/coverage.svg?branch=master)](http://codecov.io/github/alan-turing-institute/ScientificTypes.jl?branch=master) |

A light-weight, dependency-free Julia interface for implementing conventions
about the scientific interpretation of data.
This package should only be used by developers who intend to define their own
scientific type convention.
The [MLJScientificTypes.jl](https://github.com/alan-turing-institute/MLJScientificTypes.jl) packages implements such a convention used in the [MLJ](https://github.com/alan-turing-institute/MLJ.jl)
universe.

## Purpose

The package makes the distinction between between **machine type** and **scientific type**:

* the _machine type_ is a Julia type the data is currently encoded as (for instance: `Float64`)
* the _scientific type_ is a type defined by this package which
  encapsulates how the data should be _interpreted_ (for instance:
  `Continuous` or `Multiclass`)

The distinction is useful because the same machine type is often used
to represent data with *differing* scientific interpretations - `Int`
is used for product numbers (a factor) but also for a person's weight
(a continuous variable) - while the same scientific
type is frequently represented by *different* machine types - both
`Int` and `Float64` are used to represent weights, for example.

### Type hierarchy

The package provides a hierarchy of Julia types representing data types for use
in method dispatch (e.g., for trait values). Instances of the types play no
role.

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
|  ├─ Textual
│  └─ Table
└─ Unknown
```

## Defining a new convention

If you want to implement your own convention, you can consider the [MLJScientificTypes.jl](https://github.com/alan-turing-institute/MLJScientificTypes.jl) as a blueprint.

When defining a convention you may want to:

* declare a new convention,
* declare new traits,
* implement custom `schema`, `show` and `info` functions,
* add explicit `scitype` and `Scitype` definitions,
* define a `coerce` function.

We explain below how these steps may look like taking the MLJ convention as
an example.

### Declaring a new convention

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

### Declaring new traits

It's useful to mark containers that meet explicit traits; by default everything
is marked as `:other`. In the MLJ convention, we specifically consider all
containers that meet the [`Tables.jl`](https://github.com/JuliaData/Tables.jl)
interface. In order to declare this you have to add a key to the
`TRAIT_FUNCTION_GIVEN_NAME` dictionary with a boolean function that verifies
the trait. This must also be placed in your `__init__` function.
In the case of the MLJ convention:

```julia
function __init__()
    ScientificTypes.set_convention(MLJ())
    ScientificTypes.TRAIT_FUNCTION_GIVEN_NAME[:table] = Tables.istable
end
```

### Adding scientific types

You may want to extend the type hierarchy defined above. In the case of the
MLJ convention, we consider a *table* as a scientific type:

```julia
struct Table{K} <: Known end
```

where `K` is a union over the scientific type of each of the columns.

### Implementing custom `schema`, `show` and `info`

If you have added new traits, you *may* want to extend the `schema` function
for objects with that trait. Subsequently you may also want to extend  the
`show` of such schemas  and  the `info` of such objects.

The `Schema` constructor takes 4 tuples:
- the *names* of the features
- their *machine type*
- their *scientific type*
- the *number of rows*

In the MLJ convention:

```julia
function ScientificTypes.schema(X, ::Val{:table}; kw...)
    sch = Tables.schema(X)
    # ...
    return Schema(names, types, stypes, nrows)
end
```

Extending the `show` or `info` is then straightforward.

```julia
ScientificTypes.info(X, ::Val{:table}) = schema(X)

function Base.show(io::IO, ::MIME"text/plain", s::ScientificTypes.Schema)
    # ...
end
```

### Adding explicit `scitype` and `Scitype` definitions

The `scitype` functions indicate default mappings from *machine type* to a
*scientific type*. For instance in the MLJ convention:

```julia
ScientificType.scitype(::Integer, ::MLJ) = Count
```

where `::MLJ` refers to the convention.

The `Scitype` functions will typically match a few of your `scitype` functions
to automatically obtain the scientific type of arrays of a type.
For instance in the MLJ convention:

```julia
ST.Scitype(::Type{<:Integer}, ::MLJ) = Count
```

meaning that the scitype of an array such as `[1,2,3]` will directly be
inferred as an array of `Count`.

### Defining a `coerce` function

It may be very useful to define a function allowing you to convert an object
with one scitype to another scitype. In the MLJ convention, this is assumed by
the `coerce` function.

For instance consider the simplified:

```julia
function coerce(y::AbstractArray{T}, T2::Type{<:Union{Missing,Continuous}}
                ) where T <: Union{Missing,Real}
    return float(y)
end
```

This maps an array of Real to an array of `AbstractFloat` (which are mapped to
`Continuous` in the MLJ convention).

Further, if you work with specific containers, you may want to define a
`coerce` function that works on the container by applying `coerce` on each
of the features. In the MLJ convention, we work with tabular objects and
define a `coerce` function which applies specific coercion on each of the
columns.
