using Test
using ScientificTypes
using CategoricalArrays
using Tables
using ColorTypes
using Random

const S = ScientificTypes

include("basic_tests.jl")

@testset "Finite and Infinite" begin
    cv = categorical([:x, :y])
    c = cv[1]
    uv = categorical([:x, :y], ordered=true)
    u = uv[1]

    @test scitype((4, 4.5, c, u, "X")) ==
    Tuple{Count,Continuous,Multiclass{2},
          OrderedFactor{2},Unknown}
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
    @test scitype(A) ==
        AbstractArray{Union{Count, Continuous}, 2}

    @test scitype([1, 2, 3]) ==
        AbstractVector{Count}
    @test scitype([1, missing, 3]) ==
        AbstractVector{Union{Missing,Count}}
    @test scitype(Any[1, 2, 3]) ==
        AbstractVector{Count}
    @test scitype(Any[1, missing, 3]) ==
        AbstractVector{Union{Missing,Count}}

    @test scitype([1.0, 2.0, 3.0]) ==
        AbstractVector{Continuous}
    @test scitype(Any[1.0, missing, 3.0]) ==
        AbstractVector{Union{Missing,Continuous}}
    @test scitype(Any[1.0, 2.0, 3.0]) ==
        AbstractVector{Continuous}
    @test scitype(Any[1.0, missing, 3.0]) ==
        AbstractVector{Union{Missing,Continuous}}

    @test scitype(categorical(1:4)) ==
        AbstractVector{Multiclass{4}}
    @test scitype(Any[categorical(1:4)...]) ==
        AbstractVector{Multiclass{4}}
    @test scitype(categorical([1, missing, 3])) ==
        AbstractVector{Union{Multiclass{2},Missing}}
    @test scitype(categorical([1, missing])[1:1]) ==
        AbstractVector{Multiclass{1}}

    @test scitype(categorical(1:4, ordered=true)) ==
        AbstractVector{OrderedFactor{4}}
    @test scitype(Any[categorical(1:4, ordered=true)...]) ==
        AbstractVector{OrderedFactor{4}}
    @test scitype(categorical([1, missing, 3], ordered=true)) ==
        AbstractVector{Union{OrderedFactor{2},Missing}}
    @test scitype(categorical([1, missing], ordered=true)[1:1]) ==
        AbstractVector{OrderedFactor{1}}

end

@testset "Images" begin
    black = RGB(0, 0, 0)
    color_image = fill(black, (10, 20))
    @test scitype(color_image) == ColorImage{10,20}

    color_image2 = fill(black, (5, 3))
    v = [color_image, color_image2, color_image2]
    @test scitype(v) ==
        AbstractVector{Union{ColorImage{10,20},ColorImage{5,3}}}

    white = Gray(1.0)
    gray_image = fill(white, (10, 20))
    @test scitype(gray_image) == GrayImage{10,20}
end

@testset "Type coercion" begin
    X=(x=10:10:44, y=1:4, z=collect("abcd"))
    types = Dict(:x => Continuous, :z => Multiclass)
#   X_coerced = @test_logs coerce(X, types)
    X_coerced = coerce(X, types)
    @test X_coerced ==  coerce(X, :x => Continuous, :z => Multiclass)
    @test scitype_union(X_coerced.x) === Continuous
    @test scitype_union(X_coerced.z) <: Multiclass
    @test !X_coerced.z.pool.ordered
    @test_throws MethodError coerce(["a", "b", "c"], Count)
    y = collect(Float64, 1:5)
    y_coerced = coerce(y, Count)
    @test scitype_union(y_coerced) === Count
    @test y_coerced == y
    y = [1//2, 3//4, 6//5]
    y_coerced = coerce(y, Continuous)
    @test scitype_union(y_coerced) === Continuous
    @test y_coerced ≈ y
    X_coerced = coerce(X, Dict(:z => OrderedFactor))
#    X_coerced = @test_logs coerce(X, Dict(:z => OrderedFactor))
    @test X_coerced == coerce(X, :z => OrderedFactor)
    @test X_coerced.x === X.x
    @test scitype_union(X_coerced.z) <: OrderedFactor
    @test X_coerced.z.pool.ordered
    # Check no-op coercion
    y = rand(Float64, 5)
    @test coerce(y, Continuous) === y
    y = rand(Float32, 5)
    @test coerce(y, Continuous) === y
    y = rand(BigFloat, 5)
    @test coerce(y, Continuous) === y
    y = rand(Int, 5)
    @test coerce(y, Count) === y
    y = big.(y)
    @test coerce(y, Count) === y
    y = rand(UInt32, 5)
    @test coerce(y, Count) === y
    X_coerced = coerce(X, Dict())
    @test X_coerced.x === X.x
    @test X_coerced.z === X.z
    z = categorical(X.z)
    @test coerce(z, Multiclass) === z
    z = categorical(X.z, true, ordered = false)
    @test coerce(z, Multiclass) === z
    z = categorical(X.z, true, ordered = true)
    @test coerce(z, OrderedFactor) === z
    # missing values
    y_coerced = @test_logs((:warn, r"Missing values encountered"),
                           coerce([4, 7, missing], Continuous))
    @test ismissing(y_coerced == [4.0, 7.0, missing])
    @test scitype_union(y_coerced) === Union{Missing,Continuous}
    y_coerced = @test_logs((:warn, r"Missing values encountered"),
                           coerce(Any[4, 7.0, missing], Continuous))
    @test ismissing(y_coerced == [4.0, 7.0, missing])
    @test scitype_union(y_coerced) === Union{Missing,Continuous}
    y_coerced = @test_logs((:warn, r"Missing values encountered"),
                           coerce([4.0, 7.0, missing], Count))
    @test ismissing(y_coerced == [4, 7, missing])
    @test scitype_union(y_coerced) === Union{Missing,Count}
    y_coerced = @test_logs((:warn, r"Missing values encountered"),
                           coerce(Any[4, 7.0, missing], Count))
    @test ismissing(y_coerced == [4, 7, missing])
    @test scitype_union(y_coerced) === Union{Missing,Count}
#    @test scitype_union(@test_logs((:warn, r"Missing values encountered"),
#                                   coerce([:x, :y, missing], Multiclass))) ===
    @test scitype_union(coerce([:x, :y, missing], Multiclass)) ===
        Union{Missing, Multiclass{2}}
    # @test scitype_union(@test_logs((:warn, r"Missing values encountered"),
    #                                coerce([:x, :y, missing], OrderedFactor))) ===
    #                                    Union{Missing, OrderedFactor{2}}
    scitype_union(coerce([:x, :y, missing], OrderedFactor)) ===
                                       Union{Missing, OrderedFactor{2}}
    # non-missing Any vectors
    @test coerce(Any[4, 7], Continuous) == [4.0, 7.0]
    @test coerce(Any[4.0, 7.0], Continuous) == [4, 7]

end

@testset "coerce R->OF (mlj)" begin
    v = [0.1, 0.2, 0.2, 0.3, missing, 0.1]
    w = [0.1, 0.2, 0.2, 0.3, 0.1]
    cv = coerce(v, OrderedFactor)
    cw = coerce(w, OrderedFactor)
    @test all(skipmissing(unique(cv)) .== [0.1, 0.2, 0.3])
    @test all(unique(cw) .== [0.1, 0.2, 0.3])
end

include("autotype.jl")
