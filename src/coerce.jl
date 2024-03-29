const ColKey = Union{Symbol, AbstractString}

"""
    coerce(A, S)

Return new version of the array `A` whose scientific element type is `S`.

```
julia> v = coerce([3, 7, 5], Continuous)
3-element Vector{Float64}:
 3.0
 7.0
 5.0

julia> scitype(v)
AbstractVector{Continuous}

```
    coerce(X, specs...; tight=false, verbosity=1)

Given a table `X`, return a copy of `X`, ensuring that the element
scitypes of the columns match the new specification, `specs`. There
are three valid specifications:

(i) one or more `column_name=>Scitype` pairs:

    coerce(X, col1=>Scitype1, col2=>Scitype2, ... ; verbosity=1)

(ii) one or more `OldScitype=>NewScitype` pairs (`OldScitype` covering
both the `OldScitype` and `Union{Missing,OldScitype}` cases):

    coerce(X, OldScitype1=>NewScitype1, OldScitype2=>NewScitype2, ... ; verbosity=1)

(iii) a dictionary of scientific types keyed on column names:

    coerce(X, d::AbstractDict{<:ColKey, <:Type}; verbosity=1)

where `ColKey = Union{Symbol,AbstractString}`.

### Examples

Specifying  `column_name=>Scitype` pairs:

```
using CategoricalArrays, DataFrames, Tables
X = DataFrame(name=["Siri", "Robo", "Alexa", "Cortana"],
              height=[152, missing, 148, 163],
              rating=[1, 5, 2, 1])
Xc = coerce(X, :name=>Multiclass, :height=>Continuous, :rating=>OrderedFactor)
schema(Xc).scitypes # (Multiclass, Continuous, OrderedFactor)
```

Specifying `OldScitype=>NewScitype` pairs:

```
X  = (x = [1, 2, 3],
      y = rand(3),
      z = [10, 20, 30])
Xc = coerce(X, Count=>Continuous)
schema(Xfixed).scitypes # (Continuous, Continuous, Continuous)
```
"""
coerce(X, a...; kw...) = coerce(vtrait(X), X, a...; kw...)

# Non tabular data is not supported
coerce(::Val{:other}, X, a...; kw...) =
    throw(CoercionError("`coerce` is undefined for non-tabular data."))


_bad_dictionary() = throw(ArgumentError(
    "A dictionary specifying a scitype conversion "*
    "must have type `AbstractDict{<:ColKey, <:Type}`. It's keys must "*
    "be column names and its values be scientific types. "*
    "E.g., `Dict(:cats=>Continuous, :dogs=>Textual`. "))
coerce(::Val{:table}, X, types_dict::AbstractDict; kw...) =
    _bad_dictionary()

_bad_specs() =
        throw(ArgumentError(
        "Invalid `specs` in `coerce(X, specs...;  kwargs...)`. "*
        "Valid `specs` are: (i) one or more pairs of "*
        "the form `column_name=>Scitype`; (ii) one or more pairs "*
        "of the from `OldScitype=>NewScitype`; or (iii) a "*
        "dictionary of scientific "*
        "types keyed on column names. "))
coerce(::Val{:table}, X, specs...; kw...) = _bad_specs()

function coerce(::Val{:table},
                X,
                types_dict::AbstractDict{<:ColKey, <:Type};
                kw...)
    isempty(types_dict) && return X
    names  = schema(X).names
    X_ct   = Tables.columntable(X)
    ct_new = (_coerce_col(X_ct, col, types_dict; kw...) for col in names)
    return Tables.materializer(X)(NamedTuple{names}(ct_new))
end

# -------------------------------------------------------------
# utilities for coerce

struct CoercionError <: Exception
    m::String
end

function _coerce_col(Xcol,
                     name,
                     types_dict::AbstractDict{Symbol, <:Type};
                     kw...)
    y = Tables.getcolumn(Xcol, name)
    if haskey(types_dict, name)
        coerce_type = types_dict[name]
        return coerce(y, coerce_type; kw...)
    end
    return y
