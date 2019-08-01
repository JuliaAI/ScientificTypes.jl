# using Revise
using Test
using ScientificTypes
using CategoricalArrays
using Tables
using ColorTypes

@testset "Finite and Infinite" begin
    cv = categorical([:x, :y])
    c = cv[1]
    uv = categorical([:x, :y], ordered=true)
    u = uv[1]

    @test scitype((4, 4.5, c, u, "X")) ==
    Tuple{Count,Continuous,Multiclass{2},
          OrderedFactor{2},Unknown}

end

@testset "Tables" begin

    X = (x=rand(5), y=rand(Int, 5),
         z=categorical(collect("asdfa")), w=rand(5))
    s = schema(X)
    @test s.scitypes == (Continuous, Count, Multiclass{4}, Continuous)
    @test s.types == (Float64, Int64, CategoricalValue{Char,UInt32}, Float64)

    @test_throws ArgumentError schema([:x, :y])

    t = scitype(X)
    @test t <: ScientificTypes.Table(Continuous, Finite, Count)
    @test t <: ScientificTypes.Table(Infinite, Multiclass)
    @test !(t <: ScientificTypes.Table(Continuous, Union{Missing, Count}))

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
    @test scitype_union([1, 2.0, "3"]) == Union{Continuous, Count, Unknown}

end

@testset "Arrays" begin
    @test scitype(A) == AbstractArray{Union{Count, Continuous}, 2}
    @test scitype([1,2,3, missing]) == AbstractVector{Union{Missing, Count}}
end

@testset "Images" begin
    black = RGB(0, 0, 0)
    color_image = fill(black, (10, 10))
    @test scitype(color_image) == ColorImage

    white = Gray(1.0)
    gray_image = fill(white, (10, 10))
    @test scitype(gray_image) == GrayImage
end

@testset "Type coercion" begin
    X=(x=10:10:44, y=1:4, z=collect("abcd"))
    types = Dict(:x => Continuous, :z => Multiclass)
    X_coerced = @test_logs coerce(types, X)
    @test scitype_union(X_coerced.x) === Continuous
    @test scitype_union(X_coerced.z) <: Multiclass
    @test !X_coerced.z.pool.ordered
    @test_throws MethodError coerce(Count, ["a", "b", "c"])
    y = collect(Float64, 1:5)
    y_coerced = coerce(Count, y)
    @test scitype_union(y_coerced) === Count
    @test y_coerced == y
    y = [1//2, 3//4, 6//5]
    y_coerced = coerce(Continuous, y)
    @test scitype_union(y_coerced) === Continuous
    @test y_coerced ≈ y
    X_coerced = @test_logs coerce(Dict(:z => OrderedFactor), X)
    @test X_coerced.x === X.x
    @test scitype_union(X_coerced.z) <: OrderedFactor
    @test X_coerced.z.pool.ordered
    # Check no-op coercion
    y = rand(Float64, 5)
    @test coerce(Continuous, y) === y
    y = rand(Float32, 5)
    @test coerce(Continuous, y) === y
    y = rand(BigFloat, 5)
    @test coerce(Continuous, y) === y
    y = rand(Int, 5)
    @test coerce(Count, y) === y
    y = big.(y)
    @test coerce(Count, y) === y
    y = rand(UInt32, 5)
    @test coerce(Count, y) === y
    X_coerced = coerce(Dict(), X)
    @test X_coerced.x === X.x
    @test X_coerced.z === X.z
    z = categorical(X.z)
    @test coerce(Multiclass, z) === z
    z = categorical(X.z, true, ordered = false)
    @test coerce(Multiclass, z) === z
    z = categorical(X.z, true, ordered = true)
    @test coerce(OrderedFactor, z) === z
    # missing values
    y_coerced = @test_logs((:warn, r"Missing values encountered"),
                           coerce(Continuous, [4, 7, missing]))
    @test ismissing(y_coerced == [4.0, 7.0, missing])
    @test scitype_union(y_coerced) === Union{Missing,Continuous}
    y_coerced = @test_logs((:warn, r"Missing values encountered"),
                           coerce(Continuous, Any[4, 7.0, missing]))
    @test ismissing(y_coerced == [4.0, 7.0, missing])
    @test scitype_union(y_coerced) === Union{Missing,Continuous}
    y_coerced = @test_logs((:warn, r"Missing values encountered"),
                           coerce(Count, [4.0, 7.0, missing]))
    @test ismissing(y_coerced == [4, 7, missing])
    @test scitype_union(y_coerced) === Union{Missing,Count}
    y_coerced = @test_logs((:warn, r"Missing values encountered"),
                           coerce(Count, Any[4, 7.0, missing]))
    @test ismissing(y_coerced == [4, 7, missing])
    @test scitype_union(y_coerced) === Union{Missing,Count}
    @test scitype_union(@test_logs((:warn, r"Missing values encountered"),
                                   coerce(Multiclass, [:x, :y, missing]))) ===
        Union{Missing, Multiclass{2}}
    @test scitype_union(@test_logs((:warn, r"Missing values encountered"),
                                   coerce(OrderedFactor, [:x, :y, missing]))) ===
                                       Union{Missing, OrderedFactor{2}}
    # non-missing Any vectors
    @test coerce(Continuous, Any[4, 7]) == [4.0, 7.0]
    @test coerce(Count, Any[4.0, 7.0]) == [4, 7]

    # corner case of using dictionary of types on an abstract vector:
    @test scitype_union(coerce(Dict(:x=>Count), [1.0, 2.0])) <:  Count

end

