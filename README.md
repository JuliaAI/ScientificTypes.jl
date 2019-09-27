# ScientificTypes

| [MacOS/Linux] | Coverage | Documentation |
| :-----------: | :------: | :-----------: |
| [![Build Status](https://travis-ci.org/alan-turing-institute/ScientificTypes.jl.svg?branch=master)](https://travis-ci.org/alan-turing-institute/ScientificTypes.jl) | [![codecov.io](http://codecov.io/github/alan-turing-institute/ScientificTypes.jl/coverage.svg?branch=master)](http://codecov.io/github/alan-turing-institute/ScientificTypes.jl?branch=master) | [![](https://img.shields.io/badge/docs-stable-blue.svg)](https://alan-turing-institute.github.io/ScientificTypes.jl/dev) |

A light-weight Julia interface for implementing conventions about the scientific interpretation of data, and for performing type coercions enforcing those conventions.

The package makes the distinction between between **machine type** and **scientific type**:

* the _machine type_ is a Julia type the data is currently encoded as (for instance: `Float64`)
* the _scientific type_ is a type defined by this package which encapsulates how the data should be _interpreted_ in the rest of the code (for instance: `Continuous` or `Multiclass`)

As a motivating example, the data might contain a column corresponding to a _number of transactions_, the machine type in that case could be an `Int` whereas the scientific type would be a `Count`.

The usefulness of this machinery becomes evident when the machine type does not directly connect with a scientific type; taking the previous example, the data could have been encoded as a `Float64` whereas the meaning should still be a `Count`.

## Very quick start

(For more information and examples please refer to [the doc](https://alan-turing-institute.github.io/ScientificTypes.jl/dev))

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

this uses the default "MLJ convention" to attribute a scitype.

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
