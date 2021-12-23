@testset "Explicit Scitype tests" begin
    STB = ScientificTypesBase
    ST = ScientificTypes
    @test STB.Scitype(Int, ST.CONV) == Count
    @test STB.Scitype(Float64, ST.CONV) == Continuous
    @test STB.Scitype(Float32, ST.CONV) == Continuous
    @test STB.Scitype(Float16, ST.CONV) == Continuous
    @test STB.Scitype(SubString, ST.CONV) == Textual
end

@testset "scitype of (In)Finite elements" begin
    cv = categorical(['x', 'y'])
    c  = cv[1]
    uv = categorical(['x', 'y'], ordered=true)
    u  = uv[1]
    @test scitype((4, 4.5, c, u, "X")) == Tuple{
                       Count,Continuous,Multiclass{2},OrderedFactor{2},Textual}
end

@testset "elscitype" begin
    X = randn(5, 5)
    @test scitype(X) == Arr{Continuous, 2}
    @test elscitype(X) == Continuous
    X = [1, 2, missing, 5]
    @test elscitype(X) == Union{Missing, Count}
    @test elscitype(X[1:2]) == Union{Missing, Count}
    X = categorical([1, 2, 3, missing, 2, 1, missing])
    @test elscitype(X) == Union{Missing,Multiclass{3}}
    X = categorical("lksfjalksjdflkjsdlkfjasldkfj" |> collect)
    @test elscitype(X) <: Multiclass
    X = coerce(categorical([1,2,3,1,2,3]), OrderedFactor)
    @test elscitype(X) <: Union{Missing, OrderedFactor}
end

A = Any[2 4.5;
        4 4.5;
        6 4.5]

@testset "scitype_union" begin
    @test scitype_union(A) == Union{Count,Continuous}
    @test scitype_union(randn(1000000)) == Continuous
    @test scitype_union(1) == Count
    @test scitype_union([1]) == Count
    @test scitype_union(Any[1]) == Count
    @test scitype_union([1, 2.0, "3"]) == Union{Continuous, Count, Textual}
end

@testset "scitype of Arrays" begin
    # COUNT
    @test scitype(A)               == Arr{Union{Count,Continuous}, 2}
    @test scitype([1, 2, 3])       == Vec{Count}
    @test scitype([1, missing, 3]) == Vec{Union{Missing,Count}}
    @test scitype(Any[1, 2, 3])    == Vec{Count}
    @test scitype(Any[1, missing]) == Vec{Union{Missing,Count}}

    # CONTINUOUS
    @test scitype([1.0, 2.0, 3.0])    == Vec{Continuous}
    @test scitype(Any[1.0, missing])  == Vec{Union{Missing,Continuous}}
    @test scitype(Any[1.0, 2.0, 3.0]) == Vec{Continuous}
    @test scitype(Any[1.0, missing])  == Vec{Union{Missing,Continuous}}

    # MULTICLASS
    @test scitype(categorical(1:4))         == Vec{Multiclass{4}}
    @test scitype(view(categorical(1:4), 1:3)) == Vec{Multiclass{4}}
    @test scitype(Any[categorical(1:4)...]) == Vec{Multiclass{4}}
    @test scitype(categorical([1, missing, 3])) ==
        Vec{Union{Multiclass{2},Missing}}
    
        a = ["aa", "bb", "aa", "bb"] |> categorical
    @test scitype(a[1]) == Multiclass{2}
 
    # NOTE: the slice here does not contain missings but the machine type
    # still contains a missing so the scitype remains with a missing
    @test scitype(categorical([1, missing, 3])[1:1]) ==
        Vec{Union{Multiclass{2},Missing}}

    # ORDEREDFACTOR
    @test scitype(categorical(1:4, ordered=true)) ==
        Vec{OrderedFactor{4}}
    @test scitype(Any[categorical(1:4, ordered=true)...]) ==
        Vec{OrderedFactor{4}}
    @test scitype(categorical([1, missing, 3], ordered=true)) ==
        Vec{Union{OrderedFactor{2},Missing}}
    # NOTE: see note for multiclass
    @test scitype(categorical([1, missing, 3], ordered=true)[1:1]) ==
        Vec{Union{OrderedFactor{2},Missing}}
end

