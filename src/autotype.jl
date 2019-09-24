export autotype

"""
autotype(X)

Return a dictionary of suggested types for each column of `X`.
See also [`suggest_scitype`](@ref).

## Kwargs

* `only_changes=false`: if true, return only a dictionary of the names for which applying
autotype differs from just using the ambient convention.
* `rules=(:few_to_finite,)`: the set of rules to apply.
"""
function autotype(X; only_changes::Bool=false,
                  rules::NTuple{N,Symbol} where N=(:few_to_finite,))
    # check that X is a table
    @assert Tables.istable(X) "The function `autotype` requires tabular data."
    # check that the rules are recognised
    for rule in rules
        @assert rule in (:few_to_finite, :discrete_to_continuous,
                         :string_to_class) "Rule $rule not recognised."
    end
    # recuperate the schema of `X`
    sch = schema(X)
    # dictionary to keep track of the suggested types
    suggested_types  = Dict{Symbol,Type{<:Scientific}}()
    # keep track of the column names for which the suggested type is different
    # than the convention one
    has_changed = Symbol[]
    # go over each column and for each of them apply the rules in order
    # in which they were provided
    zipper = zip(sch.names, sch.types, sch.scitypes, Tables.eachcolumn(X))
    for (name, type, scitype, col) in zipper
        # start with the data type and iterate over the rules to get
        # a suggested type, note that this loop is type unstable but it
        # doesn't really matter, there are few rules and sugg is fast
        sugg_type = scitype
        for rule in rules
            sugg_type = eval(:($rule($sugg_type, $col, $sch.nrows)))
        end
        # store the suggested type
        suggested_types[name] = sugg_type
        # check if the suggested type is different than the scitype
        # if so, push it to has_changed to aid an eventual filtering
        if sugg_type != scitype
            push!(has_changed, name)
        end
    end
    if only_changes
        filter!(e -> first(e) in has_changed, suggested_types)
    end
    return suggested_types
end


"""
few_to_finite

For a column `col` with element type `type` and `nrows` rows, check if there are relatively
few values as compared to the number of rows. The heuristic for "few" is as follows:

1. there's ≤ 3 unique values with more than 5 rows, use the `MultiClass{N}` type
2. there's less than 10% unique values out of the number of rows **or** there's fewer than
    100 unique values (whichever one is smaller):
        a. if it's a Real type, return as `OrderedFactor`
        b. if it's something else (e.g. a `String`) return as `MultiClass{N}`
"""
function few_to_finite(type::Type, col, nrows::Int)
    nonmissing(type) <: Finite && return type
    unique_vals  = unique(skipmissing(col))
    coltype      = eltype(col)
    nunique_vals = length(unique_vals)
    # -----------
    # Heuristic 1
    if nunique_vals ≤ 3 && nrows ≥ 5
        return T_or_Union_Missing_T(coltype, Multiclass)
    # -----------
    # Heuristic 2
    elseif nunique_vals ≤ max(min(0.1 * nrows, 100), 4)
        T = sugg_finite(coltype)
        return T_or_Union_Missing_T(coltype, T)
    end
    return type
end


"""
discrete_to_continuous

For a column with element type `<: Count` or `<: Integer` return Continuous.
Note that it doesn't touch features already marked as `Finite`.
"""
function discrete_to_continuous(type::Type, _, _)
    nonmissing(type) <: Union{Count,Integer} && return T_or_Union_Missing_T(type, Continuous)
    return type
end


"""
string_to_class

For a column with element type `<: AbstractString` or `<: AbstractChar` return Multiclass
irrelevant of how many unique values there are. This rule is only applied on columns which
are still considered to be `Unknown`.
"""
function string_to_class(type::Type, col, _)
    nonmissing(type) <: Unknown || return type
    etc = eltype(col)
    if nonmissing(etc) <: Union{AbstractChar,AbstractString}
        return T_or_Union_Missing_T(etc, Multiclass)
    end
    return type
end

# ------------------------------
# Helper functions for the rules
# ------------------------------

"""
sugg_finite(type)

Helper function to suggest a finite type corresponding to `T` when there are few unique values.
See [`suggest_scitype`](@ref).
"""
function sugg_finite(::Type{<:Union{Missing,T}}) where T
    T <: Real && return OrderedFactor
    return Multiclass
end

"""
T_or_Union_Missing_T

Helper function to return either `T` or `Union{Missing,T}`.
"""
T_or_Union_Missing_T(type::Type, T::Type) = ifelse(type >: Missing, Union{Missing, T}, T)

if VERSION < v"1.3"
    """
    nonmissingtype(TT)

    Return the type `T` if the type is a `Union{Missing,T}` or `T`.
    """
    nonmissingtype(::Type{T}) where T = T isa Union ? ifelse(T.a == Missing, T.b, T.a) : T
    # see also discourse.julialang.org/t/get-non-missing-type-in-the-case-of-parametric-type/29109
end
nonmissing = nonmissingtype
