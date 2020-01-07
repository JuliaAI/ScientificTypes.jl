function _coerce_missing_warn(::Type{T}) where T
    T >: Missing || @warn "Missing values encountered coercing scitype " *
                          "to $T.\nCoerced to Union{Missing,$T} instead."
end

function _check_eltype(y, T, verb)
    eltype(y) >: Missing && verb > 0 && _coerce_missing_warn(T)
end
