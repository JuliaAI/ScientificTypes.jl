#=
Functionalities supporting the schema of `X` when `X` is a `Tables.jl`
compatible table.
=#
struct Schema{names, types, scitypes, nrows}
    storednames::Union{Nothing, Vector{Symbol}}
    storedtypes::Union{Nothing, Vector{Type}}
    storedscitypes::Union{Nothing, Vector{Type}}
end

"""
    Schema(names, types, scitypes, nrows)

Constructor for a `Schema` object.
"""
function Schema(names::Tuple{Vararg{Symbol}}, types::Type{T},
                scitypes::Type{S}, nrows::Integer) where {T<:Tuple, S<:Tuple}
    return Schema{names, T, S, nrows}()
end

function Schema{names, types, scitypes, nrows}() where {names, types, scitypes, nrows}
    return Schema{names, types, scitypes, nrows}(nothing, nothing, nothing)
end

# whether names/types are stored or not
function stored(::Schema{names, types, scitypes, nrows}) where {names, types, scitypes, nrows}
    return (names === nothing && types === nothing && scitypes === nothing)
end

stored(::Nothing) = false

tuple_of_symbols(x::NTuple{N, Symbol}) where {N} = x
tuple_of_symbols(x) = Tuple(map(Symbol, x))
 
function Schema(names, types, scitypes, nrows::Integer; stored::Bool=false)
    if stored || length(names) > SCHEMA_SPECIALIZATION_THRESHOLD
        return Schema{nothing, nothing, nothing, nrows}(
            [Symbol(x) for x in names],
            Type[T for T in types],
            Type[T for T in scitypes]
        )
    else 
        return Schema{tuple_of_symbols(names), Tuple{types...}, Tuple{scitypes...}, nrows}()
    end
end

if VERSION < v"1.1"
    fieldtypes(t) = Tuple(fieldtype(t, i) for i = 1:fieldcount(t))
end

function Base.getproperty(sch::Schema{names, types, scitypes, nrows},
                          field::Symbol) where {names, types, scitypes, nrows}
    if field === :names
        return names === nothing ? getfield(sch, :storednames) : names
    elseif field === :types
        return types === nothing ? 
            (T = getfield(sch, :storedtypes); T !== nothing ? T : nothing) : fieldtypes(types)
    elseif field === :scitypes
        return scitypes === nothing ? 
            (S = getfield(sch, :storedscitypes); S !== nothing ? S : nothing) : fieldtypes(scitypes)
    elseif field === :nrows
        return nrows
    else
        throw(ArgumentError("unsupported property for ScientificTypes.Schema"))
    end
end

Base.propertynames(sch::Schema) = (:names, :types, :scitypes, :nrows)

"""
    schema(X)

Inspect the column types and scitypes of a tabular object.
returns `nothing` if the column types and scitypes can't be inspected.

## Example

```
X = (ncalls=[1, 2, 4], mean_delay=[2.0, 5.7, 6.0])
schema(X)
```
"""
schema(X; kw...) = schema(X, Val(trait(X)); kw...)

# Fallback
schema(X, ::Val{:other}; kw...) =
    throw(ArgumentError("Cannot inspect the internal scitypes of "*
                        "a non-tabular object. "))

#=
function schema(X, ::Val{:table}; kw...)
    cols = Tables.columns(X)
    sch = Tables.schema(cols)
    sch === nothing && return nothing
    names = sch.names
    types = sch.types
    stypes = [elscitype(Tables.getcolumn(cols, n); kw...) for n in names]
    return Schema(names, types, stypes, _nrows(cols))
end

function _nrows(cols)
    names = Tables.columnnames(cols)
    return isempty(names) ? 0 : length(Tables.getcolumn(cols, names[1]))
end
=#

function schema(X, ::Val{:table}; kw...)
    if Tables.columnaccess(X)
        return cols_schema(X; kw...)
    else
        return rows_schema(X; kw...)
    end
end

function _nrows(cols, names, types, ::Val{true})
    return isempty(names) ? 0 : length(Tables.getcolumn(cols, types[1], 1, names[1]))
end

function _nrows(rows, @nospecialize(names), @nospecialize(types), ::Val{false})
    return _nrows_rat(Base.IteratorSize(typeof(rows)), rows)
end

_nrows_rat(::Base.HasShape, rows) = size(rows, 1)
_nrows_rat(::Base.HasLength, rows) = length(rows)
_nrows_rat(@nospecialize(iter_size), rows) = length(collect(rows))

function cols_schema(X; kw...)
    cols = Tables.columns(X)
    sch = Tables.schema(cols)
    sch === nothing && return nothing
    names = sch.names
    types = sch.types
    len = length(names)
    stypes = Vector{Type}(undef, len)

    for ind  in eachindex(names)
        @inbounds type = types[ind]
        @inbounds name = names[ind]
        S = ST.Scitype(type, ST.convention())
        @inbounds stypes[ind] = elscitype(
            Tables.getcolumn(cols, type, ind,  name);
            kw...
        )
    end
   
    return Schema(names, types, stypes, _nrows(cols, names, types, Val{true}()))
