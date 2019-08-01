
## ScientificTypes

A light-weight interface for implementing conventions about the
scientific interpretation of data, and for performing type coercions
enforcing those conventions.

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
    │  ├─ Image
    │  │  ├─ ColorImage
    │  │  └─ GrayImage
    │  ├─ Infinite
    │  │  ├─ Continuous
    │  │  └─ Count
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
  tabular data.

The only core dependencies of ScientificTypes are Requires and
InteractiveUtils (from the standard library).

### Quick start

Install with `using Pkg; add ScientificTypes`.

Get the scientific type of some julia object, using the default
convention:


```julia
scitype(3.14)
```




    ScientificTypes.Continuous



#### Typical type coercion work-flow for tabular data


```julia
using CategoricalArrays, DataFrames, Tables
X = DataFrame(x1=1:5, x2=6:10, x3=11:15, x4=[16, 17, missing, 19, 20])
```




<table class="data-frame"><thead><tr><th></th><th>x1</th><th>x2</th><th>x3</th><th>x4</th></tr><tr><th></th><th>Int64</th><th>Int64</th><th>Int64</th><th>Int64⍰</th></tr></thead><tbody><p>5 rows × 4 columns</p><tr><th>1</th><td>1</td><td>6</td><td>11</td><td>16</td></tr><tr><th>2</th><td>2</td><td>7</td><td>12</td><td>17</td></tr><tr><th>3</th><td>3</td><td>8</td><td>13</td><td>missing</td></tr><tr><th>4</th><td>4</td><td>9</td><td>14</td><td>19</td></tr><tr><th>5</th><td>5</td><td>10</td><td>15</td><td>20</td></tr></tbody></table>




```julia
fix = Dict(:x1=>Continuous, :x2=>Continuous, :x3=>Multiclass, :x4=>OrderedFactor);
Xfixed = coerce(fix, X);
schema(Xfixed)
```

    ┌ Warning: Missing values encountered coercing scitype to ScientificTypes.OrderedFactor.
    │ Coerced to Union{Missing,ScientificTypes.OrderedFactor} instead. 
    └ @ ScientificTypes /Users/anthony/Dropbox/Julia7/MLJ/ScientificTypes/src/conventions/mlj/mlj.jl:5





    (names = (:x1, :x2, :x3, :x4), types = (Float64, Float64, CategoricalArrays.CategoricalValue{Int64,UInt8}, Union{Missing, CategoricalValue{Int64,UInt8}}), scitypes = (ScientificTypes.Continuous, ScientificTypes.Continuous, ScientificTypes.Multiclass{5}, Union{Missing, OrderedFactor{4}}))



Testing if each column of a table has a scientific type sub-typing
one of a specified list of scientific types:


```julia
scitype(Xfixed) <: Table(Continuous, Union{Finite, Missing})
```




    true



### Notes

- We regard the built-in julia type `Missing` as a scientific
  type. The new scientific types introduced in the current package
  are rooted in the abstract type `Found` (see tree above) and we
  export the alias `Scientific = Union{Missing, Found}`.

- `Finite{N}`, `Muliticlass{N}` and `OrderedFactor{N}` are all
  parameterized by an integer `N`. We export the alias `Binary =
  Multiclass{2}`.

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




    ScientificTypes.Continuous




```julia
scitype((2.718, 42))
```




    Tuple{ScientificTypes.Continuous,ScientificTypes.Count}




```julia
using CategoricalArrays
v = categorical(['a', 'c', 'a', missing, 'b'], ordered=true)
scitype(v[1])
```




    ScientificTypes.OrderedFactor{3}




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
w = coerce(Multiclass, v);
scitype(w)
```

    ┌ Warning: Missing values encountered coercing scitype to ScientificTypes.Multiclass.
    │ Coerced to Union{Missing,ScientificTypes.Multiclass} instead. 
    └ @ ScientificTypes /Users/anthony/Dropbox/Julia7/MLJ/ScientificTypes/src/conventions/mlj/mlj.jl:5





    AbstractArray{Union{Missing, Multiclass{3}},1}




```julia
using Tables
T = (x1=rand(10), x2=rand(10), x3=rand(10))
scitype(T)
```




    ScientificTypes.Table{AbstractArray{ScientificTypes.Continuous,1}}




```julia
using DataFrames
X = DataFrame(name=["Siri", "Robo", "Alexa", "Cortana"],
              height=[152, missing, 148, 163],
              rating=[1, 5, 2, 1]);
