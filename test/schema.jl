@testset "Schema Object" begin
    ST = ScientificTypes
    sch = ST.Schema((:a, :b), (Count, Count), (Int, Int))
    @test sch isa ST.Schema{(:a, :b), Tuple{Count,Count}, Tuple{Int64,Int64}}
    @test sch.names == (:a, :b)
    @test sch.types == (Int, Int)
    @test sch.scitypes == (Count, Count)

    @test_throws ArgumentError sch.something
    @test propertynames(sch) == (:names, :scitypes, :types)

    # Tables.jl interface
    @test Tables.istable(sch) == true
    @test Tables.columnaccess(sch) == true
    @test Tables.columns(sch) == sch
    @test Tables.columnnames(sch) == (:names, :scitypes, :types)
    @test Tables.schema(sch) == Tables.Schema(Tables.columnnames(sch), Tuple{Symbol, Type, Type})
    @test Tables.getcolumn(sch, 1) == (:a, :b)
    @test Tables.getcolumn(sch, 2) == (Count, Count)
    @test Tables.getcolumn(sch, 3) == (Int, Int)
    @test Tables.getcolumn(sch, :types) == (Int, Int)
    @test Tables.getcolumn(sch, :names) == (:a, :b)

    sch2 = ST.Schema((:a, :b), Tuple{Count, Count}, nothing)
    @test sch2 isa ST.Schema{(:a, :b), Tuple{Count,Count}, nothing}
    @test ST.stored(sch2) == false
    @test Tables.getcolumn(sch2, :types) == [nothing, nothing]
    @test Tables.getcolumn(sch2, 3) == [nothing, nothing]

    sch3 = ST.Schema((:a, :b), (Count, Count), (Int, Int); stored=true)
    @test sch3 isa ST.Schema{nothing, nothing, nothing}
    @test ST.stored(sch3) == true

    # Schema show
    df = DataFrame(x=[1.0,2.0,3.0], y=["a","b","c"])
    s = ScientificTypes.schema(df)
    str = sprint(show, MIME("text/plain"), s)
    @test str == "┌───────┬────────────┬─────────┐\n"*
        "│ names │ scitypes   │ types   │\n"*
        "├───────┼────────────┼─────────┤\n"*
        "│ x     │ Continuous │ Float64 │\n"*
        "│ y     │ Textual    │ String  │\n"*
        "└───────┴────────────┴─────────┘\n"
end

struct MySchemalessTable{U, V}
    x::Vector{U}
    y::Vector{V}
end

Tables.istable(::MySchemalessTable) = true
Tables.columnaccess(::Type{<:MySchemalessTable}) = true
Tables.columns(t::MySchemalessTable) = t
Tables.columnnames(::MySchemalessTable) = (:x, :y)

function Tables.getcolumn(t::MySchemalessTable, i::Int)
    return Tables.getcolumn(t, Tables.columnnames(t)[i])
end

function Tables.getcolumn(t::MySchemalessTable, nm::Symbol)
    return ifelse(nm === :x, t.x, t.y)
end

Tables.schema(t::MySchemalessTable) = nothing

struct ExtremelyWideTable{U, V}
    a::Vector{U}
    b::Vector{V}
end

Tables.istable(::ExtremelyWideTable) = true
Tables.columnaccess(::Type{<:ExtremelyWideTable}) = true
Tables.columns(t::ExtremelyWideTable) = t
Tables.columnnames(::ExtremelyWideTable) = (:a, :b)

function Tables.getcolumn(t::ExtremelyWideTable, i::Int)
    return Tables.getcolumn(t, Tables.columnnames(t)[i])
end

function Tables.getcolumn(t::ExtremelyWideTable, nm::Symbol)
    return ifelse(nm === :a, t.a, t.b)
end
function Tables.schema(t::ExtremelyWideTable{U, V}) where {U, V}
    return Tables.Schema(Tables.columnnames(t), (U, V); stored=true)
end

@testset "schema" begin
    ST = ScientificTypes
    # NamedTuple schema
    X = (
        x = rand(5),
        y = rand(Int, 5),
        z = categorical(collect("asdfa")),
        w = rand(5)
     )
    s = schema(X)
    @test s.scitypes == (Continuous, Count, Multiclass{4}, Continuous)
    @test s.types == (Float64, Int64, CategoricalValue{Char,UInt32}, Float64)

    # Dataframe schema
    df = DataFrame(X = [1,2,3,missing], Y = [1.0,2.0,3.0,missing])
    sch = schema(df)
    @test sch.scitypes[1] == Union{Missing, Count}
    @test sch.scitypes[2] == Union{Missing, Continuous}
    df2 = df[1:3,:]
    sch = schema(df2)
    @test sch.scitypes[1] == Union{Missing, Count}
    @test sch.scitypes[2] == Union{Missing, Continuous}

    # schema of non-tabular objects
    @test_throws ArgumentError schema([:x, :y])

    # PR #61 "schema check for `Tables.DictColumn`"
    X1 = Dict(:a=>rand(5), :b=>rand(Int, 5))
    s1 = schema(X1)
    @test s1.scitypes == (Continuous, Count)
    @test s1.types == (Float64, Int64)

    # issue 47 (schema for objects, `X` with, `Tables.schema(X) == nothing`)
    X2 = MySchemalessTable(rand(3), rand(Int, 3))
    s2 = schema(X2)
    @test s2 === nothing
    @test ST.__cols_schema(
        Tables.columns(X2), Tables.Schema(Tables.columnnames(X2), nothing)
    ) == ST.Schema(Tables.columnnames(X2), Tuple{Continuous, Count}, nothing)

    # For ExtremelyWideTable's
    X3 = ExtremelyWideTable(rand(3), rand(Int, 3))
    s3 = schema(X3)
    @test s3.names == Tables.columnnames(X3)
    @test s3.scitypes == (Continuous, Count)
    @test s3.types == (Float64, Int)
    @test ST._cols_schema(
        Tables.columns(X3), Tables.schema(X3)
    ) == ST.Schema(Tables.columnnames(X3), (Continuous, Count), (Float64, Int))
    @test ST._rows_schema(
        Tables.rows(X3), Tables.schema(X3)
    ) == ST.Schema(Tables.columnnames(X3), (Continuous, Count), (Float64, Int))

    # test schema for column oreinted tables with number of columns
    # exceeding COLS_SPECIALIZATION_THRESHOLD.
    nt = NamedTuple{
            Tuple(Symbol("x$i") for i in Base.OneTo(ST.COLS_SPECIALIZATION_THRESHOLD + 1))
        }(
            Tuple(rand(2) for i in Base.OneTo(ST.COLS_SPECIALIZATION_THRESHOLD + 1))
    )
    @test ST.__cols_schema(
        Tables.columns(nt), Tables.Schema(Tables.columnnames(nt), nothing)
    ) == ST.Schema(
        Tables.columnnames(nt),
        NTuple{ST.COLS_SPECIALIZATION_THRESHOLD + 1, Continuous},
        nothing
    )

    @test ST.__cols_schema(
        Tables.columns(nt), Tables.schema(nt)
    ) == ST.Schema(
        Tables.columnnames(nt),
        NTuple{ST.COLS_SPECIALIZATION_THRESHOLD + 1, Continuous},
        NTuple{ST.COLS_SPECIALIZATION_THRESHOLD + 1, Float64}
    )

 end
