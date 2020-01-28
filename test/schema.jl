@testset "Schema" begin
    sch = S.Schema((:a, :b), (Int, Int), (Count, Count), 5)
    @test sch isa S.Schema{(:a, :b),Tuple{Int64,Int64},Tuple{Count,Count},5}
    @test sch.names == (:a, :b)
    @test sch.types == (Int, Int)
    @test sch.scitypes == (Count, Count)
    @test sch.nrows == 5

    @test_throws ArgumentError sch.something
    @test propertynames(sch) == (:names, :types, :scitypes, :nrows)

    X = [1,2,3]
    @test_throws ArgumentError schema(X)

    io = IOBuffer()
    show(io, sch)
    sh = String(take!(io))
    @test sh == "Schema{...}()"
end
