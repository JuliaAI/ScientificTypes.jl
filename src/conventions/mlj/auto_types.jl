export auto_types

"""
suggest_scitype(type, col, nrows)

For a column `col` with element type `type` and `nrows` rows, try to suggest an appropriate
scitype in cases which would otherwise be typed as "unknown" namely when there are few
unique values as compared to the total number of rows.

The heuristic used is as follows:

1. there's ≤ 3 unique values with more than 5 rows, use the `MultiClass{N}` type
2. there's less than 10% unique values out of the number of rows **or** there's fewer than
   100 unique values (whichever one is smaller):
      a. if it's a Real type, return as `OrderedFactor`
      b. if it's something else (e.g. a `String`) return as `MultiClass{N}`

Otherwise fall back to the default typing.
"""
function suggest_scitype(type, col, nrows)
   # TODO: deal with missing/union (?)
   unique_vals  = unique(skipmissing(col))
   nunique_vals = length(unique_vals)
   # Heuristic 1
   if nunique_vals ≤ 3 && nrows ≥ 5
      return Multiclass{nunique_vals}
   # Heuristic 2
   elseif nunique_vals ≤ max(min(0.1*nrows, 100), 4)
      type <: Real && return OrderedFactor{nunique_vals}
      return Multiclass{nunique_vals}
   else
      type <: AbstractFloat  && return Continuous
      type <: Integer        && return Count
      return Unknown
   end
end

"""
auto_types(X)

Return a dictionary of suggested types for each column of `X`.
See also [`suggest_scitype`](@ref).
"""
function auto_types(X)
   sch = schema(X)
   suggested_types = Dict{Symbol,Type{<:Found}}()
   for (name, type, col) in zip(sch.names, sch.types, Tables.eachcolumn(X))
      suggested_types[name] = suggest_scitype(type, col, sch.nrows)
   end
   return suggested_types
end
