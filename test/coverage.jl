@testset "coverage-misc" begin
    # finite.jl
    a = ["aa", "bb", "aa", "bb"] |> categorical
    @test S.nlevels(a[1]) == 2
    @test scitype(a[1]) == Multiclass{2}

    # mlj.jl
    @test S.Scitype(Int, M) == Count
    @test S.Scitype(Float32, M) == Continuous
    @test S.Scitype(SubString, M) == Textual

    # schema show
    df = DataFrame(x=[1.0,2.0,3.0],y=["a","b","c"])
    s = schema(df)
    io = IOBuffer()
    show(io, MIME("text/plain"), S.schema(df))
    @test String(take!(io)) == "_.table = \n┌─────────┬─────────┬────────────┐\n│ _.names │ _.types │ _.scitypes │\n├─────────┼─────────┼────────────┤\n│ x       │ Float64 │ Continuous │\n│ y       │ String  │ Textual    │\n└─────────┴─────────┴────────────┘\n_.nrows = 3\n"
end
