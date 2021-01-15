struct MockMLJ <: Convention end

@testset "convention" begin
    set_convention(ScientificTypes.NoConvention())
    c = ""
    @test_logs (:warn, "No convention specified. Did you forget to use the `set_convention` function?") (c = ST.convention())
    @test c isa ST.NoConvention

    set_convention(MockMLJ())
    c = ST.convention()
    @test c isa MockMLJ
end

@testset "trait" begin
    TRAIT_FUNCTION_GIVEN_NAME[:table] = Tables.istable

    isjunk(::Any)     = false
    isjunk(s::String) = s == "junk" ? true : false
    TRAIT_FUNCTION_GIVEN_NAME[:junk] = isjunk

    X = [1,2,3]
    @test ST.trait(X) == :other
    X = (x = [1,2,3],
         y = [5,5,7])
    @test ST.trait(X) == :table
    TRAIT_FUNCTION_GIVEN_NAME[:named_tuple] = X -> X isa NamedTuple
    @test_throws Exception ST.trait(X)
end

@testset "nonmissing" begin
    U = Union{Missing,Int}
    @test nonmissing(U) == Int
end

@testset "table" begin
    T0 = Table(Continuous)
    @test T0 == Table{K} where K<:AbstractVector{<:Continuous}
    T1 = Table(Continuous, Count)
    @test T1 == Table{K} where K<:Union{AbstractVector{<:Continuous}, AbstractVector{<:Count}}
    T2 = Table(Continuous, Union{Missing,Continuous})
    @test T2 == Table{K} where K<:Union{AbstractVector{<:Union{Missing,Continuous}}}
end
