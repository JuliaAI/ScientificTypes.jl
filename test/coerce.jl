@testset "Basic Type coercion tests" begin
    X = (x=10:10:44, y=1:4, z=collect("abcd"))

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
    @test scitype(yc) == Vec{Union{Missing, OrderedFactor{3}}}
    @test scitype_union(yc) == Union{Missing, OrderedFactor{3}}
    @test scitype_union(y) == Union{Missing, Multiclass{3}}

    # tests fix for issue https://github.com/JuliaAI/ScientificTypes.jl/issues/161
    X = (x=10:10:44, y=1:4, z=collect("abcd"))
    Xc = coerce(X, :x => Continuous, "y" => Continuous)
    @test scitype_union(Xc.x) === Continuous
    @test scitype_union(Xc.y) === Continuous
end

# issue #62 (ScientficTypes)
@testset "coersion of Type=>Type" begin
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
    @test elscitype(Xc.z) == Union{Missing, Multiclass{2}}
end

# issue #13
@testset "coersion of mixture of Type=>Type and Symbol=>Type" begin
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

@testset "coerce!" begin
    df = DataFrame((x=ones(Int,5), y=ones(5)))
     @test scitype(df) == Table{Union{AbstractArray{Continuous,1},
                                      AbstractArray{Count,1}}}
    coerce!(df, :x=>Continuous)
    @test scitype(df) == Table{AbstractArray{Continuous,1}}
 
    df = DataFrame((
          x=ones(Int, 50),
          y=ones(50),
          z=collect("abbabaacbcabbabaacbbcccbccbbabaaacacbcabcbccaabaaa")
          ))
     @test scitype(df) == Table{Union{AbstractArray{Continuous,1},
                                      AbstractArray{Count,1},
                                      AbstractArray{Unknown,1}}}
 
    coerce!(df, autotype(df, :few_to_finite))
     @test scitype(df) == Table{Union{AbstractArray{Multiclass{3},1},
                                      AbstractArray{OrderedFactor{1},1}}}
 
    @test_throws ScientificTypes.CoercionError coerce!(randn(5, 5))

    df2 = DataFrame(x=[1,2,3,4],
    y=["a","b","c","a"],
    z = Union{Missing,Int}[10, 20, 30, 40])
    coerce!(df2, Textual=>Finite)
    coerce!(df2, Union{Missing, Count}=>Count, tight=true) # issue #166
    @test scitype(df2) == Table{Union{AbstractArray{Count,1},
                      AbstractArray{Multiclass{3},1} }}
    
    # issue #9 (coerce Text => Num)
    df3 = DataFrame(x=["1","2","3"], y=[2,3,4])
    coerce!(df3, Textual=>Count)
    @test scitype(df3) == Table{AbstractArray{Count,1}}
    
    x = [1,2,3,4]
    @test_throws ScientificTypes.CoercionError coerce!(x, Continuous)

end
