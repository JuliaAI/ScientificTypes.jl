# ScientificTypes.jl

| Linux | Coverage | Documentation |
| :-----------: | :------: | :-----------: |
| [![Build Status](https://github.com/JuliaAI/ScientificTypes.jl/workflows/CI/badge.svg)](https://github.com/JuliaAI/ScientificTypes.jl/actions) | [![codecov.io](http://codecov.io/github/JuliaAI/ScientificTypes.jl/coverage.svg?branch=master)](http://codecov.io/github/JuliaAI/ScientificTypes.jl?branch=master) | [![](https://img.shields.io/badge/docs-dev-blue.svg)](https://JuliaAI.github.io/ScientificTypes.jl/dev)

This package makes a distinction between **machine type** and
**scientific type** of a Julia object:

* The _machine type_ refers to the Julia type being used to represent
  the object (for instance, `Float64`).

* The _scientific type_ is one of the types defined in
  [ScientificTypesBase.jl](https://github.com/JuliaAI/ScientificTypesBase.jl)
  reflecting how the object should be _interpreted_ (for instance,
  `Continuous` or `Multiclass`).


#### Contents

 - [Installation](#installation)
 - [Who is this repository for?](#who-is-this-repository-for)
 - [What's provided here?](#what-is-provided-here)
 - [Very quick start](#very-quick-start)

## Installation

```julia
using Pkg
Pkg.add("ScientificTypes")
```

## Who is this repository for?

- developers of statistical and scientific software who want to
  articulate their data type requirements in a generic,
  purpose-oriented way, and who are furthermore happy to adopt an
  existing convention about what data types should be used for
  what purpose (a convention first developed for the MLJ ecosystem,
  but useful in a general context)

## What's provided here?

The module `ScientificTypes` defined in this repo rexports the
scientific types and associated methods defined in [ScientificTypesBase.jl](https://github.com/JuliaAI/ScientificTypesBase.jl)
and provides:

- a collection of `scitype` definitions that
  articulate a default convention.

- a `coerce` function, for changing machine types to reflect a specified
  scientific interpretation (scientific type)

- an `autotype` fuction for "guessing" the intended scientific type of data


## Very quick start

For more information and examples please refer to [the
manual](https://JuliaAI.github.io/ScientificTypes.jl/dev).

```julia
using ScientificTypes, DataFrames
X = DataFrame(
    a = randn(5),
    b = [-2.0, 1.0, 2.0, missing, 3.0],
    c = [1, 2, 3, 4, 5],
    d = [0, 1, 0, 1, 0],
    e = ['M', 'F', missing, 'M', 'F'],
    )
sch = schema(X)
```

will print

```
┌───────┬────────────────────────────┬─────────────────────────┐
│ names │ scitypes                   │ types                   │
├───────┼────────────────────────────┼─────────────────────────┤
│ a     │ Continuous                 │ Float64                 │
│ b     │ Union{Missing, Continuous} │ Union{Missing, Float64} │
│ c     │ Count                      │ Int64                   │
│ d     │ Count                      │ Int64                   │
│ e     │ Union{Missing, Unknown}    │ Union{Missing, Char}    │
└───────┴────────────────────────────┴─────────────────────────┘
```

Detail is obtained in the obvious way; for example:

```julia
julia> sch.names
(:a, :b, :c, :d, :e)
```

To specify that instead `b` should be regared as `Count`, and that both `d` and `e` are `Multiclass`, we use the `coerce` function:

```julia
Xc = coerce(X, :b=>Count, :d=>Multiclass, :e=>Multiclass)
schema(Xc)
```

which prints

```
┌───────┬───────────────────────────────┬────────────────────────────────────────────────┐
│ names │ scitypes                      │ types                                          │
├───────┼───────────────────────────────┼────────────────────────────────────────────────┤
│ a     │ Continuous                    │ Float64                                        │
│ b     │ Union{Missing, Count}         │ Union{Missing, Int64}                          │
│ c     │ Count                         │ Int64                                          │
│ d     │ Multiclass{2}                 │ CategoricalValue{Int64, UInt32}                │
│ e     │ Union{Missing, Multiclass{2}} │ Union{Missing, CategoricalValue{Char, UInt32}} │
└───────┴───────────────────────────────┴────────────────────────────────────────────────┘

```


#### Acknowledgements and history

ScientificTypes is based on code from
[MLJScientificTypes.jl](https://github.com/JuliaAI/MLJScientificTypes.jl)
(now deprecated) and in particular builds on contributions of Anthony
Blaom (@ablaom), Thibaut Lienart (@tlienart), Samuel Okon
(@OkonSamuel), and others not recorded in the ScientificTypes commit
history.

ScientificTypes.jl 2.0 implements the `DefaultConvention`, which
coincides with the deprecated `MLJ` convention of
[MLJScientificTypes.jl](https://github.com/JuliaAI/MLJScientificTypes.jl)
0.4.8. The code at ScientificTypes 1.1.2 (which defined only the API)
became
[ScientificTypesBase.jl](https://github.com/JuliaAI/ScientificTypesBase.jl)
1.0.
