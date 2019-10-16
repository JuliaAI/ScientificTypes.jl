using .ColorTypes

scitype(image::AbstractArray{<:Gray,2}, ::Val{:mlj}) =
    GrayImage{size(image)...}
scitype(image::AbstractArray{<:AbstractRGB,2}, ::Val{:mlj}) =
    ColorImage{size(image)...}
