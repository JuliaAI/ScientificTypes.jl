@testset "Coerce lazyarrays" begin
   X = Tables.table(ones(1_000, 2))
   tmp = tempname()
   CSV.write(tmp, X)

   data = CSV.read(tmp, threaded=true)

   # data.Column1 and data.Column2 are LazyArrays
   @test startswith("$(typeof(data.Column1))", "LazyArrays.")

   dc = coerce(data, autotype(data, :discrete_to_continuous))
   @test scitype(dc) == Table{AbstractArray{Continuous,1}}

   rm(tmp)
end

@testset "In place coercion" begin
   df = DataFrame((x=ones(Int,5), y=ones(5)))
   @test scitype(df) == Table{Union{AbstractArray{Continuous,1}, AbstractArray{Count,1}}}
   coerce!(df, :x=>Continuous)
   @test scitype(df) == Table{AbstractArray{Continuous,1}}

   df = DataFrame((
         x=ones(Int, 50),
         y=ones(50),
         z=collect("abbabaacbcabbabaacbbcccbccbbabaaacacbcabcbccaabaaa")
         ))
   @test scitype(df) == Table{Union{AbstractArray{Continuous,1}, AbstractArray{Count,1}, AbstractArray{Unknown,1}}}

   coerce!(df, autotype(df, :few_to_finite))
   @test scitype(df) == Table{Union{AbstractArray{Multiclass{3},1}, AbstractArray{OrderedFactor{1},1}}}

   @test_throws ArgumentError coerce!(randn(5, 5))
end
