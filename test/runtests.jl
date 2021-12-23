using Test, ScientificTypes, ScientificTypesBase, Random
using Tables, CategoricalArrays, DataFrames
using ColorTypes
using Dates

# using CSV # dropped until julia release new LTS as issue for 1.0
import Distributions

const Dist = Distributions
const Arr  = AbstractArray
const CArr = CategoricalArray
const Cat  = CategoricalValue
const Vec  = AbstractVector

include("convention/coerce.jl")
include("convention/scitype.jl")

include("autotype.jl")
include("coerce.jl")
include("schema.jl")
