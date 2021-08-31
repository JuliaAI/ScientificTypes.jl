module ScientificTypes

# Dependencies
using Reexport
@reexport using ScientificTypesBase
using Tables
using CategoricalArrays
using ColorTypes
using PersistenceDiagramsBase
using CorpusLoaders
using PrettyTables
using Dates
import Distributions

import StatisticalTraits: info

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