end

# -------------------------------------------------------------
# alternative ways to do coercion, both for coerce and coerce!

# The following extends the two methods so that a mixture of
# symbol=>type and type=>type pairs can be specified in place of a
# dictionary:

feature_scitype_pairs(p::Pair{<:ColKey,<:Type}, X) = [Symbol(first(p)) => last(p), ]
function feature_scitype_pairs(p::Pair{<:Type,<:Type}, X)
    from_scitype = first(p)
    to_scitype = last(p)
    sch = schema(X)
    ret = Pair{Symbol,Type}[]
    for j in eachindex(sch.names)
        if sch.scitypes[j] <: Union{Missing,from_scitype}
            push!(ret, Pair(sch.names[j], to_scitype))
        end
    end
    return ret
end

for c in (:coerce, :coerce!)
    ex = quote
        function $c(::Val{:table},
                    X,
                    mixed_pairs::Pair{<:Union{<:ColKey,<:Type},<:Type}...;
                    kw...)
            components = map(p -> feature_scitype_pairs(p, X), mixed_pairs)
            pairs = vcat(components...)

            # must construct dictionary by hand to check no conflicts:
            scitype_given_feature = Dict{Symbol,Type}()
            for p in pairs
                feature = first(p)
                if haskey(scitype_given_feature, feature)
                    throw(ArgumentError("`coerce` argments cannot be "*
                                        "resolved to determined a "*
                                        "*unique* scitype for each "*
                                        "feature. "))
                else
                    scitype_given_feature[feature] = last(p)
                end
            end

            return $c(X, scitype_given_feature; kw...)
        end
    end
    eval(ex)
end

# -------------------------------------------------------------
# In place coercion

"""
coerce!(X, ...)

Same as [`ScientificTypes.coerce`](@ref) except it does the
modification in place provided `X` supports in-place modification (eg,
DataFrames). An error is thrown otherwise. The arguments are the same
as `coerce`.

"""
coerce!(X, a...;  kw...) = begin
    coerce!(vtrait(X), X, a...; kw...)
end

coerce!(::Val{:other}, X, a...; kw...) =
    throw(CoercionError("`coerce!` is undefined for non-tabular data."))

coerce!(::Val{:table}, X, types_dict::AbstractDict; kw...) =
    _bad_dictionary()

coerce!(::Val{:table}, X, specs...; kw...) = _bad_specs()

function coerce!(::Val{:table},
                 X,
                 types_dict::AbstractDict{<:ColKey, <:Type};
                 kw...)
    # DataFrame --> coerce_df!
    if is_type(X, :DataFrames, :DataFrame)
        return coerce_df!(X, types_dict; kw...)
    end
    # Everything else
    throw(ArgumentError("In place coercion not supported for $(typeof(X))." *
                        "Try `coerce` instead."))
end

# -------------------------------------------------------------
# utilities for coerce!

"""
    coerce_df!(df, pairs...; kw...)

In place coercion for a dataframe.(Unexported method)
"""
function coerce_df!(df, tdict::AbstractDict{<:ColKey, <:Type}; kw...)
    names = schema(df).names
    for name in names
        name in keys(tdict) || continue
        coerce_type = tdict[name]
        df[!, name] = coerce(df[!, name], coerce_type; kw...)
    end
    return df
end


"""
    is_type(X, spkg, stype)

Check that an object `X` is of a given type that may be defined in a package
that is not loaded in the current environment.
As an example say `DataFrames` is not loaded in the current environment, a
function from some package could still return a DataFrame in which case it
can be checked with

```
is_type(X, :DataFrames, :DataFrame)
```
"""
function is_type(X, spkg::Symbol, stype::Symbol)
    # If the package is loaded, then it will just be `stype`
    # otherwise it will be `spkg.stype`
    rx = Regex("^($spkg\\.)?$stype")
    return ifelse(match(rx, "$(typeof(X))") === nothing, false, true)
end
