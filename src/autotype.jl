"""
    nrows(X)

Internal method that return the number of rows a table `X` has.

**Note**
A more general version of this method is defined in `MLJModelInterface.jl`.
This method is needed here in order for `auto_type` method to run. 
"""
function nrows(X)
    if !Tables.istable(X)
        throw(ArgumentError("input argument must be a Tables.jl compatible table"))
    end
    if Tables.rowaccess(X)
        rows = Tables.rows(X)
        return _nrows_rat(Base.IteratorSize(typeof(rows)), rows)
        
    else
        cols = Tables.columns(X)
        return _nrows_cat(cols)
    end
end

# number of rows for columnaccessed table
function _nrows_cat(cols)
    names = Tables.columnnames(cols)
    !isempty(names) || return 0
    return length(Tables.getcolumn(cols, names[1]))
end

# number of rows for rowaccessed table
_nrows_rat(::Base.HasShape, rows) = size(rows, 1)
_nrows_rat(::Base.HasLength, rows) = length(rows)
_nrows_rat(iter_size, rows) = length(collect(rows))

"""
    autotype(X; kw...)

Return a dictionary of suggested scitypes for each column of `X`, a table or
an array based on rules

## Kwargs

* `only_changes=true`:       if true, return only a dictionary of the names for
                              which applying autotype differs from just using
                              the ambient convention. When coercing with
                              autotype, `only_changes` should be true.
* `rules=(:few_to_finite,)`: the set of rules to apply.
"""
autotype(X; kw...) = _autotype(X, vtrait(X); kw...)

# For an array object (trait:other)
function _autotype(X::Arr, ::Val{:other};
                   rules::NTuple{N,Symbol} where N=(:few_to_finite,))
    # check that the rules are recognised
    _check_rules(rules)
    # inspect the current element scitype
    sugg_type = elscitype(X)
    # apply rules in sequence
    np = prod(size(X))
    for rule in rules
        if rule === :few_to_finite
            col = vec(X) # needed to compute unique values
            sugg_type = eval(:($rule($sugg_type, $col, $np)))
        else
            col = view(X, :, 1) # only needed for eltype
            sugg_type = eval(:($rule($sugg_type, $col, $np)))
        end
    end
    return sugg_type
end

# For a table object (trait:table)
function _autotype(X, ::Val{:table}; only_changes::Bool=true,
                  rules::NTuple{N,Symbol} where N=(:few_to_finite,))
    # check that the rules are recognised
    _check_rules(rules)
    # recuperate the schema of `X`
    sch = schema(X)
    # dictionary to keep track of the suggested types
    suggested_types = Dict{Symbol,Type{<:Any}}()
    # keep track of the column names for which the suggested type is different
    # than the convention one
    has_changed = Symbol[]
    # go over each column and for each of them apply the rules in order
    # in which they were provided
    columns = Tables.columns(X)
    cols = (Tables.getcolumn(columns, c)
            for c in Tables.columnnames(columns)) |> Tuple
    zipper = zip(sch.names, sch.types, sch.scitypes, cols)
    for (name, machine_type, stype, col) in zipper
        # start with the data type and iterate over the rules to get
        # a suggested type, note that this loop is type unstable but it
        # doesn't really matter, there are few rules and sugg is fast
        sugg_type = stype
        for rule in rules
            sugg_type = eval(:($rule($sugg_type, $col, $(nrows(X)))))
        end
        # store the suggested type
        suggested_types[name] = sugg_type
        # check if the suggested type is different than the scitype
        # if so, push it to has_changed to aid an eventual filtering
        if sugg_type != stype
            push!(has_changed, name)
        end
    end
    if only_changes
        filter!(e -> first(e) in has_changed, suggested_types)
    end
    return suggested_types
end

# convenience functions to pass a single rule at the time
autotype(X, rule::Symbol; args...) =
    autotype(X; rules=(rule,), args...)
# convenience function to splat rules
autotype(X, rules::NTuple{N,Symbol} where N; args...) =
    autotype(X; rules=rules, args...)

# -----------------------------------------------------------------
# rules

function _check_rules(rules::NTuple{N,Symbol} where N)
    for rule in rules
        rule in (:few_to_finite,
                 :discrete_to_continuous,
                 :string_to_multiclass) ||
                 throw(ArgumentError("Rule $rule not recognised."))
    end
    return nothing
end

"""
    few_to_finite(type, col, nrows)

For a column `col` with element type `type` and `nrows` rows, check if there
are relatively few values as compared to the number of rows. The heuristic
for "few" is as follows:
1. there are ≤ 3 unique values with more than 5 rows, use `MultiClass{N}` type
2. there are less than 10% unique values out of the number of rows **or**
    there's fewer than 100 unique values (whichever one is smaller):

In both cases:
a. if it's a Real type, return as `OrderedFactor`
b. if it's something else (e.g. a `String`) return as `MultiClass{N}`
"""
function few_to_finite(type::Type, col, nrows::Int)
    nonmissing(type) <: Finite && return type
    unique_vals  = unique(skipmissing(col))
    coltype      = eltype(col)
    nunique_vals = length(unique_vals)
    if nunique_vals ≤ 3 && nrows ≥ 5 ||             # H1
       nunique_vals ≤ max(min(0.1 * nrows, 100), 4) # H2
        # suggest a type
        T = sugg_finite(coltype)
        return T_or_Union_Missing_T(coltype, T)
    end
    return type
end

"""
    discrete_to_continuous(type, _, _)

Return `Continuous` if the current type is either `Count` or `Integer`,
otherwise return the type unchanged.
"""
function discrete_to_continuous(type::Type, _, _)
    if nonmissing(type) <: Union{Count,Integer}
        return T_or_Union_Missing_T(type, Continuous)
    end
    return type
end

"""
    string_to_multiclass(type, col, _)

For a column with element type `<: AbstractString` or `<: AbstractChar` return
Multiclass irrelevant of how many unique values there are. This rule is only
applied on columns which are `Textual` or `Unknown`.
"""
function string_to_multiclass(type::Type, col, _)
    nonmissing(type) in (Textual, Unknown) || return type
    etc = eltype(col)
    if nonmissing(etc) <: Union{AbstractChar,AbstractString}
        return T_or_Union_Missing_T(etc, Multiclass)
    end
    return type
end

# -----------------------------------------------------------------
# Helper functions for the rules

"""
    sugg_finite(type)

Helper function to suggest a finite type corresponding to `T` when there are
few unique values.
"""
function sugg_finite(::Type{<:Union{Missing,T}}) where T
    T <: Real && return OrderedFactor
    return Multiclass
end

"""
    T_or_Union_Missing_T(type, T)

Helper function to return either `T` or `Union{Missing,T}`.
"""
function T_or_Union_Missing_T(type::Type, T::Type)
    return ifelse(type >: Missing, Union{Missing, T}, T)
end
