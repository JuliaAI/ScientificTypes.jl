module ScientificTypes

# Dependencies
using ScientificTypesBase
using Tables
using CategoricalArrays
using ColorTypes
using PersistenceDiagramsBase
using PrettyTables
using Dates

import StatisticalTraits: info
import TableOperations
# re-exports from ScientificTypes
export Scientific, Found, Unknown, Known, Finite, Infinite,
    OrderedFactor, Multiclass, Count, Continuous, Textual,
    Binary, ColorImage, GrayImage, Image, Table,
    ScientificTimeType, ScientificDate, ScientificDateTime,
    ScientificTime
export scitype, scitype_union, elscitype, nonmissing, trait

# re-export from StatisticalTraits
export info

# exports
export coerce, coerce!, autotype, schema

# -------------------------------------------------------------
# Abbreviations

const ST   = ScientificTypesBase
const Arr  = AbstractArray
const CArr = CategoricalArray
const Cat  = CategoricalValue
const SCHEMA_SPECIALIZATION_THRESHOLD = 67000 # use same as that of Tables.jl

# Indicate the convention, see init.jl where it is set.
struct DefaultConvention <: Convention end

include("init.jl")

# -------------------------------------------------------------
# Includes

include("coerce.jl")
include("schema.jl")
include("autotype.jl")

include("convention/scitype.jl")
include("convention/coerce.jl")

end # module
