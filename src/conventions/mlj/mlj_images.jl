using .ColorTypes

scitype(::AbstractArray{<:Gray,2}, ::Val{:mlj}) = GrayImage
scitype(::AbstractArray{<:AbstractRGB,2}, ::Val{:mlj}) = ColorImage


