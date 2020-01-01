# ScientificTypes

| [MacOS/Linux] | Coverage | Documentation |
| :-----------: | :------: | :-----------: |
| [![Build Status](https://travis-ci.org/alan-turing-institute/ScientificTypes.jl.svg?branch=master)](https://travis-ci.org/alan-turing-institute/ScientificTypes.jl) | [![codecov.io](http://codecov.io/github/alan-turing-institute/ScientificTypes.jl/coverage.svg?branch=master)](http://codecov.io/github/alan-turing-institute/ScientificTypes.jl?branch=master) | [![](https://img.shields.io/badge/docs-stable-blue.svg)](https://alan-turing-institute.github.io/ScientificTypes.jl/stable) |

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

- Convenience methods for working with scientific types, the most commonly used being

    - `schema(X)`, which gives an extended schema of any Tables.jl
       compatible table `X`, including the column scientific types
       implied by the active convention.
	   
	   - `coerce(X, ...)`, which coerces the machine types of `X` to
       reflect a desired scientific type.

For example,

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
```

will print

```
_.table = 
┌─────────┬─────────────────────────┬────────────────────────────┐
│ _.names │ _.types                 │ _.scitypes                 │
├─────────┼─────────────────────────┼────────────────────────────┤
│ a       │ Float64                 │ Continuous                 │
│ b       │ Union{Missing, Float64} │ Union{Missing, Continuous} │
│ c       │ Int64                   │ Count                      │
│ d       │ Int64                   │ Count                      │
│ e       │ Union{Missing, Char}    │ Union{Missing, Unknown}    │
└─────────┴─────────────────────────┴────────────────────────────┘
_.nrows = 5
```

Here the default *mlj* convention is being applied ((cf. [docs](https://alan-turing-institute.github.io/ScientificTypes.jl/dev/#The-MLJ-convention-1)). Detail is obtained in the obvious way; for example:

```julia
julia> sch.names
(:a, :b, :c, :d, :e)
```

Now you could want to specify that `b` is actually a `Count`, and that `d` and `e` are `Multiclass`; this is done with the `coerce` function:

```julia
Xc = coerce(X, :b=>Count, :d=>Multiclass, :e=>Multiclass)
schema(Xc)
```

which prints

```
_.table = 
┌─────────┬──────────────────────────────────────────────┬───────────────────────────────┐
│ _.names │ _.types                                      │ _.scitypes                    │
├─────────┼──────────────────────────────────────────────┼───────────────────────────────┤
│ a       │ Float64                                      │ Continuous                    │
│ b       │ Union{Missing, Int64}                        │ Union{Missing, Count}         │
│ c       │ Int64                                        │ Count                         │
│ d       │ CategoricalValue{Int64,UInt8}                │ Multiclass{2}                 │
│ e       │ Union{Missing, CategoricalValue{Char,UInt8}} │ Union{Missing, Multiclass{2}} │
└─────────┴──────────────────────────────────────────────┴───────────────────────────────┘
_.nrows = 5

```
