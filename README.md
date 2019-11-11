# ScientificTypes

| [MacOS/Linux] | Coverage | Documentation |
| :-----------: | :------: | :-----------: |
| [![Build Status](https://travis-ci.org/alan-turing-institute/ScientificTypes.jl.svg?branch=master)](https://travis-ci.org/alan-turing-institute/ScientificTypes.jl) | [![codecov.io](http://codecov.io/github/alan-turing-institute/ScientificTypes.jl/coverage.svg?branch=master)](http://codecov.io/github/alan-turing-institute/ScientificTypes.jl?branch=master) | [![](https://img.shields.io/badge/docs-stable-blue.svg)](https://alan-turing-institute.github.io/ScientificTypes.jl/dev) |

A light-weight Julia interface for implementing conventions about the
scientific interpretation of data, and for performing type coercions
enforcing those conventions.

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


## Very quick start

For more information and examples please refer to [the
manual](https://alan-turing-institute.github.io/ScientificTypes.jl/dev).

ScientificTypes.jl has three components:

- An *interface*, for articulating a convention about the scientific
  interpretation of data. This consists of a definition of a scientific
  type hierarchy, and a single function `scitype` with scientific
  types as values. Someone implementing a convention must add methods
  to this function, while the general user just applies it to data, as
  in `scitype(4.5)` (returning `Continuous` in the *mlj* convention).
  
- A built-in convention, called *mlj*, active by default.

- Convenience methods for working with scientific types, the most commonly used being:

    -  `schema(X)`, which gives an extended schema of any table `X`,
       including the column scientific types implied by the active
       convention. 
.
    - `coerce(X, ...)`, which coerces the machine types of `X`
      to reflect a desired scientific type.

```julia
using ScientificTypes, DataFrames
X = DataFrame(
    a = randn(5),
    b = [-2.0, 1.0, 2.0, missing, 3.0],
    c = [1, 2, 3, 4, 5],
    d = [0, 1, 0, 1, 0],
    e = ['M', 'F', missing, 'M', 'F'],
    )
sch = schema(X) # schema is overloaded in Scientifictypes
for (name, scitype) in zip(sch.names, sch.scitypes)
    println(":$name  --  $scitype")
end
```

will print

```
:a  --  Continuous
:b  --  Union{Missing, Continuous}
:c  --  Count
:d  --  Count
:e  --  Union{Missing, Unknown}
```

this uses the default *mlj* convention to attribute a scitype
(cf. [docs](https://alan-turing-institute.github.io/ScientificTypes.jl/dev/#The-MLJ-convention-1)).

Now you could want to specify that `b` is actually a `Count`, and that `d` and `e` are `Multiclass`; this is done with the `coerce` function:

```julia
Xc = coerce(X, :b=>Count, :d=>Multiclass, :e=>Multiclass)
sch = schema(Xc)
for (name, scitype) in zip(sch.names, sch.scitypes)
    println(":$name  --  $scitype")
end
```

will print

```
:a  --  Continuous
:b  --  Union{Missing, Count}
:c  --  Count
:d  --  Multiclass{2}
:e  --  Union{Missing, Multiclass{2}}
```
