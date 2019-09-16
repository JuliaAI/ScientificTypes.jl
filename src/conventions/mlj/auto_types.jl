export autotype

get_nonmissing_type(::Type{<:Union{Missing, T}}) where T = T

function sugg_finite(::Type{T}) where T
   T <: Real && return OrderedFactor
   return Multiclass
end

function sugg_infinite(::Type{T}) where T
   T <: AbstractFloat && return Continuous
   T <: Integer       && return Count
   return Unknown
end

"""
suggest_scitype(type, col, nrows)

For a column `col` with element type `type` and `nrows` rows, try to suggest an appropriate
scitype in cases which would otherwise be typed as `Unknown` namely when there are few
unique values as compared to the total number of rows.

The heuristic used is as follows:

1. there's ≤ 3 unique values with more than 5 rows, use the `MultiClass{N}` type
2. there's less than 10% unique values out of the number of rows **or** there's fewer than
   100 unique values (whichever one is smaller):
      a. if it's a Real type, return as `OrderedFactor`
      b. if it's something else (e.g. a `String`) return as `MultiClass{N}`

Otherwise fall back to the default typing.
"""
function sugg_scitype(type, col, nrows)
   unique_vals    = unique(skipmissing(col))
   nunique_vals   = length(unique_vals)
   used_heuristic = false
   # Heuristic 1
   if nunique_vals ≤ 3 && nrows ≥ 5
      used_heuristic = true
      if type >: Missing
         ST = Union{Missing, Multiclass}
      else
         ST = Multiclass
      end
   # Heuristic 2
   elseif nunique_vals ≤ max(min(0.1*nrows, 100), 4)
      used_heuristic = true
      if type >: Missing
         ST = Union{Missing, sugg_finite(get_nonmissing_type(type))}
      else
         ST = sugg_finite(type)
      end
   else
      if type >: Missing
         ST = Union{Missing, sugg_infinite(get_nonmissing_type(type))}
      else
         ST = sugg_infinite(type)
      end
   end
   return ST, used_heuristic
end

"""
autotype(X)

Return a dictionary of suggested types for each column of `X`.
See also [`suggest_scitype`](@ref).

## Kwargs

* `only_suggestions=false`: if true, return only a dictionary of the names for which applying
autotype differs from just using scitype.
"""
function autotype(X; only_suggestions::Bool=false)
   @assert Tables.istable(X) "auto_types only works with tabular data."
   sch = schema(X)
   suggested_types = Dict{Symbol,Type{<:Union{Missing,Found}}}()
   # keep track of the types for which the suggestion is different
   # than what would have been given by just using the convention
   suggestions     = Symbol[]
   for (name, type, col) in zip(sch.names, sch.types, Tables.eachcolumn(X))
      sugg_type, used_heuristic = sugg_scitype(type, col, sch.nrows)
      suggested_types[name]     = sugg_type
      used_heuristic && push!(suggestions, name)
   end
   only_suggestions && filter!(e -> first(e) in suggestions, suggested_types)
   return suggested_types
end
