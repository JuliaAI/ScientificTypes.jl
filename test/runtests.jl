using Test, ScientificTypes, ScientificTypesBase, Random
using Tables, CategoricalArrays, DataFrames
using ColorTypes, PersistenceDiagramsBase
using Dates
# using CSV # dropped until julia release new LTS as issue for 1.0
import Distributions

const Arr  = AbstractArray
const CArr = CategoricalArray
const Cat  = CategoricalValue
const Vec  = AbstractVector
const Dist = Distributions

include("type_tests.jl")
include("basic_tests.jl")
include("extra_tests.jl")
include("autotype.jl")
include("extra_coercion.jl")

include("coverage.jl")
