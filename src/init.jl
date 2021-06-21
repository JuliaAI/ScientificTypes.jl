function __init__()
    ScientificTypesBase.set_convention(DefaultConvention())
    ScientificTypesBase.TRAIT_FUNCTION_GIVEN_NAME[:table] = Tables.istable
end
