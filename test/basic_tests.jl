@testset "(In)Finite" begin
    cv = categorical(['x', 'y'])
    c  = cv[1]
    uv = categorical(['x', 'y'], ordered=true)
    u  = uv[1]
    @test scitype((4, 4.5, c, u, "X")) == Tuple{
                       Count,Continuous,Multiclass{2},OrderedFactor{2},Textual}
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
    @test scitype_union([1, 2.0, "3"]) == Union{Continuous, Count, Textual}
end

@testset "elscitype" begin
    X = randn(5, 5)
    @test scitype(X) == Arr{Continuous, 2}
    @test elscitype(X) == Continuous
    X = [1, 2, missing, 5]
    @test elscitype(X) == Union{Missing,Count}
    X = categorical([1, 2, 3, missing, 2, 1, missing])
    @test elscitype(X) == Union{Missing,Multiclass{3}}
    X = categorical("lksfjalksjdflkjsdlkfjasldkfj" |> collect)
    @test elscitype(X) <: Multiclass
    X = coerce(categorical([1,2,3,1,2,3]), OrderedFactor)
    @test elscitype(X) <: Union{Missing,OrderedFactor}
end

@testset "Arrays" begin
    # COUNT
    @test scitype(A)               == Arr{Union{Count,Continuous}, 2}
    @test scitype([1, 2, 3])       == Vec{Count}
    @test scitype([1, missing, 3]) == Vec{Union{Missing,Count}}
    @test scitype(Any[1, 2, 3])    == Vec{Count}
    @test scitype(Any[1, missing]) == Vec{Union{Missing,Count}}

    # CONTINUOUS
    @test scitype([1.0, 2.0, 3.0])    == Vec{Continuous}
    @test scitype(Any[1.0, missing])  == Vec{Union{Missing,Continuous}}
    @test scitype(Any[1.0, 2.0, 3.0]) == Vec{Continuous}
    @test scitype(Any[1.0, missing])  == Vec{Union{Missing,Continuous}}

    # MULTICLASS
    @test scitype(categorical(1:4))         == Vec{Multiclass{4}}
    @test scitype(view(categorical(1:4), 1:3)) == Vec{Multiclass{4}}
    @test scitype(Any[categorical(1:4)...]) == Vec{Multiclass{4}}
    @test scitype(categorical([1, missing, 3])) ==
        Vec{Union{Multiclass{2},Missing}}
    # NOTE: the slice here does not contain missings but the machine type
    # still contains a missing so the scitype remains with a missing
    @test scitype(categorical([1, missing, 3])[1:1]) ==
        Vec{Union{Multiclass{2},Missing}}

    # ORDEREDFACTOR
    @test scitype(categorical(1:4, ordered=true)) ==
        Vec{OrderedFactor{4}}
    @test scitype(Any[categorical(1:4, ordered=true)...]) ==
        Vec{OrderedFactor{4}}
    @test scitype(categorical([1, missing, 3], ordered=true)) ==
        Vec{Union{OrderedFactor{2},Missing}}
    # NOTE: see note for multiclass
    @test scitype(categorical([1, missing, 3], ordered=true)[1:1]) ==
        Vec{Union{OrderedFactor{2},Missing}}
end

@testset "Images" begin
    black = RGB(0, 0, 0)
    color_image = fill(black, (10, 20))
    @test scitype(color_image) == ColorImage{10,20}

    color_image2 = fill(black, (5, 3))
    v = [color_image, color_image2, color_image2]
    @test scitype(v) ==
        Vec{Union{ColorImage{10,20},ColorImage{5,3}}}

    white = Gray(1.0)
    gray_image = fill(white, (10, 20))
    @test scitype(gray_image) == GrayImage{10,20}
end

@testset "PersistenceDiagrams" begin
    diagram = PersistenceDiagram([(1, Inf), (2, 3)], dim=0)
    @test scitype(diagram) == PersistenceDiagram

    diagrams = [diagram, diagram, diagram]
    @test scitype(diagrams) == Vec{PersistenceDiagram}
end

@testset "temporal types" begin
    d = Date(2020, 4, 21)
    t = Time(8, 15, 42)
    dt = now()
    @test scitype(d) == ScientificDate
    @test scitype(t) == ScientificTime
    @test scitype(dt) == ScientificDateTime
    @test scitype(vcat([missing, ], fill(d, 3))) ==
        AbstractVector{Union{Missing,ScientificDate}}
    @test scitype(vcat([missing, ], fill(t, 3))) ==
        AbstractVector{Union{Missing,ScientificTime}}
    @test scitype(vcat([missing, ], fill(dt, 3))) ==
        AbstractVector{Union{Missing,ScientificDateTime}}
    @test scitype([missing, d, t]) ==
        AbstractVector{Union{Missing,ScientificTimeType}}
end

