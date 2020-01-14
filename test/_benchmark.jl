# Last run: 7/1/2020

using ScientificTypes, DataFrames, Random

function foo()
    r = rand()
    r < 0.2 && return "AAA"
    r < 0.4 && return "BBB"
    r < 0.6 && return "CCC"
    r < 0.8 && return "DDD"
    return "EEE"
end

Random.seed!(5161)
v1 = [foo() for i in 1:1_000_000];
v2 = [foo() for i in 1:1_000_000];
df = DataFrame((x1=v1,x2=v2));

using BenchmarkTools
using CategoricalArrays

@btime categorical($v1); # 28.495 ms (1000046 allocations: 34.34 MiB)
@btime coerce($v1, Multiclass);
#this branch ==> 28.755 ms (1000046 allocations: 34.34 MiB)
#master      ==> 46.380 ms (1000080 allocations: 31.48 MiB)

function foo()
    r = rand()
    r < 0.2 && return "AAA"
    r < 0.4 && return "BBB"
    r < 0.6 && return "CCC"
    r < 0.8 && return "DDD"
    return missing
end

Random.seed!(51261)
v2 = [foo() for i in 1:1_000_000];

@btime categorical($v2); # 25.051 ms (799786 allocations: 28.22 MiB)
@btime coerce($v2, Union{Missing,Multiclass});
#this branch ==> 25.712 ms (799787 allocations: 28.22 MiB)
#master      ==> 139.152 ms (1599678 allocations: 51.69 MiB)

using Random, Distributions

n = 1_115_000
Random.seed!(51611)
df  = DataFrame(
        rs  = rand(["A", "B", "C", "D", "E", "F", "G"], n),
        es  = rand(["1","3","5","7","8","9"], n),
        inc = rand([collect(5000:15000); [missing for _ ∈ 1:50]], n),
        gr  = rand([randstring(6) for _ in 1:400], n),
        year = rand(2012:2017, n),
        lt = rand([12, 24, 36, 48, 60, 72], n),
        pb = Int.(round.(rand(LogNormal(8.07, 1.116), n))),
        cb = rand(LogNormal(7.88, 1.288), n),
        ci = rand(0.03:0.01:0.17, n),
        db = rand([repeat(collect(1945:2000),100); missing], n),
        ms = rand(["1", "2", "NA"], n),
        ho = BitArray(rand([true, false], n)),
        el = Int.(round.(rand(LogNormal(1.0, 0.72), n))),
        fl = rand(n),
        ft = rand(n),
        ea = BitArray(rand([true, false], n))
        );

@btime schema($df);
#this branch ==> 296.510 μs (140 allocations: 10.78 KiB)
#master      ==> 270.863 μs (140 allocations: 10.78 KiB)

@btime coerce($df, autotype($df, :few_to_finite));
#this branch ==> 979.098 ms (11152394 allocations: 636.62 MiB)
#master      ==> 1.415 s (12273798 allocations: 609.21 MiB)
