@testset "Schema" begin
    sch = S.Schema((:a, :b), (Int, Int), (Count, Count), 5)
    @test sch.names == (:a, :b)
    @test sch.types == (Int, Int)
    @test sch.scitypes == (Count, Count)
    @test sch.nrows == 5

    @test_throws ArgumentError sch.something
    @test propertynames(sch) == (:names, :types, :scitypes, :nrows, :table)
    snt = S._as_named_tuple(sch)
    @test snt isa NamedTuple
    @test snt.names == sch.names
end

@testset "Tables" begin
    X = (
        x = rand(5),
        y = rand(Int, 5),
        z = categorical(collect("asdfa")),
        w = rand(5)
    )
    s = schema(X)
    @test info(X) == schema(X)
    @test s.scitypes == (Continuous, Count, Multiclass{4}, Continuous)
    @test s.types == (Float64, Int64, CategoricalValue{Char,UInt32}, Float64)
    @test s.nrows == 5

    @test_throws ArgumentError schema([:x, :y])

    t = scitype(X)
    @test t <: ScientificTypes.Table(Continuous, Finite, Count)
    @test t <: ScientificTypes.Table(Infinite, Multiclass)
    @test !(t <: ScientificTypes.Table(Continuous, Union{Missing, Count}))

    @test S._nrows(X) == 5
    @test S._nrows(()) == 0
    @test S._nrows((i for i in 1:7)) == 7
end

@testset "scitype of a table that is also an array" begin
    X = (x=rand(4),)
    f = mkpath()
    CSV.write(f, X)
    file = CSV.file(f)
    @test scitype(file) == scitype(X)
end
