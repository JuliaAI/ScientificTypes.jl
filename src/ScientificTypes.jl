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
vtrait(X) = Val{ifelse(Tables.istable(X), :table, :other)}()

# -------------------------------------------------------------
# Includes

include("coerce.jl")
include("schema.jl")
include("autotype.jl")

include("convention/scitype.jl")
include("convention/coerce.jl")

end # module