@testset "scitype of Images" begin
    black = RGB(0, 0, 0)
    color_image = fill(black, (10, 20))
    @test scitype(color_image) == ColorImage{10,20}

    color_image2 = fill(black, (5, 3))
    v = [color_image, color_image2, color_image2]
    @test scitype(v) ==
        Vec{Union{ColorImage{10,20},ColorImage{5,3}}}

    white = Gray(1.0)
    gray_image = fill(white, (10, 20))
    @test scitype(gray_image) == GrayImage{10,20}
end

# @testset "PersistenceDiagrams" begin
#     diagram = PersistenceDiagram([(1, Inf), (2, 3)], dim=0)
#     @test scitype(diagram) == PersistenceDiagram

#     diagrams = [diagram, diagram, diagram]
#     @test scitype(diagrams) == Vec{PersistenceDiagram}
# end

@testset "scitype for objects with temporal types" begin
    d = Date(2020, 4, 21)
    t = Time(8, 15, 42)
    dt = now()
    @test scitype(d) == ScientificDate
    @test scitype(t) == ScientificTime
    @test scitype(dt) == ScientificDateTime
    @test scitype(vcat([missing, ], fill(d, 3))) ==
        AbstractVector{Union{Missing,ScientificDate}}
    @test scitype(vcat([missing, ], fill(t, 3))) ==
        AbstractVector{Union{Missing,ScientificTime}}
    @test scitype(vcat([missing, ], fill(dt, 3))) ==
        AbstractVector{Union{Missing,ScientificDateTime}}
    @test scitype([missing, d, t]) ==
        AbstractVector{Union{Missing,ScientificTimeType}}
end

struct FooSampleable <: Dist.Sampleable{Dist.ArrayLikeVariate{0},
    Dist.Discrete}
end

@testset "scitypes of distributions" begin
    @test scitype(Dist.Normal()) == Density{Continuous}
    @test scitype(Dist.Poisson()) == Density{Count}
    @test scitype(Dist.Categorical(3)) == Density{Count}
    X = [1 2; 3 4]
    @test scitype(Dist.MultivariateNormal(X'X)) ==
    Density{AbstractVector{Continuous}}
    @test scitype(FooSampleable()) == Sampleable{Count}
end

@testset "Tables scitype" begin
    ST = ScientificTypes
    ## Test scitype for Column oriented tables
    X = (
        x = rand(5),
        y = rand(Int, 5),
        z = categorical(collect("asdfa")),
        w = rand(5)
    )
    t = scitype(X)
    @test t <: Table(Continuous, Finite, Count)
    @test t <: Table(Infinite, Multiclass)
    @test !(t <: Table(Continuous, Union{Missing, Count}))
    @test ST._cols_scitype(
        Tables.columns(X), Tables.Schema(Tables.columnnames(X), nothing)
    ) == t

    ## scitype tests for row oriented tables.
    Y = Tables.rowtable(X)
    r = scitype(Y)
    @test r <: Table(Continuous, Finite, Count)
    @test r <: Table(Infinite, Multiclass)
    @test !(r <: Table(Continuous, Union{Missing, Count}))
    rows = Tables.rows(Y)
    @test ST._rows_scitype(
        rows, Tables.Schema(Tables.columnnames(iterate(rows, 1)[1]), nothing)
    ) == r
    # ExtremelyWide row oriented table
    @test ST._rows_scitype(
        rows, 
        Tables.Schema(
            Tables.columnnames(iterate(rows, 1)[1]),
            (Int, Int, CategoricalValue{Char, UInt32}, Float64);
            stored = true
        )
    ) == r

    # test schema for column oreinted tables with number of columns 
    # exceeding COLS_SPECIALIZATION_THRESHOLD.
    nt = NamedTuple{
            Tuple(Symbol("x$i") for i in Base.OneTo(ST.COLS_SPECIALIZATION_THRESHOLD + 1))
        }(
            Tuple(rand(2) for i in Base.OneTo(ST.COLS_SPECIALIZATION_THRESHOLD + 1))
    )
    @test scitype(nt) <: Table(Continuous)

    #issue 146
    X = Tables.table(coerce(rand("abc", 5, 3), Multiclass))
    @test scitype(X) === Table{AbstractVector{Multiclass{3}}}
end

# TODO: re-instate when julia 1.0 is no longer LTS release:

# @testset "csvfile" begin
#     X = (x = rand(4), )
#     CSV.write("test.csv", X)
#     file = CSV.File("test.csv")
#     @test scitype(file) == scitype(X)
#     rm("test.csv")
# end