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
    sugg_types = autotype(X1)
    @test sugg_types[:book]   == Multiclass
    @test sugg_types[:number] == Multiclass
    @test sugg_types[:gender] == Multiclass
    @test sugg_types[:random] == Unknown

    # now with missing values
    sugg_types = autotype(X2)
    @test sugg_types[:a] == Union{Missing,Multiclass}
    @test sugg_types[:b] == Continuous
    @test sugg_types[:c] == Count
    @test sugg_types[:d] == Multiclass
    @test sugg_types[:e] == Union{Missing,OrderedFactor}
    @test sugg_types[:f] == Multiclass
end

@testset "autotype-coercion" begin
    X2c = coerce(X2, autotype(X2))
    @test schema(X2).scitypes == (Union{Missing, Unknown},   # a
                                 Continuous,                # b
                                 Count,                     # c
                                 Unknown,                   # d
                                 Union{Missing, Count},     # e
                                 Count)                     # f
    @test schema(X2c).scitypes == (Union{Missing, Multiclass{nobj_a}},  # a*
                                 Continuous,                           # b
                                 Count,                                # c
                                 Multiclass{nobj_d},                   # d*
                                 Union{Missing,OrderedFactor{nobj_e}}, # e*
                                 Multiclass{nobj_f})                   # f*

    # test only_changes
    sugg_types = autotype(X2; only_changes=true)
    @test Set(keys(sugg_types)) == Set([:a, :d, :e, :f])
    @test sugg_types[:a] == Union{Missing,Multiclass}
    @test sugg_types[:f] == Multiclass
end

@testset "autotype-d2c" begin
    sugg_types = autotype(X2; only_changes=true, rules=(:discrete_to_continuous,))
    @test Set(keys(sugg_types)) == Set([:c, :e, :f])
    @test sugg_types[:c] == Continuous

    # now **after** already using few_to_finite
    sugg_types = autotype(X2; only_changes=true, rules=(:few_to_finite, :discrete_to_continuous))
    @test sugg_types[:a] == Union{Missing,Multiclass}
    @test sugg_types[:c] == Continuous
    @test sugg_types[:d] == Multiclass
    @test sugg_types[:e] == Union{Missing,OrderedFactor}
    @test sugg_types[:f] == Multiclass
end

@testset "autotype-s2c" begin
    sugg_types = autotype(X2; only_changes=true, rules=(:string_to_class,))
    @test Set(keys(sugg_types)) == Set([:a, :d])
    @test sugg_types[:a] == Multiclass
end
