struct MockMLJ <: Convention end

@testset "convention" begin
    ST.set_convention(ScientificTypes.NoConvention())
    c = ""
    @test_logs (:warn, "No convention specified. Did you forget to use the `set_convention` function?") (c = ST.convention())
    @test c isa ST.NoConvention

    struct MockMLJ <: Convention end
    ST.set_convention(MockMLJ())
    c = ST.convention()
    @test c isa MockMLJ
end

@testset "trait" begin
    ST.TRAIT_FUNCTION_GIVEN_NAME[:table] = Tables.istable

    isjunk(::Any)     = false
    isjunk(s::String) = s == "junk" ? true : false
    ST.TRAIT_FUNCTION_GIVEN_NAME[:junk] = isjunk

    X = (x = [1,2,3],
         y = [5,5,7])
    @test ST.trait(X)     == :table
    X = [1,2,3]
    @test ST.trait(X) == :other
end

@testset "nonmissing" begin
    U = Union{Missing,Int}
    @test nonmissing(U) == Int
end
