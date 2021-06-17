if VERSION ≥ v"1.3.0-"
   @testset "Coerce Col2" begin
      X = Tables.table(ones(1_000, 2))
      tmp = tempname()
      CSV.write(tmp, X)
      data = CSV.read(tmp, DataFrame)
      # data.Column1 and data.Column2 are Column2 (as of CSV 5.19)
      @test data.Column1 isa AbstractArray{<:AbstractFloat}
      dc = coerce(data, autotype(data, :discrete_to_continuous))
      @test scitype(dc) == Table{AbstractArray{Continuous,1}}
      rm(tmp)
   end
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
   @test_throws ArgumentError coerce!(df, Count())
   @test_throws ArgumentError coerce!(df, Dict(:x=>Count(), :y=>Multiclass))
   @test_throws ArgumentError coerce!(df, :x=>Count(), :y=>Multiclass)
end
