function _coerce_missing_warn(::Type{T}) where T
    T == Any && @warn "Trying to coerce from `Any` type to $T.\n" *
                      "Coerced to Union{Missing,$T} instead."
    T >: Missing || @warn "Missing values encountered coercing scitype " *
                          "to $T.\nCoerced to Union{Missing,$T} instead."
end

function _check_eltype(y, T, verb)
    eltype(y) >: Missing && verb > 0 && _coerce_missing_warn(T)
end

function _check_tight(v, T, tight)
    if T >: Missing && tight && findfirst(ismissing, v) == nothing
        v = identity.(v)
    end
    return v
end
