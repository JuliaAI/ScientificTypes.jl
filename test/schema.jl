@testset "Schema" begin
    sch = S.Schema((:a, :b), (Int, Int), (Count, Count), 5)
    @test sch.names == (:a, :b)
    @test sch.types == (Int, Int)
    @test sch.scitypes == (Count, Count)
    @test sch.nrows == 5

    @test_throws ArgumentError sch.something
    @test propertynames(sch) == (:names, :types, :scitypes, :nrows)
    snt = S._as_named_tuple(sch)
    @test snt isa NamedTuple
    @test snt.names == sch.names

    X = [1,2,3]
    @test_throws ArgumentError schema(X)

    io = IOBuffer()
    show(io, sch)
    sh = String(take!(io))
    @test sh == "Schema{...}()"
end
