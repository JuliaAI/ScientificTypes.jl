# ## ScientificTypes

# A light-weight interface for implementing conventions about the
# scientific interpretation of data, and for performing type coercions
# enforcing those conventions.

# ScientificTypes provides:

# - A hierarchy of new julia types representing scientific data types
#   for use in method dispatch (eg, for trait values). Instances of
#   the types play no role:

using ScientificTypes, AbstractTrees 
ScientificTypes.tree()

# - A single method `scitype` for articulating a convention about what
#   scientific type each julia object can represent. For example, one
#   might declare `scitype(::AbstractFloat) = Continuous`.

# - A default convention called *mlj*, based on optional dependencies
#   CategoricalArrays, ColorTypes, and Tables, which includes a convenience
#   method `coerce` for performing scientific type coercion on
#   AbstractVectors and columns of tabular data (any table
#   implementing the
#   [Tables.jl](https://github.com/JuliaData/Tables.jl) interface). A
#   table at the end of this document details the convention.

# - A `schema` method for tabular data, based on the optional Tables
#   dependency, for inspecting the machine and scientific types of
#   tabular data.

# The only core dependencies of ScientificTypes are Requires and
# InteractiveUtils (from the standard library).


# ### Quick start

# Install with `using Pkg; add ScientificTypes`.

# Get the scientific type of some julia object, using the default
# convention:

scitype(3.14)


# #### Typical type coercion work-flow for tabular data

using CategoricalArrays, DataFrames, Tables
X = DataFrame(x1=1:5, x2=6:10, x3=11:15, x4=[16, 17, missing, 19, 20])

#-

fix = Dict(:x1=>Continuous, :x2=>Continuous, :x3=>Multiclass, :x4=>OrderedFactor);
Xfixed = coerce(fix, X);
schema(Xfixed)

# Testing if each column of a table has a scientific type sub-typing
# one of a specified list of scientific types:

scitype(Xfixed) <: Table(Continuous, Union{Finite, Missing})


# ### Notes

# - We regard the built-in julia type `Missing` as a scientific
#   type. The new scientific types introduced in the current package
#   are rooted in the abstract type `Found` (see tree above) and we
#   export the alias `Scientific = Union{Missing, Found}`.

# - `Finite{N}`, `Muliticlass{N}` and `OrderedFactor{N}` are all
#   parameterized by an integer `N`. We export the alias `Binary =
#   Multiclass{2}`.

# - The function `scitype` has the fallback value `Unknown`.

# - Since Tables is an optional dependency, the `scitype` of a
#   Tables.jl supported table is `Unknown` unless Tables has been imported.

# - Developers can define their own conventions using the code in
#   "src/conventions/mlj/" as a template. The active convention is
#   controlled by the value of `ScientificTypes.CONVENTION[1]`.


# ### Detailed usage examples

using ScientificTypes

# Activate a convention:

mlj() # redundant, as the default

#-

scitype(3.142)

#-

scitype((2.718, 42))

#-

using CategoricalArrays
v = categorical(['a', 'c', 'a', missing, 'b'], ordered=true)
scitype(v[1])

#-

scitype(v)

#-

v = [1, 2, missing, 3];
scitype(v)

#-

w = coerce(Multiclass, v);
scitype(w)

#-

using Tables
T = (x1=rand(10), x2=rand(10), x3=rand(10))
scitype(T)

#-
using DataFrames
X = DataFrame(name=["Siri", "Robo", "Alexa", "Cortana"],
              height=[152, missing, 148, 163],
              rating=[1, 5, 2, 1]);

#-

scitype(X) 

#-

schema(X)

#-

fix = Dict(:name=>Multiclass,
           :height=>Continuous,
           :rating=>OrderedFactor);
Xfixed = coerce(fix, X);
scitype(Xfixed)

#-

scitype(Xfixed) <: Table(Continuous, Finite)

#-

scitype(Xfixed) <: Table(Union{Continuous, Missing}, Finite)


# ### Compositional properties of scientific types

# Note that under any convention, the scitype of a tuple is a `Tuple`
# type parameterized by scientific types:

scitype((1, 4.5))

# Similarly, the scitype of an `AbstractArray` object is
# `AbstractArray{U}`, where `U` is the union of the element scitypes:

scitype([1,2,3, missing])

# Provided the [Tables]() package is loaded, any table implementing
# the Tables interface has a scitype encoding the scitypes of its
# columns:

using CategoricalArrays
using Tables
X = (x1=rand(10),
     x2=rand(10),
     x3=categorical(rand("abc", 10)),
     x4=categorical(rand("01", 10)))
scitype(X)

# A special constructor for the `Table` scientific type allows for
# convenient checking of the scientific types of the columns:

scitype(X) <: Table(Continuous, Finite)

# For more details on the `Table` type and its constructor, do `?Table`.

# Detailed inspection of column scientific types is included in an extended form of Tables.schema:

schema(X)

#-

schema(X).scitypes

#-

typeof(schema(X))


# ### The *mlj* convention

# The table below summarizes the *mlj* convention for representing
# scientific types:

# `T`                               | `scitype(x)` for `x::T`                                                     | requires package 
# ----------------------------------|:----------------------------------------------------------------------------|:------------------------
# `Missing`                         | `Missing`                                                                   |
# `AbstractFloat`                   | `Continuous`                                                                | 
# `Integer`                         |  `Count`                                                                    |
# `CategoricalValue`                | `Multiclass{N}` where `N = nlevels(x)`, provided `x.pool.ordered == false`  | CategoricalArrays.jl
# `CategoricalString`               | `Multiclass{N}` where `N = nlevels(x)`, provided `x.pool.ordered == false`  | CategoricalArrays.jl
# `CategoricalValue`                | `OrderedFactor{N}` where `N = nlevels(x)`, provided `x.pool.ordered == true`| CategoricalArrays.jl
# `CategoricalString`               | `OrderedFactor{N}` where `N = nlevels(x)` provided `x.pool.ordered == true` | CategoricalArrays.jl
# `AbstractArray{<:Gray,2}`         | `GrayImage`                                                                 | ColorTypes.jl
# `AbstractArrray{<:AbstractRGB,2}` | `ColorImage`                                                                | ColorTypes
# any table type `T` supported by Tables.jl | `Table{K}` where `K=Union{column_scitypes...}`                      | Tables.jl

# Here `nlevels(x) = length(levels(x.pool))`.














 