@testset "Type coercion" begin
    X = (x=10:10:44, y=1:4, z=collect("abcd"))

    # test fix for issue 39
    y = collect(Int64, 1:5)
    @test_throws ScientificTypes.CoercionError coerce(y, Float64)
    @test_throws ScientificTypes.CoercionError coerce(y, Textual)
    @test_throws ScientificTypes.CoercionError coerce(X, :x=>Float64)
    @test_throws ScientificTypes.CoercionError coerce(X, :x=>Textual)

    types = Dict(:x => Continuous, :z => Multiclass)
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
    X_coerced = coerce(X, Dict{Symbol, Type}())
    @test X_coerced.x === X.x
    @test X_coerced.z === X.z
    z = categorical(X.z)
    @test coerce(z, Multiclass) === z
    z = categorical(X.z, compress=true, ordered=false)
    @test coerce(z, Multiclass) === z
    z = categorical(X.z, compress=true, ordered=true)
    @test coerce(z, OrderedFactor) === z

    # missing values
    y_coerced = @test_logs(
        (:info, r"Trying to coerce from `Union{Missing,"),
        coerce([4, 7, missing], Continuous))
    @test ismissing(y_coerced == [4.0, 7.0, missing])
    @test scitype_union(y_coerced) === Union{Missing,Continuous}
    y_coerced = @test_logs(
        (:info, r"Trying to coerce from `Any"),
        coerce(Any[4, 7.0, missing], Continuous))
    @test ismissing(y_coerced == [4.0, 7.0, missing])
    @test scitype_union(y_coerced) === Union{Missing,Continuous}
    y_coerced = @test_logs(
        (:info, r"Trying to coerce from `Union{Missing,"),
        coerce([4.0, 7.0, missing], Count))
    @test ismissing(y_coerced == [4, 7, missing])
    @test scitype_union(y_coerced) === Union{Missing,Count}
    y_coerced = @test_logs(
        (:info, r"Trying to coerce from `Any"),
        coerce(Any[4, 7.0, missing], Count))
    @test ismissing(y_coerced == [4, 7, missing])
    @test scitype_union(y_coerced) === Union{Missing,Count}
    @test scitype_union(@test_logs(
        (:info, r"Trying to coerce from `Union{Missing,"),
        coerce(['x', 'y', missing], Multiclass))) ===
            Union{Missing, Multiclass{2}}
    @test scitype_union(@test_logs(
        (:info, r"Trying to coerce from `Union{Missing,"),
        coerce(['x', 'y', missing], OrderedFactor))) ===
            Union{Missing, OrderedFactor{2}}
    # non-missing Any vectors
    @test coerce(Any[4, 7],     Continuous) == [4.0, 7.0]
    @test coerce(Any[4.0, 7.0], Continuous) == [4, 7]

    # Finite conversions:
    @test scitype_union(coerce(['x', 'y'], Finite)) === Multiclass{2}
    @test scitype_union(@test_logs(
        (:info, r"Trying to coerce from `Union{Missing,"),
        coerce(['x', 'y', missing], Finite))) === Union{Missing, Multiclass{2}}

    # More finite conversions (to check resolution of #48):
    y = categorical([1, 2, 3, missing]) # unordered
    yc = coerce(y, Union{Missing,OrderedFactor})
    @test isordered(yc)
    @test yc[1].pool.ordered
    @test scitype(yc) == Vec{Union{Missing,OrderedFactor{3}}}
    @test scitype_union(yc) == Union{Missing,OrderedFactor{3}}
    @test scitype_union(y) == Union{Missing,Multiclass{3}}

end

@testset "coerce arrays" begin
    A = rand(Int, 2, 3)
    z = rand(Char, 2, 3)
    y = Any[1.0 2; 3 4]
    @test scitype_union(coerce(A, Continuous)) == Continuous
    @test scitype_union(coerce(A, OrderedFactor)) <: OrderedFactor
    @test scitype_union(coerce(z, Multiclass)) <: Multiclass
    @test scitype_union(coerce(y, Count)) === Count
end

@testset "Real->OF" begin
    v = [0.1, 0.2, 0.2, 0.3, missing, 0.1]
    w = [0.1, 0.2, 0.2, 0.3, 0.1]
    @test_logs((:info, r"Trying to coerce from `Union{Missing,"),
                   global cv = coerce(v, OrderedFactor))
    cw = coerce(w, OrderedFactor)
    @test all(skipmissing(unique(cv)) .== [0.1, 0.2, 0.3])
    @test all(unique(cw) .== [0.1, 0.2, 0.3])
end

@testset "Any->MC" begin
    v2 = Symbol.(collect("asdfghj"))
    global v2c = @test_logs((:warn, r"Converting array"),
                            coerce(v2, Multiclass))
    @test scitype_union(v2c) == Multiclass{7}
    @test eltype(v2c) <: Union{Missing,CategoricalValue{String}}

    v3 = Any[1, 2, 3]
    coerce(v3, Multiclass) # should be no warning here

    # normal behaviour
    v1 = categorical([1,2,1,2,1,2,missing])
    v2 = collect("aksldjfalsdjkfslkjdfalksjdf")
    @test_logs((:info, r"Trying to coerce from `Union"),
               global v1c = coerce(v1, Multiclass))
    global v2c # otherwise julia complains...
    v2c = coerce(v2, Multiclass)
    @test scitype_union(v1c) == Union{Missing,Multiclass{2}}
    @test scitype_union(v2c) == Multiclass{7}
    @test eltype(v1c) <: Union{Missing,CategoricalValue{Int64}}
    @test eltype(v2c) <: CategoricalValue{Char}
