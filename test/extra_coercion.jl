@testset "issue #7" begin
    df = DataFrame(x=[1,2,3,4], y=["a","b","c","a"])
    coerce!(df, Textual=>Finite)
    @test scitype(df) == Table{Union{ AbstractArray{Count,1},
                                      AbstractArray{Multiclass{3},1} }}
end

# issue #9
@testset "Text=>Num" begin
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

    df = DataFrame(x=["1","2","3"], y=[2,3,4])
    coerce!(df, Textual=>Count)
    @test scitype(df) == Table{AbstractArray{Count,1}}
end
