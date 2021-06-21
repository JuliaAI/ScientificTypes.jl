"""
    coerce(A, specs...; tight=false, verbosity=1)

Given a table `A`, return a copy of `A`, ensuring that the element
scitypes of the columns match the new specification, `specs`. There
are three valid specifiations:

(i) one or more `column_name=>Scitype` pairs:

    coerce(X, col1=>Sciyype1, col2=>Scitype2, ... ; verbosity=1)

(ii) one or more `OldScitype=>NewScitype` pairs (`OldScitype` covering
both the `OldScitype` and `Union{Missing,OldScitype}` cases):

    coerce(X, OldScitype1=>NewSciyype1, OldScitype2=>NewScitype2, ... ; verbosity=1)

(iii) a dictionary of scientific types keyed on column names:

    coerce(X, d::AbstractDict{Symbol, <:Type}; verbosity=1)

### Examples

Specifiying  `column_name=>Scitype` pairs:

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
coerce(X, a...; kw...) = coerce(Val(ST.trait(X)), X, a...; kw...)

# Non tabular data is not supported
coerce(::Val{:other}, X, a...; kw...) =
    throw(CoercionError("`coerce` is undefined for non-tabular data."))


_bad_dictionary() = throw(ArgumentError(
    "A dictionary specifying a scitype conversion "*
    "must have type `AbstractDict{Symbol, <:Type}`. It's keys must "*
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
                types_dict::AbstractDict{Symbol, <:Type};
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

feature_scitype_pairs(p::Pair{Symbol,<:Type}, X) = [p, ]
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
                    mixed_pairs::Pair{<:Union{Symbol,<:Type},<:Type}...;
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

Same as [`ScientificTypes.coerce`](@ref) except it does the modification in
place provided `X` supports in-place modification (at the moment, only the
DataFrame! does). An error is thrown otherwise. The arguments are the same as
`coerce`.

"""
coerce!(X, a...;  kw...) = coerce!(Val(ST.trait(X)), X, a...; kw...)

coerce!(::Val{:other}, X, a...; kw...) =
    throw(CoercionError("`coerce!` is undefined for non-tabular data."))

coerce!(::Val{:table}, X, types_dict::AbstractDict; kw...) =
    _bad_dictionary()

coerce!(::Val{:table}, X, specs...; kw...) = _bad_specs()

function coerce!(::Val{:table},
                 X,
                 types_dict::AbstractDict{Symbol, <:Type};
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
function coerce_df!(df, tdict::AbstractDict{Symbol, <:Type}; kw...)
    names = schema(df).names
    for name in names
        name in keys(tdict) || continue
        coerce_type = tdict[name]
        # for DataFrames >= 0.19 df[!, name] = coerce(df[!, name], types(name))
        # but we want something that works more robustly... even for older
        # DataFrames; the only way to do this is to use the
        # `df.name = something` but we cannot use setindex! without throwing
        # a deprecation warning... metaprogramming to the rescue.
        name_str = "$name"
        ex = quote
            $df.$name = coerce($df.$name, $coerce_type, $kw...)
        end
        eval(ex)
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
