using Documenter, ScientificTypes

makedocs(
    modules = [ScientificTypes],
    format = Documenter.HTML(
        prettyurls = !("local" in ARGS),
        # assets = ["assets/custom.css"]
        ),
    sitename = "ScientificTypes.jl",
    authors = "Anthony Blaom, Thibaut Lienart, and contributors.",
    pages = [
        "Home" => "index.md",
        # "Manual" => [
        # ],
        # "Library" => [
        # ],
    ]
)

deploydocs(
    repo = "github.com/alan-turing-institute/ScientificTypes.jl"
)
