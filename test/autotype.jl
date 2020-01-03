###################
#### Basic tests
###################

Random.seed!(5)
n = 5
X1 = (book=["red", "white", "blue", "blue", "white"],
     number=[0, 1, 1, 0, 1, 0],
     gender=['M', 'F', 'F', 'M', 'F'],
     random=[Random.randstring(4) for i in 1:n])
n = 10
X2 = (
    a = ['M', 'M', 'F', missing, 'F', 'F', 'M', 'F', missing, 'M'],
    b = randn(n),
    c = abs.(Int.(floor.(5*randn(n)))),
    d = ["aaa", "bbb", "bbb", "ccc", "ddd", "ddd", "ccc", "aaa"],
    e = [1, 2, 3, 4, 4, 3, 2, 2, 1, missing],
    f = [1, 2, 3, 3, 2, 1, 2, 3, 1, 2],
    )
nobj_a = 2
nobj_d = 4
nobj_e = 4
nobj_f = 3

@testset "autotype-default" begin
    # this is just with few_to_finite
    # -------------------------------
    # no missing
    sugg_types = autotype(X1, only_changes=false)
    @test sugg_types[:book]   == Multiclass
    @test sugg_types[:number] == OrderedFactor
    @test sugg_types[:gender] == Multiclass
    @test sugg_types[:random] == Textual

    # now with missing values
    sugg_types = autotype(X2, only_changes=false)
    @test sugg_types[:a] == Union{Missing,Multiclass}
    @test sugg_types[:b] == Continuous
    @test sugg_types[:c] == Count
    @test sugg_types[:d] == Multiclass
    @test sugg_types[:e] == Union{Missing,OrderedFactor}
    @test sugg_types[:f] == OrderedFactor
end

@testset "autotype-coercion" begin
    X2c = coerce(X2, autotype(X2))
    @test schema(X2).scitypes == (Union{Missing, Unknown},  # a
                                 Continuous,                # b
                                 Count,                     # c
                                 Textual,                   # d
                                 Union{Missing, Count},     # e
                                 Count)                     # f
    @test schema(X2c).scitypes == (Union{Missing, Multiclass{nobj_a}},  # a*
                                 Continuous,                           # b
                                 Count,                                # c
                                 Multiclass{nobj_d},                   # d*
                                 Union{Missing,OrderedFactor{nobj_e}}, # e*
                                 OrderedFactor{nobj_f})                # f*

    # test only_changes
    sugg_types = autotype(X2)
    @test Set(keys(sugg_types)) == Set([:a, :d, :e, :f])
    @test sugg_types[:a] == Union{Missing,Multiclass}
    @test sugg_types[:f] == OrderedFactor
end

@testset "autotype-d2c" begin
    sugg_types = autotype(X2; rules=(:discrete_to_continuous,))
    @test Set(keys(sugg_types)) == Set([:c, :e, :f])
    @test sugg_types[:c] == Continuous

    # now **after** already using few_to_finite
    sugg_types = autotype(X2; rules=(:few_to_finite, :discrete_to_continuous))
    @test sugg_types[:a] == Union{Missing,Multiclass}
    @test sugg_types[:c] == Continuous
    @test sugg_types[:d] == Multiclass
    @test sugg_types[:e] == Union{Missing,OrderedFactor}
    @test sugg_types[:f] == OrderedFactor
end

@testset "autotype-s2c" begin
    sugg_types = autotype(X2; rules=(:string_to_multiclass,))
    @test Set(keys(sugg_types)) == Set([:a, :d])
    @test sugg_types[:a] == Union{Missing,Multiclass}
end

@testset "autotype of a table that is also an array" begin
    X = (x=rand(4),)
    CSV.write("test.csv", X)
    file = CSV.file("test.csv")
    @test autotype(file) == autotype(X)
    rm("test.csv")
end

#######################
#### Detailed tests
#######################

@testset "autotype-utils" begin
    @test S.nonmissing(Union{Missing,Real}) == Real
    @test S.nonmissing(Real) == Real
    @test S.nonmissing(Union{Missing,Multiclass}) == Multiclass
    @test S.T_or_Union_Missing_T(Union{Missing,Real},Float64) == Union{Missing,Float64}
    @test S.T_or_Union_Missing_T(Real, Float64) == Float64
    @test S.sugg_finite(Union{Missing,Float64}) == OrderedFactor
    @test S.sugg_finite(Union{Missing,String}) == Multiclass
    @test S.sugg_finite(Float64) == OrderedFactor
    @test S.sugg_finite(String) == Multiclass
    @test S.sugg_finite(Char) == Multiclass
    @test S.sugg_finite(Int) == OrderedFactor
