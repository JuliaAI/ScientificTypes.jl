srcdir = joinpath(@__DIR__(), "src")

# ENV["TRAVIS_REPO_SLUG"]="" #"alan-turing-institute/MLJ.jl"

using Literate
Literate.notebook(joinpath(srcdir, "index.jl"), srcdir)

# Literate.markdown(joinpath(srcdir, "index.jl"), srcdir,
#                    codefence = "```@repl scitypes" => "```")

# using Documenter
# using ScientificTypes

# makedocs(
#     sitename = "ScientificTypes",
#     format = Documenter.HTML(),
#     modules = [ScientificTypes],
#     pages = Any["ScientificTypes"=>"index.md"]
# )

# deploydocs(
#     repo = "github.com/alan-turing-institute/ScientificTypes.jl.git"
# )