end

function rows_schema(X; kw...)
    rows = Tables.rows(X)
    sch = Tables.schema(rows)
    sch === nothing && return nothing
    names = sch.names 
    types = sch.types
    len = length(names)
    cat_names = Vector{Symbol}(undef, len)
    #cat_types = Vector{Type}(undef, len)
    stypes = Vector{Type}(undef, len)
    indexes = Vector{Int}(undef, len)

    j = 1
    for ind  in eachindex(names)
        @inbounds type = types[ind]
        @inbounds name = names[ind]
        S = ST.Scitype(type, ST.convention())
        val = _elscitype(
            rows, name, type, ind, S;
            kw...
        )
        @inbounds stypes[ind] =  val
        #@inbounds cat_types[j] = type
        @inbounds cat_names[j] = name
        @inbounds indexes[j] = ind
        j = ifelse(Unknown <: val && type <: Union{Missing, Cat}, j+1, j) 
    end
    resize!(cat_names, j-1)
    #resize!(cat_types, j-1)
    resize!(indexes, j-1)
    #@show cat_names
   # @show cat_types
    if !isempty(cat_names)
        #cat_sch = Tables.Schema(cat_names, cat_types)
        #@show cat_sch
        #println("cat_sch = ", cat_sch)
        #nt = Tables.buildcolumns(cat_sch, rows)
        cat_table = TableOperations.select(X, cat_names...)
        nt = Tables.columntable(cat_table)
        for ind in eachindex(cat_names)
            ind_ = @inbounds indexes[ind]
            name = @inbounds cat_names[ind]
            #stypes[ind_] = elscitype(nt[name]; kw...)
            stypes[ind_] = elscitype(nt[name]; kw...)
        end
    end 

    return Schema(names, types, stypes, _nrows(rows, names, types, Val{false}()))
end

#=
@inline function _tighten_type_if_needed(
    iter, ::Type{iter_type}, ::Type{iter_scitype};
    tight::Val=Val{false}()
) where {iter_type, iter_scitype}
    if iter_type >: Missing
        if tight === Val{true}()
            has_missings = 
                findfirst(ismissing, iter) !== nothing
            !has_missings && return nonmissing(iter_scitype)
        end
        return Union{iter_scitype, Missing}
    end
    return iter_scitype
end
=#
@inline function _tighten_type_if_needed(
    iter, ::Type{iter_type}, ::Type{iter_scitype};
    tight::Bool = false,
    union::Bool = false
) where {iter_type, iter_scitype}
    if Unknown <: iter_scitype && union 
        return scitype_union(iter) #union automatically tightens type
    elseif iter_type >: Missing
        if tight
            has_missings = 
                findfirst(ismissing, iter) !== nothing
            !has_missings && return nonmissing(iter_scitype)
        end
        return Union{iter_scitype, Missing}
    else
        return iter_scitype
    end
end

@inline function _elscitype(
    rows, name, ::Type{T}, ind, ::Type{S};
    tight::Bool=false,
    union::Bool=false
) where {T, S}
    col = (Tables.getcolumn(row, T, ind, name) for row in rows)
    return _tighten_type_if_needed(col, T, S; tight = tight, union=union)
end

#=
function _elscitype(rows, name, ::Type{T}, ind, ::Type{S}; kw...) where {T, S}
    isunknown = Unknown <: S
    col = (Tables.getcolumn(row, T, ind, name) for row in rows)
    kwargs = values(kw)
    union = haskey(kwargs, :tight) ? Val{kwargs[:union]}() : Val{false}()
    tight = haskey(kwargs, :tight) ? Val{kwargs[:tight]}() : Val{false}()
    if (isunknown)
        #if T <: Union{Missing, Cat}
        #    return elscitype(CategoricalArrays.categorical([1,2,3]); kw...)
            #return elscitype(collect(T, col); kw...)
        if (union === Val{true}())
            return scitype_union(col)
        end
    end
    return _tighten_type_if_needed(col, T, S; tight = tight)
    
    #= 
    elseif T >: Missing
        kwargs = values(kw)
        if haskey(kwargs, :tight) && kwargs[:tight]
            has_missings = 
                findfirst(ismissing, (Tables.getcolumn(row, T, ind, name) for row in rows)) !== nothing
            !has_missings && return nonmissing(S)
        end
        return Union{S, Missing}
    end
    return S
    =#
end

=#
function Base.show(io::IO, ::MIME"text/plain", s::Schema)
    data = Tables.matrix((
                names=collect(s.names),
                types=collect(s.types),
                scitypes=collect(s.scitypes)
                ))
    header = (["_.names", "_.types", "_.scitypes"],)
    pretty_table(io, data, header=header;
                 header_crayon=Crayon(bold=false),
                 alignment=:l)
    println(io, "_.nrows = $(s.nrows)")
end

# overload StatisticalTraits function:
info(X, ::Val{:table}) = schema(X)
