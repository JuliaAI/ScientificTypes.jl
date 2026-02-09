using Documenter, ScientificTypes
import ScientificTypesBase

const  REPO = Remotes.GitHub("JuliaAI", "ScientificTypes.jl")

makedocs(
    modules = [ScientificTypes, ScientificTypesBase],
    format=Documenter.HTML(
        prettyurls = true,
        collapselevel = 1,
    ),
    pages = [
        "Home" => "index.md",
        "Reference" => "reference.md",
    ],
    sitename = "ScientificTypes.jl",
    authors = "Anthony Blaom, Thibaut Lienart, and contributors.",
    warnonly = [:cross_references, :missing_docs],
    repo = REPO
)

deploydocs(
    devbranch="dev",
    push_preview=false,
    repo=REPO, #"github.com/JuliaAI/ScientificTypes.jl.git",
)
