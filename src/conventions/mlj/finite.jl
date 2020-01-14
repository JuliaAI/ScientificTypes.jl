#=
Functionalities to coerce to T <: Union{Missing,<:Finite}
=#

# Arr{T} -> Finite
function coerce(v::Arr{T}, ::Type{T2};
                verbosity::Int=1, tight::Bool=false
                ) where T where T2 <: Union{Missing,Finite}
    v    = _check_tight(v, T, tight)
    vcat = categorical(v, ordered=nonmissing(T2)<:OrderedFactor)
    return _finalize_finite_coerce(vcat, verbosity, T2, T)
end

# CArr{T} -> Finite
function coerce(v::CArr{T}, ::Type{T2};
                verbosity::Int=1, tight::Bool=false
                ) where T where T2 <: Union{Missing,Finite}
    v = _check_tight(v, T, tight)
    return _finalize_finite_coerce(v, verbosity, T2, T)
end

# v is already categorical here, but may need `ordering` changed
function _finalize_finite_coerce(v, verbosity, T, fromT)
    elst = elscitype(v)
    if (elst >: Missing) && !(T >: Missing)
        verbosity > 0 && _coerce_missing_warn(T, fromT)
    end
    if elst <: T
        return v
    end
    return categorical(v, ordered=nonmissing(T)<:OrderedFactor)
end