end

@testset "Cat->C" begin
    a = categorical(["a","b","a","b",missing])
    a1 = coerce(a, Union{Count,Missing})
    @test scitype_union(a1) == Union{Missing,Count}
    @test all(skipmissing(a1 .== [1, 2, 1, 2, missing]))
    a1 = coerce(a, Union{Continuous,Missing})
    @test scitype_union(a1) == Union{Missing,Continuous}
    @test all(skipmissing(a1 .== [1., 2., 1., 2., missing]))

    y = categorical(1:10, ordered=true)
    new_order = [4, 10, 9, 7, 6, 2, 8, 3, 1, 5]
    levels!(y, new_order)
    @test all(coerce(y, Count) .== sortperm(new_order))
    @test all(coerce(y, Count) .== [9, 6, 8, 1, 10, 5, 4, 7, 3, 2])

    y = categorical([1:10..., missing, 11], ordered=true)
    @test all(skipmissing(coerce(y, Union{Continuous, Missing}) .==
                          float([1:10...,missing,11])))
end

# issue #62 (ScientficTypes)
@testset "Type=>Type" begin
    X = (x=[1,2,1,2,5,1,0,7],
         y=[0,1,0,1,0,1,0,1],
         z=['a','b','a','b','a','a',missing,missing])
    Xc = coerce(X, :y=>OrderedFactor)
    Xc = coerce(Xc, Count=>Continuous)
    @test elscitype(Xc.x) == Continuous
    @test elscitype(Xc.y) == OrderedFactor{2}
    Xc = coerce(Xc, OrderedFactor=>Count)
    @test elscitype(Xc.y) == Count
    Xc = coerce(Xc, :z=>Multiclass, verbosity=0)
    Xc = coerce(Xc, Multiclass=>OrderedFactor, verbosity=0)
    @test elscitype(Xc.z) == Union{Missing,OrderedFactor{2}}
    Xc = coerce(X, Count=>Continuous, Unknown=>Multiclass, verbosity=0)
    @test elscitype(Xc.x) == Continuous
    @test elscitype(Xc.y) == Continuous
    @test elscitype(Xc.z) == Union{Missing,Multiclass{2}}
end

# issue #13

@testset "mixture of Type=>Type and Symbol=>Type" begin
    X = (x=10:10:44, y=1:4, z=collect("abcd"), w=["a", "b", "c", missing])
    @test ScientificTypes.feature_scitype_pairs(:x => Continuous, X) ==
        [:x => Continuous, ]
    @test ScientificTypes.feature_scitype_pairs(Count => Continuous, X) ==
        [:x => Union{Continuous}, :y=> Union{Continuous}]
    X1 = coerce(X, :z => Multiclass, Count=>Continuous)
    @test schema(X1).scitypes ==
        (Continuous, Continuous, Multiclass{4}, Union{Missing,Textual})
    X2 = coerce(X, :z => Multiclass, :w=>Multiclass, Count=>Continuous,
                verbosity=0)
    @test schema(X2).scitypes ==
        (Continuous, Continuous, Multiclass{4}, Union{Missing,Multiclass{3}})
    @test_throws ArgumentError coerce(X, Count => Continuous, :x=>Multiclass)
end

@testset "Image" begin
    #1. Single GrayImage:
    img = rand(10, 10)
    @test coerce(img, GrayImage) |> size == size(img)
    @test scitype(coerce(img, GrayImage)) == GrayImage{10, 10}

    #2. Single colorimage
    img = rand(10, 10, 3)
    @test coerce(img, ColorImage) |> size == (10, 10)
    @test scitype(coerce(img, ColorImage)) == ColorImage{10, 10}

    #3. Collection: 3dcollection -> GrayImage
    imgs = rand(10, 10, 3)
    @test coerce(imgs, GrayImage) |> size == (3,)
    @test scitype(coerce(imgs, GrayImage)) == AbstractArray{GrayImage{10, 10},1}

    #4. Collection: 4dcollection -> GrayImage
    imgs = rand(10, 10, 1, 3)
    @test coerce(imgs, GrayImage) |> size == (3,)
    @test scitype(coerce(imgs, GrayImage)) == AbstractArray{GrayImage{10, 10},1}

    #5. Collection : 4dcollection -> ColorImage
    imgs = rand(10, 10, 3, 5)
    @test coerce(imgs, ColorImage) |> size == (5,)
    @test scitype(coerce(imgs, ColorImage)) == AbstractArray{ColorImage{10,10},1}
end
