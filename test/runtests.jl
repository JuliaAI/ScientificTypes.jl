using Test, ScientificTypes, ScientificTypesBase, Random
using Tables, CategoricalArrays, CSV, DataFrames
using ColorTypes, PersistenceDiagramsBase
using Dates

const Arr  = AbstractArray
const CArr = CategoricalArray
const Cat  = CategoricalValue
const Vec  = AbstractVector

include("type_tests.jl")
include("basic_tests.jl")
include("extra_tests.jl")
include("autotype.jl")
include("extra_coercion.jl")

include("coverage.jl")
