using Test
using ScientificTypes
using CategoricalArrays
using Tables
using ColorTypes
using Random
using CSV

const S = ScientificTypes

include("type_tests.jl")

include("basic_tests.jl")

include("extra_tests.jl")

include("autotype.jl")
