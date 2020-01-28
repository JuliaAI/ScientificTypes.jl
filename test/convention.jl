@testset "convention" begin
    set_convention(ScientificTypes.NoConvention)
    c = ""
    @test_logs (:warn, "No convention specified. Did you forget to use the `set_convention` function?") (c = convention())
    @test c isa ScientificTypes.NoConvention

    struct MockMLJ <: Convention end
    set_convention(MockMLJ)
    c = convention()
    @test c isa MockMLJ
end

@testset "trait" begin
    TRAIT_FUNCTION_GIVEN_NAME[:table] = Tables.istable

    isjunk(::Any)     = false
    isjunk(s::String) = s == "junk" ? true : false
    TRAIT_FUNCTION_GIVEN_NAME[:junk] = isjunk

    ScientificTypes.info(object, ::Val{:junk}) = length(object)

    X = (x = [1,2,3],
         y = [5,5,7])
    @test trait(X)     == :table
    @test info("junk") == 4
    X = [1,2,3]
    @test trait(X) == :other
end

@testset "nonmissing" begin
    U = Union{Missing,Int}
    @test nonmissing(U) == Int
end
