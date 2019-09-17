
## ScientificTypes

A light-weight julia interface for implementing conventions about the
scientific interpretation of data, and for performing type coercions
enforcing those conventions.

[![Build
Status](https://travis-ci.com/alan-turing-institute/ScientificTypes.jl.svg?branch=master)](https://travis-ci.com/alan-turing-institute/ScientificTypes.jl) [![codecov.io](http://codecov.io/github/alan-turing-institute/ScientificTypes.jl/coverage.svg?branch=master)](http://codecov.io/github/alan-turing-institute/ScientificTypes.jl?branch=master)


ScientificTypes provides:

- A hierarchy of new julia types representing scientific data types
  for use in method dispatch (eg, for trait values). Instances of
  the types play no role:


```julia
using ScientificTypes, AbstractTrees
ScientificTypes.tree()
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
    │  └─ Table
    └─ Unknown


- A single method `scitype` for articulating a convention about what
  scientific type each julia object can represent. For example, one
  might declare `scitype(::AbstractFloat) = Continuous`.

- A default convention called *mlj*, based on optional dependencies
  CategoricalArrays, ColorTypes, and Tables, which includes a convenience
  method `coerce` for performing scientific type coercion on
  AbstractVectors and columns of tabular data (any table
  implementing the
  [Tables.jl](https://github.com/JuliaData/Tables.jl) interface). A
  table at the end of this document details the convention.

- A `schema` method for tabular data, based on the optional Tables
  dependency, for inspecting the machine and scientific types of
  tabular data, in addition to column names and number of rows

The only core dependencies of ScientificTypes are Requires and
InteractiveUtils (from the standard library).

### Quick start

Install with `using Pkg; add ScientificTypes`.

Get the scientific type of some julia object, using the default
convention:


```julia
scitype(3.14)
```




    Continuous



#### Typical type coercion work-flow for tabular data


```julia
using CategoricalArrays, DataFrames, Tables
X = DataFrame(name=["Siri", "Robo", "Alexa", "Cortana"],
              height=[152, missing, 148, 163],
              rating=[1, 5, 2, 1])
```




<table class="data-frame"><thead><tr><th></th><th>name</th><th>height</th><th>rating</th></tr><tr><th></th><th>String</th><th>Int64⍰</th><th>Int64</th></tr></thead><tbody><p>4 rows × 3 columns</p><tr><th>1</th><td>Siri</td><td>152</td><td>1</td></tr><tr><th>2</th><td>Robo</td><td>missing</td><td>5</td></tr><tr><th>3</th><td>Alexa</td><td>148</td><td>2</td></tr><tr><th>4</th><td>Cortana</td><td>163</td><td>1</td></tr></tbody></table>




```julia
schema(X)
```




    (names = (:name, :height, :rating), types = (String, Union{Missing, Int64}, Int64), scitypes = (Unknown, Union{Missing, Count}, Count), nrows = 4)




```julia
schema(X).scitypes
```




    (Unknown, Union{Missing, Count}, Count)




```julia
Xfixed = coerce(X, :name=>Multiclass,
                   :height=>Continuous,
                   :rating=>OrderedFactor);
```

    ┌ Warning: Missing values encountered coercing scitype to Continuous.
    │ Coerced to Union{Missing,Continuous} instead. 
    └ @ ScientificTypes /Users/anthony/Dropbox/Julia7/MLJ/ScientificTypes/src/conventions/mlj/mlj.jl:5



```julia
schema(Xfixed).scitypes
```




    (Multiclass{4}, Union{Missing, Continuous}, OrderedFactor{3})



Testing if each column of a table has an element scientific type
that subtypes types from a specified list:


```julia
scitype(Xfixed) <: Table(Union{Missing,Continuous}, Finite)
```




    true



### Notes

- We regard the built-in julia type `Missing` as a scientific
  type. The new scientific types introduced in the current package
  are rooted in the abstract type `Found` (see tree above) and we
  export the alias `Scientific = Union{Missing, Found}`.

- `Finite{N}`, `Muliticlass{N}` and `OrderedFactor{N}` are all
  parameterized by the number of levels `N`. We export the alias
  `Binary = Finite{2}`.

- `Image{W,H}`, `GrayImage{W,H}` and `ColorImage{W,H}` are all
  parameterized by the image width and height dimensions, `(W, H)`.

- The function `scitype` has the fallback value `Unknown`.

- Since Tables is an optional dependency, the `scitype` of a
  Tables.jl supported table is `Unknown` unless Tables has been imported.

- Developers can define their own conventions using the code in
  "src/conventions/mlj/" as a template. The active convention is
  controlled by the value of `ScientificTypes.CONVENTION[1]`.

### Detailed usage examples


```julia
using ScientificTypes
```

Activate a convention:


```julia
mlj() # redundant, as the default
```


```julia
scitype(3.142)
```




    Continuous




```julia
scitype((2.718, 42))
```




    Tuple{Continuous,Count}




```julia
using CategoricalArrays
v = categorical(['a', 'c', 'a', missing, 'b'], ordered=true)
scitype(v[1])
```




    OrderedFactor{3}




```julia
scitype(v)
```




    AbstractArray{Union{Missing, OrderedFactor{3}},1}




```julia
v = [1, 2, missing, 3];
scitype(v)
```




    AbstractArray{Union{Missing, Count},1}




```julia
w = coerce(v, Multiclass);
scitype(w)
```

    ┌ Warning: Missing values encountered coercing scitype to Multiclass.
    │ Coerced to Union{Missing,Multiclass} instead. 
    └ @ ScientificTypes /Users/anthony/Dropbox/Julia7/MLJ/ScientificTypes/src/conventions/mlj/mlj.jl:5





    AbstractArray{Union{Missing, Multiclass{3}},1}




```julia
using Tables
T = (x1=rand(10), x2=rand(10), x3=rand(10))
scitype(T)
```




    Table{AbstractArray{Continuous,1}}




```julia
using DataFrames
X = DataFrame(x1=1:5, x2=6:10, x3=11:15, x4=[16, 17, missing, 19, 20]);
```


```julia
scitype(X)
```




    Table{Union{AbstractArray{Count,1}, AbstractArray{Union{Missing, Count},1}}}




```julia
schema(X)
```




    (names = (:x1, :x2, :x3, :x4), types = (Int64, Int64, Int64, Union{Missing, Int64}), scitypes = (Count, Count, Count, Union{Missing, Count}), nrows = 5)




```julia
Xfixed = coerce(X, :x1=>Continuous,
                   :x2=>Continuous,
                   :x3=>Multiclass,
                   :x4=>OrderedFactor)
scitype(Xfixed)
```

    ┌ Warning: Missing values encountered coercing scitype to OrderedFactor.
    │ Coerced to Union{Missing,OrderedFactor} instead. 
    └ @ ScientificTypes /Users/anthony/Dropbox/Julia7/MLJ/ScientificTypes/src/conventions/mlj/mlj.jl:5





    Table{Union{AbstractArray{Continuous,1}, AbstractArray{Multiclass{5},1}, AbstractArray{Union{Missing, OrderedFactor{4}},1}}}




```julia
scitype(Xfixed) <: Table(Continuous, Finite)
```




    false




```julia
scitype(Xfixed) <: Table(Continuous, Union{Finite, Missing})
```




    true



### The scientific type  of tuples, arrays and tables

Note that under any convention, the scitype of a tuple is a `Tuple`
type parameterized by scientific types:


```julia
scitype((1, 4.5))
```




    Tuple{Count,Continuous}



Similarly, the scitype of an `AbstractArray` object is
`AbstractArray{U}`, where `U` is the union of the element scitypes:


```julia
scitype([1,2,3, missing])
```




    AbstractArray{Union{Missing, Count},1}



Provided the [Tables]() package is loaded, any table implementing
the Tables interface has a scitype encoding the scitypes of its
columns:


```julia
using CategoricalArrays
using Tables
X = (x1=rand(10),
     x2=rand(10),
     x3=categorical(rand("abc", 10)),
     x4=categorical(rand("01", 10)))
scitype(X)
```




    Table{Union{AbstractArray{Continuous,1}, AbstractArray{Multiclass{3},1}, AbstractArray{Multiclass{2},1}}}



Specifically, if `X` has columns `c1, c2, ..., cn`, then, by definition,

```julia
scitype(X) = Table{Union{scitype(c1), scitype(c2), ..., scitype(cn)}}
```

With this definition, we can perform common type checks associated
with tables. For example, to check that each column of `X` has an
element scitype subtying either `Continuous` or `Finite` (but not
`Union{Continuous, Finite}`!), we check

```julia
scitype(X) <: Table{Union{AbstractVector{Continuous}, AbstractVector{<:Finite}}
```

A built-in `Table` type constructor provides `Table(Continuous, Finite)` as
shorthand for the right-hand side. More generally,

```julia
scitype(X) <: Table(T1, T2, T3, ..., Tn)
 ```

if and only if `X` is a table and, for every column `col` of `X`,
`scitype(col) <: AbstractVector{<:Tj}`, for some `j` between `1` and `n`:


```julia
scitype(X) <: Table(Continuous, Finite)
```




    true



Note that `Table(Continuous, Finite)` is a *type* union and not a
`Table` *instance*.

Detailed inspection of column scientific types is included in an
extended form of Tables.schema:


```julia
schema(X)
```




    (names = (:x1, :x2, :x3, :x4), types = (Float64, Float64, CategoricalValue{Char,UInt32}, CategoricalValue{Char,UInt32}), scitypes = (Continuous, Continuous, Multiclass{3}, Multiclass{2}), nrows = 10)




```julia
schema(X).scitypes
```




    (Continuous, Continuous, Multiclass{3}, Multiclass{2})




```julia
typeof(schema(X))
```




    ScientificTypes.Schema{(:x1, :x2, :x3, :x4),Tuple{Float64,Float64,CategoricalValue{Char,UInt32},CategoricalValue{Char,UInt32}},Tuple{Continuous,Continuous,Multiclass{3},Multiclass{2}},10}



### The *mlj* convention

The table below summarizes the *mlj* convention for representing
scientific types:

`T`                               | `scitype(x)` for `x::T`                                                     | requires package
----------------------------------|:----------------------------------------------------------------------------|:------------------------
`Missing`                         | `Missing`                                                                   |
`AbstractFloat`                   | `Continuous`                                                                |
`Integer`                         |  `Count`                                                                    |
`CategoricalValue`                | `Multiclass{N}` where `N = nlevels(x)`, provided `x.pool.ordered == false`  | CategoricalArrays
`CategoricalString`               | `Multiclass{N}` where `N = nlevels(x)`, provided `x.pool.ordered == false`  | CategoricalArrays
`CategoricalValue`                | `OrderedFactor{N}` where `N = nlevels(x)`, provided `x.pool.ordered == true`| CategoricalArrays
`CategoricalString`               | `OrderedFactor{N}` where `N = nlevels(x)` provided `x.pool.ordered == true` | CategoricalArrays
`AbstractArray{<:Gray,2}`         | `GrayImage{W,H}` where `(W, H) = size(x)`                                   | ColorTypes
`AbstractArrray{<:AbstractRGB,2}` | `ColorImage{W,H}` where `(W, H) = size(x)`                                  | ColorTypes
any table type `T` supported by Tables.jl | `Table{K}` where `K=Union{column_scitypes...}`                      | Tables

Here `nlevels(x) = length(levels(x.pool))`.

*This notebook was generated using [Literate.jl](https://github.com/fredrikekre/Literate.jl).*
> 
