using Test
using ScientificTypes
using CategoricalArrays
using Tables

using ColorTypes
using Random
using DataFrames
using CSV

const S = ScientificTypes
const M = S.MLJ()

const Arr  = AbstractArray
const Vec  = AbstractVector
const CArr = CategoricalArray

include("type_tests.jl")

include("basic_tests.jl")

include("extra_tests.jl")

include("autotype.jl")

include("mlj.jl")
