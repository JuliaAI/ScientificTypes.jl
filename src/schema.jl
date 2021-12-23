#=
Functionalities supporting the schema of `X` when `X` is a `Tables.jl`
compatible table.
=#
struct Schema{names, scitypes, types}
    storednames::Union{Nothing, Vector{Symbol}}
    storedscitypes::Union{Nothing, Vector{Type}}
    storedtypes::Union{Nothing, Vector{Type}}
end

"""
    Schema(names, scitypes, types)

Constructor for a `Schema` object.
"""
function Schema(
    names::Tuple{Vararg{Symbol}},
    scitypes::Type{S},
    types::Type{T},
) where {T<:Tuple, S<:Tuple}
    return Schema{names, S, T}()
end

function Schema{names, scitypes, types}() where {names, scitypes, types}
    return Schema{names, scitypes, types}(nothing, nothing, nothing)
end

function Schema(
    names::Tuple{Vararg{Symbol}},
    scitypes::Type{S},
    ::Nothing
) where {S<:Tuple}
    return Schema{names, S, nothing}(nothing, nothing, nothing)
end

# whether names/types are stored or not
function stored(::Schema{names, scitypes, types}) where {names, scitypes, types}
    return (names === nothing && scitypes === nothing && types === nothing)
end

stored(::Nothing) = false
tuple_of_symbols(x::NTuple{N, Symbol}) where {N} = x
tuple_of_symbols(x) = Tuple(map(Symbol, x))
 
@inline function Schema(names, scitypes, types; stored::Bool=false)
    if stored || length(names) > SCHEMA_SPECIALIZATION_THRESHOLD
        return Schema{nothing, nothing, nothing}(
            [Symbol(x) for x in names],
            Type[T for T in scitypes],
            Type[T for T in types]
        )
    else 
        return Schema{tuple_of_symbols(names), Tuple{scitypes...}, Tuple{types...}}()
    end
end

if VERSION < v"1.1"
    fieldtypes(t) = Tuple(fieldtype(t, i) for i = 1:fieldcount(t))
end

# Note that `getproperty(::Schema, :name)`, `getproperty(::Schema, :scitypes)`
# and `getproperty(::Schema, :types)` cannot return `nothing` even though the 
# definition below allows for this case. This is because the nature of the `schema`
# function defined below.   
function Base.getproperty(sch::Schema{names, scitypes, types},
                          field::Symbol) where {names, scitypes, types}
    if field === :names
        return names === nothing ? getfield(sch, :storednames) : names
    elseif field === :scitypes
        return scitypes === nothing ? 
            (S = getfield(sch, :storedscitypes); S !== nothing ? S : nothing) : fieldtypes(scitypes)
    elseif field === :types
        return types === nothing ? 
            (T = getfield(sch, :storedtypes); T !== nothing ? T : nothing) : fieldtypes(types)
    else
        throw(ArgumentError("unsupported property for ScientificTypes.Schema"))
    end
end

Base.propertynames(sch::Schema) = (:names, :scitypes, :types)

# make `Schema` a Tables.jl compatible object.
Tables.istable(::Type{<:Schema}) = true
Tables.columnaccess(::Schema) = true
Tables.columns(s::Schema) = s
Tables.columnnames(sch::Schema) = propertynames(sch)
Tables.schema(sch::Schema) = Tables.Schema(Tables.columnnames(sch), Tuple{Symbol, Type, Type})
Tables.getcolumn(sch::Schema, i::Int) = Tables.getcolumn(sch, Tables.columnnames(sch)[i])

function Tables.getcolumn(sch::Schema, nm::Symbol)
    col = getproperty(sch, nm)
    if col === nothing
        N = length(getproperty(sch, :names))
        return fill(nothing, N)
    end
    return col
end

"""
    schema(X)

Inspect the column types and scitypes of a tabular object.
returns `nothing` if the column types and/or scitypes can't be inspected.

## Example

```
X = (ncalls=[1, 2, 4], mean_delay=[2.0, 5.7, 6.0])
schema(X)
```
"""
schema(X) = schema(X, vtrait(X))

