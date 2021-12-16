# -----------------------------------------------------------------------------------------
# This file includes the single argument definition of `scitype` method and corresponding 
# convenience functions. It also includes definitions for `scitype/Scitype` of different 
# objects with respect to the `DefaultConvention``.
# -----------------------------------------------------------------------------------------
"""
The scientific type (interpretation) of `X`, as distinct from its
machine type, as specified by the active convention.
### Examples
```
julia> scitype(3.14)
Continuous
julia> scitype([1, 2, 3, missing])
AbstractArray{Union{Missing, Count},1}
julia> scitype((5, "beige"))
Tuple{Count, Textual}
julia> using CategoricalArrays
julia> X = (gender = categorical(['M', 'M', 'F', 'M', 'F']),
            ndevices = [1, 3, 2, 3, 2])
julia> scitype(X)
Table{Union{AbstractArray{Count,1}, AbstractArray{Multiclass{2},1}}}
```
"""
scitype(X) = ST.scitype(X, CONV)

function ST.scitype(@nospecialize(X), C::DefaultConvention)
    return _scitype(X, C, vtrait(X)) 
end

function _scitype(X, C, ::Val{:other})
    return ST.fallback_scitype(X, C)
end

# -----------------------------------------------------------------------------------------
# Basic (scalar) scitypes
ST.scitype(::Integer, ::DefaultConvention) = Count
ST.scitype(::AbstractFloat, ::DefaultConvention) = Continuous
ST.scitype(::AbstractString, ::DefaultConvention) = Textual
ST.scitype(::TimeType, ::DefaultConvention) = ScientificTimeType
ST.scitype(::Time, ::DefaultConvention) = ScientificTime
ST.scitype(::Date, ::DefaultConvention) = ScientificDate
ST.scitype(::DateTime, ::DefaultConvention) = ScientificDateTime

# -----------------------------------------------------------------------------------------
# Image scitypes
ST.scitype(img::Arr{<:Gray,2}, ::DefaultConvention) = GrayImage{size(img)...}
ST.scitype(img::Arr{<:AbstractRGB,2}, ::DefaultConvention) =
ColorImage{size(img)...}

# -----------------------------------------------------------------------------------------
# CategoricalArray scitype
function ST.scitype(c::Cat, ::DefaultConvention)
    nc = length(levels(c.pool))
    return ifelse(c.pool.ordered, OrderedFactor{nc}, Multiclass{nc})
end

const CatArrOrSub{T, N} =
    Union{CategoricalArray{T, N}, SubArray{T, N, <:CategoricalArray}}

function ST.scitype(A::CatArrOrSub{T, N}, ::DefaultConvention) where {T, N}
    nlevels = length(levels(A))
    S = ifelse(isordered(A), OrderedFactor{nlevels}, Multiclass{nlevels})
    T >: Missing && (S = Union{S, Missing})
    return AbstractArray{S, N}
end

# -----------------------------------------------------------------------------------------
## Table scitypes

function _scitype(X, C, ::Val{:table})
    if Tables.columnaccess(X)
        return cols_scitype(X)
    else
        return rows_scitype(X)
    end
end

function cols_scitype(X)
    cols = Tables.columns(X)
    sch = Tables.schema(cols)
    return _cols_scitype(cols, sch)
end

function _cols_scitype(cols, ::Union{Nothing, Tables.Schema{nothing, nothing}})
    col_names = Tables.columnnames(cols)
    scitypes = map(col_names) do name
        scitype(Tables.getcolumn(cols, name))
    end
    return Table{Union{scitypes...}}
end

function _cols_scitype(cols, sch::Tables.Schema{names, types}) where {names, types}
    N = length(names)
    if N <= COLS_SPECIALIZATION_THRESHOLD
        return __cols_scitype(cols, sch) 
    else
        scitypes = if types === nothing
            Type[scitype(Tables.getcolumn(cols, name[i])) for i in Base.OneTo(N)]
        else
            Type[
                scitype(
                    Tables.getcolumn(
                    cols, fieldtype(types, i), i, name[i])
                ) for i in Base.OneTo(N)
            ]
            
        end
        return Table{Union{scitypes...}}
    end
