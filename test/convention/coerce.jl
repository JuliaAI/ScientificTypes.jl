# -----------------------------------------------------------------------------------------
##############
## Basic (Behavioural tests)
##############

# ----------------------------------------------------------------------------------------------------------------------
###############
## Detailed Tests
###############

@testset "coerce arrays" begin
    A = rand(Int, 2, 3)
    z = rand(Char, 2, 3)
    y = Any[1.0 2; 3 4]
    @test scitype_union(coerce(A, Continuous)) == Continuous
    @test scitype_union(coerce(A, OrderedFactor)) <: OrderedFactor
    @test scitype_union(coerce(z, Multiclass)) <: Multiclass
    @test scitype_union(coerce(y, Count)) === Count
    
    # test fix for issue 39
    y = collect(Int64, 1:5)
    @test_throws ScientificTypes.CoercionError coerce(y, Float64)
    @test_throws ScientificTypes.CoercionError coerce(y, Textual)

    @testset "coersion of Real->OrderedFactor" begin
        v = [0.1, 0.2, 0.2, 0.3, missing, 0.1]
        w = [0.1, 0.2, 0.2, 0.3, 0.1]
        @test_logs((:info, r"Trying to coerce from `Union{Missing,"),
                    global cv = coerce(v, OrderedFactor))
        cw = coerce(w, OrderedFactor)
        @test all(skipmissing(unique(cv)) .== [0.1, 0.2, 0.3])
        @test all(unique(cw) .== [0.1, 0.2, 0.3])
    end

    @testset "coersion of Any->MultiClass" begin
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

    @testset "coerce Categorical->Continuous" begin
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

    # see issue 9
    @testset "coerce Text=>Num" begin
        x = ["52", "15", "125"]
        cx = coerce(x, Count)
        @test cx == [52, 15, 125]
        cx = coerce(x, Continuous)
        @test cx == [52.0, 15.0, 125.0]
        x = ["52", "15", "125", missing]
        cx = coerce(x, Union{Count,Missing})
        @test all(cx .=== [52, 15, 125, missing])
        cx = coerce(x, Union{Missing,Continuous})
        @test all(cx .=== [52.0, 15.0, 125.0, missing])
        @test_logs (:info, "Trying to coerce from `Union{Missing, String}` to `Count`.\nCoerced to `Union{Missing,Count}` instead.") coerce(x, Count)
    end
end

@testset "coersion of Images" begin
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

# TODO: CSV as testing dep is causing issues for julia 1.0. Perhaps
# the followinng can be re-instated when we have a new LTS release:

# if VERSION ≥ v"1.3.0-"
#    @testset "Coerce Col2" begin
#       X = Tables.table(ones(1_000, 2))
#       tmp = tempname()
#       CSV.write(tmp, X)
#       data = CSV.read(tmp, DataFrame)
#       # data.Column1 and data.Column2 are Column2 (as of CSV 5.19)
#       @test data.Column1 isa AbstractArray{<:AbstractFloat}
#       dc = coerce(data, autotype(data, :discrete_to_continuous))
#       @test scitype(dc) == Table{AbstractArray{Continuous,1}}
#       rm(tmp)
#    end
# end


@testset "misc" begin
    x = Any['a', 5]
    @test (@test_logs (:info, "Char value encountered, such value will be coerced according to the corresponding numeric value (e.g. 'A' to 65).") coerce(x, Count)) == [97, 5]
    x = categorical(['a','b','a','b'])
    @test coerce(x, Continuous) == [1.0,2.0,1.0,2.0]
    y = [missing, 1, 2]
    x = y[2:end]
    c = ScientificTypes._tighten_if_needed(x, eltype(x), true)
    @test c == [1, 2]
    @test eltype(c) == Int
    y = categorical([missing,1,2])
    x = y[2:end]
    @test eltype(x) >: Missing
    c = ScientificTypes._tighten_if_needed(x, eltype(x), true)
    @test c == [1,2]
    @test eltype(c) == Int
    c = coerce(x, OrderedFactor, tight=true)
    @test c == categorical([1,2])
    @test !(eltype(c) >: Missing)
end