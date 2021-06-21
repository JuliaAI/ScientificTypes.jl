using Documenter, ScientificTypes, ScientificTypesBase

makedocs(
    modules = [ScientificTypes, ScientificTypesBase],
    format = Documenter.HTML(
        prettyurls = !("local" in ARGS),
        ),
    sitename = "ScientificTypes.jl",
    authors = "Anthony Blaom, Thibaut Lienart, and contributors.",
    pages = [
        "Home" => "index.md",
    ]
)

deploydocs(
    repo = "github.com/JuliaAI/ScientificTypes.jl",
    push_preview = true
)
