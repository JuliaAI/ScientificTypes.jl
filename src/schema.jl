# ## TABLE SCHEMA

struct Schema{names, types, scitypes, nrows} end

Schema(names::Tuple{Vararg{Symbol}},
       types::Type{T},
       scitypes::Type{S},
       nrows::Integer) where {T<:Tuple,S<:Tuple} =
           Schema{names, T, S, nrows}()
Schema(names, types, scitypes, nrows) =
    Schema{Tuple(Base.map(Symbol, names)),
           Tuple{types...}, Tuple{scitypes...}, nrows}()

boogie(t) = Tuple(fieldtype(t, i) for i = 1:fieldcount(t))
boogie_woogie(t) = collect(boogie(t))

function Base.getproperty(sch::Schema{names, types, scitypes, nrows},
                          field::Symbol) where {names, types, scitypes, nrows}

    if field === :names
        return names
    elseif field === :types
        return types === nothing ? nothing : boogie(types)
    elseif field === :scitypes
        return scitypes === nothing ? nothing : boogie(scitypes)
    elseif field === :nrows
        return nrows === nothing ? nothing : nrows
    elseif field === :table
        return (names=collect(names), types=boogie_woogie(types),
                scitypes=boogie_woogie(scitypes))
    else
        throw(ArgumentError("unsupported property for ScientificTypes.Schema"))
    end
end

Base.propertynames(sch::Schema) = (:names, :types, :scitypes, :nrows, :table)

_as_named_tuple(s::Schema) =
    NamedTuple{(:names, :types, :scitypes, :nrows)}((s.names,
                                                     s.types,
                                                     s.scitypes,
                                                     s.nrows))

function Base.show(io::IO, ::MIME"text/plain", s::Schema)
    data = Tables.matrix(s.table)
    header = ["_.names", "_.types", "_.scitypes"]
    println(io, "_.table = ")
    PrettyTables.pretty_table(io, data, header;
                              header_crayon=Crayon(bold=false),
                              alignment=:l)
    println(io, "_.nrows = $(s.nrows)")
end

Base.show(io::IO, s::Schema) = print(io, "Schema{...}()")

info(object, ::Val{:table}) = schema(object)

"""
    schema(X)

Inspect the column types and scitypes of a table.

    julia> X = (ncalls=[1, 2, 4], mean_delay=[2.0, 5.7, 6.0])
    julia> schema(X)
    (names = (:ncalls, :mean_delay),
     types = (Int64, Float64),
     scitypes = (Count, Continuous))

"""
schema(X) = schema(X, Val(trait(X)))
schema(X, ::Val{:other}) =
    throw(ArgumentError("Cannot inspect the internal scitypes of "*
                        "an object with trait `:other`\n"*
                        "Perhaps you meant to import Tables first?"))

## TABLES SPECIFICS

TRAIT_FUNCTION_GIVEN_NAME[:table] = Tables.istable

function scitype(X, ::Val, ::Val{:table})
    Xcol = Tables.columns(X)
    col_names = propertynames(Xcol)
    types = map(col_names) do name
        scitype(getproperty(Xcol, name))
    end
    return Table{Union{types...}}
end

function _nrows(X)
    if !Tables.columnaccess(X)
        return length(collect(X))
    else
        cols = Tables.columntable(X)
        !isempty(cols) || return 0
        return length(cols[1])
    end
end

function schema(X, ::Val{:table})
    s = Tables.schema(X)
    Xcol = Tables.columntable(X)
    names = s.names
    types = Tuple{s.types...}
    scitypes = Tuple{(elscitype(getproperty(Xcol, name))
                              for name in names)...}
    return Schema(names, types, scitypes, _nrows(X))
end