end

@inline function __cols_scitype(
    cols, 
    sch::Tables.Schema{names, types}
) where {names, types}
    N = length(names)
    if @generated
        stypes = if types === nothing
            (
                :(scitype(Tables.getcolumn(cols, $(Meta.QuoteNode(names[i]))))) 
                for i in Base.OneTo(N)
            )
        else
            (
                quote
                    scitype(
                        Tables.getcolumn(
                            cols, $(fieldtype(types, i)), $i,  $(Meta.QuoteNode(names[i]))
                        );
                    )
                end 
                for i in Base.OneTo(N)
            )
        end
        return :(Table{Union{$(stypes...)}})
    else
        stypes = if types === nothing 
            (scitype(Tables.getcolumn(cols, names[i])) for i in Base.OneTo(N))
        else
            (
                scitype(Tables.getcolumn(cols, fieldtype(types, i), i, names[i])) 
                for i in Base.OneTo(N)
            )
        end
        return Table{Union{stypes...}}
    end
end

function rows_scitype(X)
    rows = Tables.rows(X)
    sch = Tables.schema(rows)
    return _rows_scitype(rows, sch)
end

function _rows_scitype(rows, sch::Tables.Schema{names, types}) where {names, types}
    rows_ = RowsWrapper(rows)
    cols = if length(names) <= ROWS_SPECIALIZATION_THRESHOLD
        Tables.columns(rows_)
    else
        Tables.dictcolumntable(rows_)
    end
    return _cols_scitype(cols, sch)
end

function _rows_scitype(rows, sch::Union{Nothing, Tables.Schema{nothing, nothing}})
    cols = Tables.dictcolumntable(RowsWrapper(rows))
    return _cols_scitype(cols, sch)
end

# -----------------------------------------------------------------------------------------
# Distributions scitype

const Dist = Distributions

scalar_scitype(::Type) = Unknown
scalar_scitype(::Type{<:Dist.Discrete}) = Count
scalar_scitype(::Type{<:Dist.Continuous}) = Continuous

function space_scitype(
    variate_form::Type{<:Dist.ArrayLikeVariate{0}},
    value_support
)
    return scalar_scitype(value_support)
end

function space_scitype(
    variate_form::Type{<:Dist.ArrayLikeVariate{N}},
    value_support
) where N
    return AbstractArray{scalar_scitype(value_support), N}
end

function ST.scitype(::Distributions.Sampleable{F, S}) where {F, S}
    return Sampleable{space_scitype(F, S)}
end

function ST.scitype(::Distributions.Distribution{F,S}) where {F, S}
    return Density{space_scitype(F, S)}
end

# -----------------------------------------------------------------------------------------
# `Scitype` definitions for fast array broadcasting

ST.Scitype(::Type{<:Integer}, ::DefaultConvention) = Count
ST.Scitype(::Type{<:AbstractFloat}, ::DefaultConvention) = Continuous
ST.Scitype(::Type{<:AbstractString}, ::DefaultConvention) = Textual
ST.Scitype(::Type{<:TimeType}, ::DefaultConvention) = ScientificTimeType
ST.Scitype(::Type{<:Date}, ::DefaultConvention) = ScientificDate
ST.Scitype(::Type{<:Time}, ::DefaultConvention) = ScientificTime
ST.Scitype(::Type{<:DateTime}, ::DefaultConvention) = ScientificDateTime
# ST.Scitype(::Type{<:PersistenceDiagram}, ::DefaultConvention) = PersistenceDiagram

# -----------------------------------------------------------------------------------------
## convenience methods
"""
    elscitype(A)
Return the element scientific type of an abstract array `A`. By definition, if
`scitype(A) = AbstractArray{S,N}`, then `elscitype(A) = S`.
"""
elscitype(X) = elscitype(collect(X))
elscitype(X::Arr) = eltype(scitype(X))
 
"""
    scitype_union(A)
Return the type union, over all elements `x` generated by the iterable `A`,
of `scitype(x)`. See also [`scitype`](@ref).
"""
scitype_union(X) = ST.scitype_union(X, DefaultConvention())