module ScientificTypes 

# Dependencies
using Reexport
@reexport using ScientificTypesBase
export scitype, elscitype, scitype_union
using Tables
using CategoricalArrays
using ColorTypes
using PrettyTables
using Dates
import Distributions

# exports
export coerce, coerce!, autotype, schema, levels, levels!

# --------------------------------------------------------------------------------------
# Abbreviations

const ST  = ScientificTypesBase
const Arr = AbstractArray
const CArr = CategoricalArray
const Cat = CategoricalValue
const COLS_SPECIALIZATION_THRESHOLD = 30
const ROWS_SPECIALIZATION_THRESHOLD = 10000
const SCHEMA_SPECIALIZATION_THRESHOLD = Tables.SCHEMA_SPECIALIZATION_THRESHOLD

#---------------------------------------------------------------------------------------
# Define convention

struct DefaultConvention <: Convention end
const CONV = DefaultConvention()

# -------------------------------------------------------------
# vtrait function, returns either `Val{:table}()` or `Val{:other}()`

# To address https://github.com/JuliaData/Tables.jl/issues/306:
const DictColumnsWithStringKeys = AbstractDict{K, V} where {
    K <: AbstractString,
    V <: AbstractVector
}
const DictRowsWithStringKeys = AbstractVector{T} where {
T <: AbstractDict{<:AbstractString}
}
_istable(::DictColumnsWithStringKeys) = false
_istable(::DictRowsWithStringKeys) = false
_istable(something_else) = Tables.istable(something_else)

vtrait(X) = Val{ifelse(_istable(X), :table, :other)}()

# -------------------------------------------------------------
# Includes

include("coerce.jl")
include("schema.jl")
include("autotype.jl")

include("convention/scitype.jl")
include("convention/coerce.jl")

end # module