# Fallback
function schema(X, ::Val{:other})
    throw(
        ArgumentError("Cannot inspect the internal scitypes of a non-tabular object. ")
    )
end

function schema(X, ::Val{:table})
    if Tables.columnaccess(X)
        return cols_schema(X)
    else
        return rows_schema(X)
    end
end

function cols_schema(X)
    cols = Tables.columns(X)
    sch = Tables.schema(cols)
    sch === nothing && return nothing
    return _cols_schema(cols, sch)
end

function _cols_schema(cols, sch::Tables.Schema{names, types}) where {names, types}
    N = length(names)
    if N <= COLS_SPECIALIZATION_THRESHOLD
        return __cols_schema(cols, sch)
    else
        stypes = if types === nothing
            Type[
                elscitype(Tables.getcolumn(cols, names[i])) 
                for i in Base.OneTo(N)
            ]
        else
            Type[
                elscitype(Tables.getcolumn(cols, fieldtype(types, i), i, names[i])) 
                for i in Base.OneTo(N)
            ]
        end
        return Schema(names, Tuple{stypes...}, types)
    end
end

@inline function __cols_schema(cols, sch::Tables.Schema{names, types}) where {names, types}
    N = length(names)
    if @generated
        stypes = if types === nothing
            (
                :(elscitype(Tables.getcolumn(cols, $(Meta.QuoteNode(names[i]))))) 
                for i in Base.OneTo(N)
            )
        else
            (
                quote
                    elscitype(
                        Tables.getcolumn(
                            cols, $(fieldtype(types, i)), $i,  $(Meta.QuoteNode(names[i]))
                        )
                    )
                end 
                for i in Base.OneTo(N)
            )
        end
        
        return :(Schema(names, Tuple{$(stypes...)}, types))
        
    else
        
        stypes = if types === nothing 
            (
                elscitype(Tables.getcolumn(cols, names[i])) 
                for i in Base.OneTo(N)
            )
        else
            (
                elscitype(Tables.getcolumn(cols, fieldtype(types, i), i, names[i])) 
                for i in Base.OneTo(N)
            )
        end

        return Schema(names, Tuple{stypes...}, types)
        
    end

end

# For extremely wide column oriented tables.
@inline function _cols_schema(cols, sch::Tables.Schema{nothing, nothing})
    names = sch.names
    types = sch.types
    len = length(names)
    stypes = Vector{Type}(undef, len)
    @simd for ind in eachindex(names)
        name = @inbounds(names[ind])
        @inbounds(
            stypes[ind] = elscitype(Tables.getcolumn(cols, name))
        )
    end
    return Schema(names, stypes, types)
end

struct RowsWrapper{T}
    rows::T
end

Tables.istable(::Type{<:RowsWrapper}) = true
Tables.rowaccess(::RowsWrapper) = true
Tables.rows(x::RowsWrapper) = x.rows
Tables.columns(x::RowsWrapper) = Tables.columns(x.rows)

function rows_schema(X)
    rows = Tables.rows(X)
    sch = Tables.schema(rows)
    sch === nothing && return nothing
    return _rows_schema(rows, sch)
end

function _rows_schema(rows, sch::Tables.Schema{names, types}) where {names, types}
    rows_ = RowsWrapper(rows)
    cols = if length(names) <= ROWS_SPECIALIZATION_THRESHOLD
            Tables.columns(rows_)
    else
        Tables.dictcolumntable(rows_)
    end
    return _cols_schema(cols, sch)
end

# for extremely wide row oriented tables
function _rows_schema(rows, sch::Tables.Schema{nothing, nothing})
    cols = Tables.dictcolumntable(RowsWrapper(rows))
    return _cols_schema(cols, sch)
end

function Base.show(io::IO, ::MIME"text/plain", s::Schema)
    data = Tables.matrix(s)
    header = (["names", "scitypes", "types"],)
    pretty_table(io, data, header=header;
                 header_crayon=Crayon(bold=false),
                 alignment=:l)
end

