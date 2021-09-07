@testset "Missing ex" begin
    # these tests only serve as complement to the rest to exemplify
    # the behaviour when there are missing values / any types
    # these tests are more meant to showcase behaviour than thorough testing
    # the rest of the tests are more thorough.

    ## Arr{Union{Missing,T}} --> FINITE
    v  = [1, 2, missing]
    cv = coerce(v, Union{Missing,OrderedFactor})
    @test elscitype(cv) == Union{Missing,OrderedFactor{2}}
    cv = coerce(v[1:2], Union{Missing,OrderedFactor})
    @test elscitype(cv) == Union{Missing,OrderedFactor{2}}

    ## CArr{Union{Missing,T}} --> FINITE
    v  = categorical(['a', 'b', missing])
    cv = coerce(v, Union{Missing,Multiclass})
    @test elscitype(cv) == Union{Missing,Multiclass{2}}
    cv = coerce(v[1:2], Union{Missing,Multiclass}) # no true missing
    @test elscitype(cv) == Union{Missing,Multiclass{2}}

    ## Arr{Union{Missing,T}} --> INFINITE
    v  = [1, 2, 3, missing]
    cv = coerce(v, Union{Missing,Count})
    @test elscitype(cv) == Union{Missing,Count}
    cv = coerce(v[1:3], Union{Missing,Count})
    @test elscitype(cv) == Union{Missing,Count}

    ## CArr{Union{Missing,T}} --> INFINITE
    v  = categorical([1, 2, 3, missing])
    cv = coerce(v, Union{Missing,Count})
    @test elscitype(cv) == Union{Missing,Count}
    cv = coerce(v[1:3], Count)   # NOTE: broadcast
    @test elscitype(cv) == Count

    ## WARNINGs
    v = categorical(['a', 'b', missing])
    @test_logs (:warn,
        "Trying to coerce from `Union{Missing, Char}` to `Multiclass`.\nCoerced to `Union{Missing,Multiclass}` instead."
        ) (cv = coerce(v, Multiclass))
    @test elscitype(cv) == Union{Missing,Multiclass{2}}
end

@testset "Any ex" begin
    # Arr{Any} --> FINITE
    v  = Any[1, 2, 3]
    cv = coerce(v, Union{Missing,OrderedFactor})
    @test elscitype(cv) == Union{Missing,OrderedFactor{3}}
    v  = Any[1, 2, 3, missing]
    cv = coerce(v, Union{Missing,OrderedFactor})
    @test elscitype(cv) == Union{Missing,OrderedFactor{3}}

    # CArr{Any} --> FINITE
    v  = categorical(Any['a', 'b', 'c'])
    cv = coerce(v, Union{Missing,Multiclass})
    @test elscitype(cv) == Union{Missing,Multiclass{3}}
    v  = categorical(Any['a', 'b', missing])
    cv = coerce(v, Union{Missing,Multiclass})
    @test elscitype(cv) == Union{Missing,Multiclass{2}}
    cv = coerce(v[1:2], Union{Missing,Multiclass}) # no true missing
    @test elscitype(cv) == Union{Missing,Multiclass{2}}

    # Arr{Any} --> Infinite
    v  = Any[1.0, 2.0, 5.3]
    cv = coerce(v, Continuous)
    @test elscitype(cv) == Continuous

    # CArr{Any} --> Infinite
    v  = categorical(Any[1.0, 2.0, 3.0])
    cv = coerce(v, Continuous)
    @test elscitype(cv) == Continuous

    ## Warnings
    v = Any['A', 1, 2]
    @test_logs (:warn,
        "Char value encountered, such value will be coerced according to the corresponding numeric value (e.g. 'A' to 65)."
        ) (cv = coerce(v, Count))
    @test cv == [65, 1, 2]
    @test elscitype(cv) == Count

    v = categorical(Any[1,2,3])
    @test_logs (:warn,
        "Trying to coerce from `Any` to `OrderedFactor` with categoricals.\nCoerced to `Union{Missing,OrderedFactor}` instead."
        ) (cv = coerce(v, OrderedFactor))
    @test elscitype(cv) == Union{Missing,OrderedFactor{3}}
end

