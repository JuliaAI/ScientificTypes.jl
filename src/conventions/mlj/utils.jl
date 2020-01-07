function _coerce_missing_warn(::Type{T}, from::Type) where T
    T >: Missing && return
    if from == Any
        @warn "Trying to coerce from `Any` to `$T` with categoricals.\n" *
              "Coerced to Union{Missing,$T} instead."
    else
        @warn "Trying to coerce from `Union{Missing,$from}` to `$T`.\n" *
              "Coerced to Union{Missing,$T} instead."
    end
end

function _check_eltype(y, T, verb)
    E = eltype(y)
    E >: Missing && verb > 0 && _coerce_missing_warn(T, E)
end

function _check_tight(v::CArr, T, tight)
    if T >: Missing && tight && findfirst(ismissing, v) === nothing
        v = get.(v)
    end
    return v
end

function _check_tight(v::Arr, T, tight)
    if T >: Missing && tight && findfirst(ismissing, v) === nothing
        v = identity.(v)
    end
    return v
end