```


```julia
scitype(X)
```




    ScientificTypes.Table{Union{AbstractArray{Unknown,1}, AbstractArray{Union{Missing, Count},1}, AbstractArray{Count,1}}}




```julia
schema(X)
```




    (names = (:name, :height, :rating), types = (String, Union{Missing, Int64}, Int64), scitypes = (ScientificTypes.Unknown, Union{Missing, Count}, ScientificTypes.Count))




```julia
fix = Dict(:name=>Multiclass,
           :height=>Continuous,
           :rating=>OrderedFactor);
Xfixed = coerce(fix, X);
scitype(Xfixed)
```

    ┌ Warning: Missing values encountered coercing scitype to ScientificTypes.Continuous.
    │ Coerced to Union{Missing,ScientificTypes.Continuous} instead. 
    └ @ ScientificTypes /Users/anthony/Dropbox/Julia7/MLJ/ScientificTypes/src/conventions/mlj/mlj.jl:5





    ScientificTypes.Table{Union{AbstractArray{Multiclass{4},1}, AbstractArray{Union{Missing, Continuous},1}, AbstractArray{OrderedFactor{3},1}}}




```julia
scitype(Xfixed) <: Table(Continuous, Finite)
```




    false




```julia
scitype(Xfixed) <: Table(Union{Continuous, Missing}, Finite)
```




    true



### Compositional properties of scientific types

Note that under any convention, the scitype of a tuple is a `Tuple`
type parameterized by scientific types:


```julia
scitype((1, 4.5))
```




    Tuple{ScientificTypes.Count,ScientificTypes.Continuous}



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




    ScientificTypes.Table{Union{AbstractArray{Continuous,1}, AbstractArray{Multiclass{3},1}, AbstractArray{Multiclass{2},1}}}



A special constructor for the `Table` scientific type allows for
convenient checking of the scientific types of the columns:


```julia
scitype(X) <: Table(Continuous, Finite)
```




    true



For more details on the `Table` type and its constructor, do `?Table`.

Detailed inspection of column scientific types is included in an extended form of Tables.schema:


```julia
schema(X)
```




    (names = (:x1, :x2, :x3, :x4), types = (Float64, Float64, CategoricalArrays.CategoricalValue{Char,UInt32}, CategoricalArrays.CategoricalValue{Char,UInt32}), scitypes = (ScientificTypes.Continuous, ScientificTypes.Continuous, ScientificTypes.Multiclass{3}, ScientificTypes.Multiclass{2}))




```julia
schema(X).scitypes
```




    (ScientificTypes.Continuous, ScientificTypes.Continuous, ScientificTypes.Multiclass{3}, ScientificTypes.Multiclass{2})




```julia
typeof(schema(X))
```




    ScientificTypes.Schema{(:x1, :x2, :x3, :x4),Tuple{Float64,Float64,CategoricalArrays.CategoricalValue{Char,UInt32},CategoricalArrays.CategoricalValue{Char,UInt32}},Tuple{ScientificTypes.Continuous,ScientificTypes.Continuous,ScientificTypes.Multiclass{3},ScientificTypes.Multiclass{2}}}



### The *mlj* convention

The table below summarizes the *mlj* convention for representing
scientific types:

`T`                               | `scitype(x)` for `x::T`                                                     | requires package
----------------------------------|:----------------------------------------------------------------------------|:------------------------
`Missing`                         | `Missing`                                                                   |
`AbstractFloat`                   | `Continuous`                                                                |
`Integer`                         |  `Count`                                                                    |
`CategoricalValue`                | `Multiclass{N}` where `N = nlevels(x)`, provided `x.pool.ordered == false`  | CategoricalArrays.jl
`CategoricalString`               | `Multiclass{N}` where `N = nlevels(x)`, provided `x.pool.ordered == false`  | CategoricalArrays.jl
`CategoricalValue`                | `OrderedFactor{N}` where `N = nlevels(x)`, provided `x.pool.ordered == true`| CategoricalArrays.jl
`CategoricalString`               | `OrderedFactor{N}` where `N = nlevels(x)` provided `x.pool.ordered == true` | CategoricalArrays.jl
`AbstractArray{<:Gray,2}`         | `GrayImage`                                                                 | ColorTypes.jl
`AbstractArrray{<:AbstractRGB,2}` | `ColorImage`                                                                | ColorTypes
any table type `T` supported by Tables.jl | `Table{K}` where `K=Union{column_scitypes...}`                      | Tables.jl

Here `nlevels(x) = length(levels(x.pool))`.

*This notebook was generated using [Literate.jl](https://github.com/fredrikekre/Literate.jl).*
