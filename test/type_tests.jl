struct MySchemalessTable{U, V}
   x::Vector{U}
   y::Vector{V}
end

Tables.istable(::MySchemalessTable) = true
Tables.columnaccess(::Type{<:MySchemalessTable}) = true
Tables.columns(t::MySchemalessTable) = t

@testset "Tables" begin
    X = (
        x = rand(5),
        y = rand(Int, 5),
        z = categorical(collect("asdfa")),
        w = rand(5)
    )
    s = schema(X)
    @test s.scitypes == (Continuous, Count, Multiclass{4}, Continuous)
    @test s.types == (Float64, Int64, CategoricalValue{Char,UInt32}, Float64)

    @test_throws ArgumentError schema([:x, :y])

    t = scitype(X)
    @test t <: Table(Continuous, Finite, Count)
    @test t <: Table(Infinite, Multiclass)
    @test !(t <: Table(Continuous, Union{Missing, Count}))

    # PR #61 "scitype checks for `Tables.DictColumn`"
    X1 = Dict(:a=>rand(5), :b=>rand(Int, 5))
    s1 = schema(X1)
    @test s1.scitypes == (Continuous, Count)
    @test s1.types == (Float64, Int64)

    #issue 47
    X2 = MySchemalessTable(rand(3), rand(3))
    s2 = schema(X2)
    @test s2 === nothing

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