@testset "Finite" begin
    # char / string
    char    = ['a','b','c']
    char_m  = [char..., missing]
    char_nm = char_m[1:end-1]
    str     = ["a", "b", "c"]
    str_m   = [str..., missing]
    str_nm  = str_m[1:end-1]
    # real
    int     = [1, 2, 3]
    int_m   = [int..., missing]
    int_nm  = int_m[1:end-1]
    fl      = [1.0,2.0,3.0]
    fl_m    = [fl..., missing]
    fl_nm   = fl_m[1:end-1]
    frac    = [1//2, 2//2, 3//4]
    frac_m  = [frac..., missing]
    frac_nm = frac_m[1:end-1]
    # any
    any_int    = Any[1,2,3]
    any_int_m  = Any[1,2,3,missing]
    any_int_nm = any_int_m[1:end-1]
    any_str    = Any["a","b","c"]
    any_str_m  = Any["a","b","c",missing]
    any_str_nm = any_str_m[1:end-1]
    # categorical
    cat_int    = categorical([1,2,3])
    cat_int_m  = categorical([1,2,3,missing])
    cat_int_nm = cat_int_m[1:end-1]
    cat_any    = categorical(Any[1,2,3])
    cat_any_m  = categorical(Any[1,2,3,missing])
    cat_any_nm = cat_int_m[1:end-1]

    for T in (Multiclass, OrderedFactor)
        # coercion without missing
        for ex in (char, int, fl, frac, cat_int)
            c = coerce(ex, T)
            @test elscitype(c) == T{3}
        end
        # coercion with missing or any
        for ex in (char_m, int_m, fl_m, frac_m,
                   any_int, any_int_m, any_str, any_str_m,
                   cat_int_m, cat_any, cat_any_m)
            c = coerce(ex, Union{Missing,T})
            @test elscitype(c) == Union{Missing,T{3}}
        end
        # coercion without true missing, tight=false
        for ex in (char_nm, str_nm, int_nm, fl_nm, frac_nm,
                   any_int_nm, any_str_nm, cat_int_nm, cat_any_nm)
            c = coerce(ex, Union{Missing,T})
            @test elscitype(c) == Union{Missing,T{3}}
        end
        #  coercion without true missing, tight=true
        for ex in (char_nm, str_nm, int_nm, fl_nm, frac_nm,
                   any_int_nm, any_str_nm, cat_int_nm, cat_any_nm)
            c = coerce(ex, T, tight=true)
            @test elscitype(c) == T{3}
        end
    end
end

@testset "Infinite" begin
    int     = [1, 2, 3]
    int_m   = [int..., missing]
    int_nm  = int_m[1:end-1]
    fl      = [1.0,2.0,3.0]
    fl_m    = [fl..., missing]
    fl_nm   = fl_m[1:end-1]
    frac    = [1//2, 2//2, 3//4]
    frac_m  = [frac..., missing]
    frac_nm = frac_m[1:end-1]
    # any
    any_int    = Any[1,2,3]
    any_int_m  = Any[1,2,3,missing]
    any_int_nm = any_int_m[1:end-1]
    # categorical
    cat_int    = categorical([1,2,3])
    cat_int_m  = categorical([1,2,3,missing])
    cat_int_nm = cat_int_m[1:end-1]
    cat_any    = categorical(Any[1,2,3])
    cat_any_m  = categorical(Any[1,2,3,missing])
    cat_any_nm = cat_int_m[1:end-1]

    ## COUNT

    # coercion without missing, note that with cat and any
    # int gets broadcasted
    for ex in (int, any_int, cat_int, cat_any)
        c = coerce(ex, Count)
        @test elscitype(c) == Count
    end
    # coercion with missing
    for ex in (int_m, any_int_m, cat_int_m, cat_any_m)
        c = coerce(ex, Union{Missing,Count})
        @test elscitype(c) == Union{Missing,Count}
    end
    # coercion without true missing and tight=false
    begin
        # Note that for any and categorical, the `int` is broadcasted
        c = coerce(int_nm, Union{Missing,Count})
        @test elscitype(c) == Union{Missing,Count}
        c = coerce(any_int_nm, Count) # broadcasted
        @test elscitype(c) == Count
        c = coerce(cat_int_nm, Count) # broadcasted
        @test elscitype(c) == Count
        c = coerce(cat_any_nm, Count) # broadcasted
        @test elscitype(c) == Count
    end
    # coercion without true missing and tight=true
    c = coerce(int_nm, Count, tight=true)
    @test elscitype(c) == Count

    ## CONTINUOUS

    # coercion without missing, similar story as for Count
    for ex in (int, fl, frac, any_int, cat_int, cat_any)
        c = coerce(ex, Continuous)
        @test elscitype(c) == Continuous
    end
    # coercion with missing
    for ex in (int_m, fl_m, frac_m, any_int_m, cat_int_m, cat_any_m)
        c = coerce(ex, Union{Missing,Continuous})
        @test elscitype(c) == Union{Missing,Continuous}
    end
    # coercion without true missing and tight=false
    # similar story as with Count
    begin
        for ex in (int_nm, fl_nm, frac_nm)
            c = coerce(ex, Union{Missing,Continuous})
            @test elscitype(c) == Union{Missing,Continuous}
        end
        for ex in (any_int_nm, cat_int_nm, cat_any_nm)
            c = coerce(ex, Continuous)
            @test elscitype(c) == Continuous
        end
    end
    # coercion without true missing and tight=true
    for ex in (int_nm, fl_nm, frac_nm)
        c = coerce(ex, Continuous, tight=true)
        @test elscitype(c) == Continuous
    end
end

struct FooSampleable <: Dist.Sampleable{Dist.ArrayLikeVariate{0},
                                        Dist.Discrete}
end

@testset "distributions" begin
    @test scitype(Dist.Normal()) == Density{Continuous}
    @test scitype(Dist.Poisson()) == Density{Count}
    @test scitype(Dist.Categorical(3)) == Density{Count}
    @test scitype(MultivariateNormal(2,1.0)) ==
        Density{AbstractVector{Continuous}}
    @test scitype(FooSampleable()) == Sampleable{Count}
end

@testset "text analysis" begin
    tagged_word = CorpusLoaders.PosTaggedWord("NN", "wheelbarrow")
    tagged_word2 = CorpusLoaders.PosTaggedWord("NN", "soil")
    @test scitype(tagged_word) == Annotated{Textual}
    bag_of_words = Dict("cat"=>1, "dog"=>3)
    @test scitype(bag_of_words) == Multiset{Textual}
    bag_of_tagged_words = Dict(tagged_word => 5)
    @test scitype(bag_of_tagged_words) == Multiset{Annotated{Textual}}
    @test scitype(Document("My Document", "kadsfkj")) == Unknown
    @test scitype(Document([tagged_word, tagged_word2])) ==
        Annotated{AbstractVector{Annotated{Textual}}}
    @test scitype(Document("My Other Doc", [tagged_word, tagged_word2])) ==
        Annotated{AbstractVector{Annotated{Textual}}}
    nested_tokens = [["dog", "cat"], ["bird", "cat"]]
    @test scitype(Document("Essay Number 1", nested_tokens)) ==
        Annotated{AbstractVector{AbstractVector{Textual}}}

    @test scitype(Dict(("cat", "in") => 3)) == Multiset{Tuple{Textual,Textual}}
    bag_of_words = Dict("cat in" => 1,
                        "the hat" => 1,
                        "the" => 2,
                        "cat" => 1,
                        "hat" => 1,
                        "in the" => 1,
                        "in" => 1,
                        "the cat" => 1)
    bag_of_ngrams =
        Dict(Tuple(String.(split(k))) => v for (k, v) in bag_of_words)
    # Dict{Tuple{String, Vararg{String, N} where N}, Int64} with 8 entries:
    #   ("cat",)       => 1
    #   ("cat", "in")  => 1
    #   ("in",)        => 1
    #   ("the", "hat") => 1
    #   ("the",)       => 2
    #   ("hat",)       => 1
    #   ("in", "the")  => 1
    #   ("the", "cat") => 1
    @test scitype(bag_of_ngrams) == Multiset{NTuple{<:Any,Textual}}

    @test scitype(Dict((tagged_word, tagged_word2) => 3)) ==
        Multiset{Tuple{Annotated{Textual},Annotated{Textual}}}
    bag_of_ngrams = Dict((tagged_word, tagged_word2) => 3,
                        (tagged_word,) => 7)
    @test scitype(bag_of_ngrams) == Multiset{NTuple{<:Any,Annotated{Textual}}}

end

@testset "Autotype+tight" begin
    x = [1,2,3,missing];
    x = x[1:3]
    y = randn(3)
    X = (x = x, y = y)
    d = autotype(X, :discrete_to_continuous)
    Xc = coerce(X, d)
    @test elscitype(Xc.x) == Union{Missing,Continuous}
    Xc = coerce(X, d, tight=true)
    @test elscitype(Xc.x) == Continuous
end

@testset "Extra tight" begin
    a = categorical(Any[1,2,3])
    # calls DataAPI.unwrap:
    c = coerce(a, Multiclass; tight=true)
    @test elscitype(c) == Multiclass{3}
end

@testset "Scitype/tight" begin
    x = [1,2,3,missing]
    @test elscitype(x) == Union{Missing,Count}
    @test elscitype(x[1:3]) == Union{Missing,Count}
    @test elscitype(x[1:3], tight=true) == Count

    df = DataFrame(X = [1,2,3,missing], Y = [1.0,2.0,3.0,missing])
    sch = schema(df)
    @test sch.scitypes[1] == Union{Missing,Count}
    @test sch.scitypes[2] == Union{Missing,Continuous}
    df2 = df[1:3,:]
    sch = schema(df2)
    @test sch.scitypes[1] == Union{Missing,Count}
    @test sch.scitypes[2] == Union{Missing,Continuous}
    sch = schema(df2, tight=true)
    @test sch.scitypes[1] == Count
    @test sch.scitypes[2] == Continuous
end
