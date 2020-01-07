# this overlaps with other tests it's aim is more to a list of mappings
# and exemplify the behaviour in a wide range of cases.

@testset "(MLJ)->Finite" begin
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

@testset "(MLJ)->Infinite" begin
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
    # calls get.
    c = coerce(a, Multiclass; tight=true)
    @test elscitype(c) == Multiclass{3}
end
