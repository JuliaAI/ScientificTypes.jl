# Basic scitype

ST.scitype(::Integer,        ::DefaultConvention) = Count
ST.scitype(::AbstractFloat,  ::DefaultConvention) = Continuous
ST.scitype(::AbstractString, ::DefaultConvention) = Textual
ST.scitype(::TimeType,       ::DefaultConvention) = ScientificTimeType
ST.scitype(::Time    ,       ::DefaultConvention) = ScientificTime
ST.scitype(::Date,           ::DefaultConvention) = ScientificDate
ST.scitype(::DateTime,       ::DefaultConvention) = ScientificDateTime

ST.scitype(img::Arr{<:Gray,2}, ::DefaultConvention) = GrayImage{size(img)...}
ST.scitype(img::Arr{<:AbstractRGB,2}, ::DefaultConvention) =
ColorImage{size(img)...}

ST.scitype(::PersistenceDiagram, ::DefaultConvention) = PersistenceDiagram

# CategoricalArray scitype

function ST.scitype(c::Cat, ::DefaultConvention)
    nc = length(levels(c.pool))
    return ifelse(c.pool.ordered, OrderedFactor{nc}, Multiclass{nc})
end

const CatArrOrSub{T,N} =
    Union{CategoricalArray{T,N},SubArray{<:Any,<:Any,<:CategoricalArray{T,N}}}
#=
function ST.scitype(A::CatArrOrSub{T,N}, ::DefaultConvention; kw...) where {T,N}
    nlevels = length(levels(A))
    S = ifelse(isordered(A), OrderedFactor{nlevels}, Multiclass{nlevels})
    kwargs = values(kw)
    #tight = haskey(kwargs, :tight) ? Val{kwargs[:tight]}() : Val{false}()
    #_S = _tighten_type_if_needed(A, T, S; tight = tight)
    return AbstractArray{S, N}
end
=#
function ST.scitype(A::CatArrOrSub{T,N}, ::DefaultConvention; kw...) where {T,N}
    nlevels = length(levels(A))
    S = ifelse(isordered(A), OrderedFactor{nlevels}, Multiclass{nlevels})
    _S = _tighten_type_if_needed(A, T, S; kw...)
    return AbstractArray{_S, N}
end

# Table scitype

function ST.scitype(X, ::DefaultConvention, ::Val{:table}; kw...)
    Xcol = Tables.columns(X)
    col_names = Tables.columnnames(Xcol)
    types = map(col_names) do name
        scitype(Tables.getcolumn(Xcol, name); kw...)
    end
    return Table{Union{types...}}
end

# Scitype for fast array broadcasting

ST.Scitype(::Type{<:Integer},            ::DefaultConvention) = Count
ST.Scitype(::Type{<:AbstractFloat},      ::DefaultConvention) = Continuous
ST.Scitype(::Type{<:AbstractString},     ::DefaultConvention) = Textual
ST.Scitype(::Type{<:TimeType},           ::DefaultConvention) = ScientificTimeType
ST.Scitype(::Type{<:Date},               ::DefaultConvention) = ScientificDate
ST.Scitype(::Type{<:Time},               ::DefaultConvention) = ScientificTime
ST.Scitype(::Type{<:DateTime},           ::DefaultConvention) = ScientificDateTime
ST.Scitype(::Type{<:PersistenceDiagram}, ::DefaultConvention) = PersistenceDiagram
