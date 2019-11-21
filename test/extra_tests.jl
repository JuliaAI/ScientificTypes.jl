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