end

@testset ":string_to_multiclass" begin
    n = nothing
    M = Missing
    @test S.string_to_multiclass(Continuous, n, n) == Continuous
    col = ('A', 'B', 'C')
    @test S.string_to_multiclass(Textual, col, n) == Multiclass
    col = ('A', 'B', 'C', missing)
    @test S.string_to_multiclass(Textual, col, n) == Union{M,Multiclass}
    col = (1, 2, 3, 4, 5)
    @test S.string_to_multiclass(Textual, col, n) == Textual
    col = (1, 2, 3, 4, 5, missing)
    @test S.string_to_multiclass(Union{M,Textual}, col, n) == Union{M,Textual}
    @test S.string_to_multiclass(Textual, col, n) == Textual
    col = ("aa", "bb", "cc")
    @test S.string_to_multiclass(Multiclass, col, n) == Multiclass
    @test S.string_to_multiclass(Textual, col, n) == Multiclass
    col = ("aa", "bb", "cc", missing)
    @test S.string_to_multiclass(Union{M,Textual}, col, n) == Union{M,Multiclass}
    @test S.string_to_multiclass(Textual, col, n) == Union{M,Multiclass}
end

@testset ":discrete_to_continuous" begin
    n = nothing
    M = Missing
    @test S.discrete_to_continuous(Integer, n, n) == Continuous
    @test S.discrete_to_continuous(Real, n, n) == Real
    @test S.discrete_to_continuous(Count, n, n) == Continuous
    @test S.discrete_to_continuous(OrderedFactor, n, n) == OrderedFactor
    @test S.discrete_to_continuous(Union{M,Integer}, n, n) == Union{M,Continuous}
    @test S.discrete_to_continuous(Union{M,Real}, n, n) == Union{M,Real}
    @test S.discrete_to_continuous(Union{M,Count}, n, n) == Union{M,Continuous}
    @test S.discrete_to_continuous(Union{M,OrderedFactor}, n, n) == Union{M,OrderedFactor}
end

@testset ":few_to_finite" begin
    n = nothing
    M = Missing
    # short return
    @test S.few_to_finite(Multiclass, n, 0) == Multiclass
    @test S.few_to_finite(OrderedFactor, n, 1) == OrderedFactor
    @test S.few_to_finite(Union{M,Multiclass}, n, 0) == Union{M,Multiclass}
    @test S.few_to_finite(Union{M,OrderedFactor}, n, 1) == Union{M,OrderedFactor}
    # apply
    col = Random.rand("abcd", 50)
    st  = scitype(col[1])
    @test S.few_to_finite(st, col, length(col)) == Multiclass
    col = Random.rand([1,2,3], 50)
    st  = scitype(col[1])
    @test S.few_to_finite(st, col, length(col)) == OrderedFactor
    col = Random.rand([1,2,3,4], 50)
    st = scitype(col[1])
    @test S.few_to_finite(st, col, length(col)) == OrderedFactor
    col = Random.rand([true, false], 50)
    st = scitype(col[1])
    @test S.few_to_finite(st, col, length(col)) == OrderedFactor
    col = randn(50)
    st = scitype(col[1])
    @test S.few_to_finite(st, col, length(col)) == st
    col = Int.(ceil.(100*randn(100)))
    st = scitype(col[1])
    @test S.few_to_finite(st, col, length(col)) == st
end


@testset "bool->OF" begin
    X = (v = [false, true, false, true, missing],
         z = [0, 1, 0, 1, 0])
    Xc = coerce(X, autotype(X))
    @test scitype_union(Xc.v) == Union{Missing,OrderedFactor{2}}
    @test scitype_union(Xc.z) == OrderedFactor{2}
end


@testset "Auto for Array" begin
    X = ones(Int, 5, 5)
    @test autotype(X, (:discrete_to_continuous,)) == Continuous
    @test autotype(X, :discrete_to_continuous) == Continuous
    X = reshape([3.415 for i in 1:9], 3, 3)
    @test autotype(X) == OrderedFactor # using :few_to_finite
end
