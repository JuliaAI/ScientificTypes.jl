@testset "scitype" begin
    X = [1, 2, 3]
    @test scitype(X) == AbstractVector{Unknown}
end
