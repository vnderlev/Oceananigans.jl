"""
    StretchedRectilinearGrid{FT, TX, TY, TZ, R, A} <: AbstractRectilinearGrid{FT, TX, TY, TZ}
A rectilinear grid that allows for a stretched spacing in any or all of the three directions `Δz`, `Δy` and `Δz`, 
topology `{TX, TY, TZ}`, and coordinate ranges of type `X`, `Y` and `Z` in each direction (where a range can be used).
The grid spacings are of type `DX`, `DY` and `DZ` in each direction, respectively.  
This allows for `Flat` in any direction and can generate the same grids from 
regular_rectilinear_grid.jl and vertially_stretched_rectilinear_grid.jl.
"""

struct StretchedRectilinearGrid{FT, TX, TY, TZ, X, Y, Z, DX, DY, DZ, Arch} <: AbstractRectilinearGrid{FT, TX, TY, TZ}

    architecture :: Arch

    # Number of grid points in (x,y,z).
    Nx :: Int
    Ny :: Int
    Nz :: Int

    # Halo size in (x,y,z).
    Hx :: Int
    Hy :: Int
    Hz :: Int

    # Domain size [m].
    Lx :: FT
    Ly :: FT
    Lz :: FT

   # Range of coordinates at the centers of the cells.
    xᶜᵃᵃ :: X
    yᵃᶜᵃ :: Y
    zᵃᵃᶜ :: Z

    # Range of grid coordinates at the faces of the cells.
    xᶠᵃᵃ :: X
    yᵃᶠᵃ :: Y
    zᵃᵃᶠ :: Z

    # Grid spacing [m].
    Δxᶜᵃᵃ :: DX
    Δxᶠᵃᵃ :: DX
    Δyᵃᶜᵃ :: DY
    Δyᵃᶠᵃ :: DY
    Δzᵃᵃᶜ :: DZ
    Δzᵃᵃᶠ :: DZ
end

function generate_stretched_grid(FT, x_topo, Nx, Hx, x_faces)

    # Ensure correct type for xF and derived quantities
    interior_xF = zeros(FT, Nx+1)

    for i = 1:Nx+1
        interior_xF[i] = get_x_face(x_faces, i)
    end

    Lx = interior_xF[Nx+1] - interior_xF[1]

    # Build halo regions
    ΔxF₋ = lower_exterior_Δxᵃᵃᶜ(x_topo, interior_xF, Hx)
    ΔxF₊ = lower_exterior_Δxᵃᵃᶜ(x_topo, interior_xF, Hx)

    x¹, xᴺ⁺¹ = interior_xF[1], interior_xF[Nx+1]

    xF₋ = [x¹   - sum(ΔxF₋[i:Hx]) for i = 1:Hx] # locations of faces in lower halo
    xF₊ = [xᴺ⁺¹ + ΔxF₊[i]         for i = 1:Hx] # locations of faces in width of top halo region

    xF = vcat(xF₋, interior_xF, xF₊)

    # Build cell centers, cell center spacings, and cell interface spacings
    TCx = total_length(Center, x_topo, Nx, Hx)
     xC = [ (xF[i + 1] + xF[i]) / 2 for i = 1:TCx ]
    ΔxC = [  xC[i] - zC[i - 1]      for i = 2:TCx ]

    # Trim face locations for periodic domains
    TFx = total_length(Face, x_topo, Nx, Hx)
    xF = xF[1:TFx]

    ΔxF = [xF[i + 1] - xF[i] for i = 1:TFx-1]

    return Lx, xF, xC, ΔxF, ΔxC
end

get_x_face(x::Function, i) = x(i)
get_x_face(x::AbstractVector, i) = x[i]

lower_exterior_Δxᵃᵃᶜ(x_topo,          xFi, Hx) = [xFi[end - Hx + i] - xFi[end - Hx + i - 1] for i = 1:Hx]
lower_exterior_Δxᵃᵃᶜ(::Type{Bounded}, xFi, Hx) = [xFi[2]  - xFi[1] for i = 1:Hx]

# FJP: How to deal with periodic domains? Depends on how halos are extended
#generate_grid(FT, ::Type{Flat}, Lx, x, N, H, stretch) = 0., 0., 1, 0

#function generate_grid(FT, topo, L, x, N, H, stretch)
function generate_grid(FT, x_topo, Nx, Hx, x_faces)

    interior_xᶠ = zeros(FT, Nx+1)

    for i = 1:Nx+1
        interior_xᶠ[i] = get_x_face(x_faces, i)
    end

    Lx = interior_xᶠ[Nx+1] - interior_xᶠ[1]

    # Build halo regions
    Δxᶠ⁻ = lower_exterior_Δxᵃᵃᶜ(x_topo, interior_xᶠ, Hx)
    Δxᶠ⁺ = lower_exterior_Δxᵃᵃᶜ(x_topo, interior_xᶠ, Hx)

    Txᶠ = total_length(Face,   topo, N, H) 
    Txᶜ = total_length(Center, topo, N, H)

    #interior_xᶠ = stretch(x[1], L, N) 

    Δxᶠ₋ = interior_xᶠ[2]   - interior_xᶠ[1]
    Δxᶠ₊ = interior_xᶠ[end] - interior_xᶠ[end-1]

    xᶠ₋ = [interior_xᶠ[1]   - sum(Δxᶠ₋[i:Hx]) for i=1:Hx]
    xᶠ₊ = [interior_xᶠ[end] + Δxᶠ₊[i]         for i=1:Hx]

     xᶠ = OffsetArray(vcat(xᶠ₋, interior_xᶠ, xᶠ₊),                       -H)
     xᶜ = OffsetArray([(xᶠ[i + 1] + xᶠ[i]) / 2 for i = (1-H):(Txᶜ-H)],   -H)
    Δxᶜ = OffsetArray([xᶜ[i]     - xᶜ[i - 1]   for i = (2-H):(Txᶜ-H)],   -H)
    Δxᶠ = OffsetArray([xᶠ[i+1]   - xᶠ[i]       for i = (1-H):(Txᶠ-1-H)], -H)

   return xᶜ, xᶠ, Δxᶜ, Δxᶠ
end

function StretchedRectilinearGrid(FT=Float64; 
                                architecture = CPU(),
                                size, 
                                x = nothing, 
                                y = nothing, 
                                z = nothing,
                                extent = nothing,
                                topology = (Bounded, Periodic, Flat),
                                halo = nothing,
                                stretch = nothing)

    TX, TY, TZ = validate_topology(topology)
    size = validate_size(TX, TY, TZ, size)
    halo = validate_halo(TX, TY, TZ, halo)
    Lx, Ly, Lz, x, y, z = validate_stretched_grid(TX, TY, TZ, FT, extent, x, y, z)

    Nx, Ny, Nz = size
    Hx, Hy, Hz  = halo
    L = (Lx, Ly, Lz)

    # What if stretch is nothing????  set default to linear
    #FJP: mimic generate_stretched_vertical_grid
    xᶜᵃᵃ, xᶠᵃᵃ, Δxᶜᵃᵃ, Δxᶠᵃᵃ = generate_grid(FT, topology[1], Lx, x, Nx, Hx, stretch["x"])
    yᵃᶜᵃ, yᵃᶠᵃ, Δyᵃᶜᵃ, Δyᵃᶠᵃ = generate_grid(FT, topology[2], Ly, y, Ny, Hy, stretch["y"])
    zᵃᵃᶜ, zᵃᵃᶠ, Δzᵃᵃᶜ, Δzᵃᵃᶠ = generate_grid(FT, topology[3], Lz, z, Nz, Hz, stretch["z"])

    Arch = typeof(architecture)

    return StretchedRectilinearGrid{FT, TX, TY, TZ, 
        typeof(xᶜᵃᵃ),  typeof(yᵃᶜᵃ),  typeof(zᵃᵃᶜ), 
        typeof(Δxᶜᵃᵃ), typeof(Δyᵃᶜᵃ), typeof(Δzᵃᵃᶜ), Arch}(
        architecture, Nx, Ny, Nz, Hx, Hy, Hz, Lx, Ly, Lz, 
        xᶜᵃᵃ, yᵃᶜᵃ, zᵃᵃᶜ, xᶠᵃᵃ, yᵃᶠᵃ, zᵃᵃᶠ, 
        Δxᶜᵃᵃ, Δxᶠᵃᵃ, Δyᵃᶜᵃ, Δyᵃᶠᵃ, Δzᵃᵃᶜ, Δzᵃᵃᶠ)
end

function Base.show(io::IO, grid::StretchedRectilinearGrid{FT, TX, TY, TZ}) where {FT, TX, TY, TZ}
    Δx_min, Δx_max = minimum(grid.Δxᶜᵃᵃ), maximum(grid.Δxᶜᵃᵃ)
    Δy_min, Δy_max = minimum(grid.Δyᵃᶜᵃ), maximum(grid.Δyᵃᶜᵃ)
    Δz_min, Δz_max = minimum(grid.Δzᵃᵃᶜ), maximum(grid.Δzᵃᵃᶜ)
 
    print(io, "\nStretchedRectilinearGrid{$FT, $TX, $TY, $TZ}\n",
              "               domain: (Lx=$(grid.Lx),        Ly=$(grid.Ly),      Lz=$(grid.Lz))\n",
              "           resolution: (Nx=$(grid.Nx),          Ny=$(grid.Ny),        Nz=$(grid.Nz))\n",
              "            halo size: (Hx=$(grid.Hx),          Hy=$(grid.Hy),        Hz=$(grid.Hz))\n",
              "         grid spacing: (minΔx=$(Δx_min),   minΔy=$(Δy_min),   minΔz=$(Δz_min))\n",
              "                       maxΔx=$(Δx_max),   maxΔy=$(Δy_max),   maxΔz=$(Δz_max))\n\n   ")
end

# We cannot reconstruct a StretchedRectilinearGrid without the zF_generator.
# So the best we can do is tell the user what they should have done.
function with_halo(new_halo, old_grid::StretchedRectilinearGrid)
    new_halo != halo_size(old_grid) &&
        @error "You need to construct your StretchedRectilinearGrid with the keyword argument halo=$new_halo"
    return old_grid
end

short_show(grid::StretchedRectilinearGrid{FT, TX, TY, TZ}) where {FT, TX, TY, TZ} =
    "StretchedRectilinearGrid{$FT, $TX, $TY, $TZ}(Nx=$(grid.Nx), Ny=$(grid.Ny), Nz=$(grid.Nz))"

@inline xnode(::Type{Center}, i, grid::StretchedRectilinearGrid) = @inbounds grid.xᶜᵃᵃ[i]
@inline xnode(::Type{Face},   i, grid::StretchedRectilinearGrid) = @inbounds grid.xᶠᵃᵃ[i]
@inline ynode(::Type{Center}, j, grid::StretchedRectilinearGrid) = @inbounds grid.yᵃᶜᵃ[j]
@inline ynode(::Type{Face},   j, grid::StretchedRectilinearGrid) = @inbounds grid.yᵃᶠᵃ[j]
@inline znode(::Type{Center}, k, grid::StretchedRectilinearGrid) = @inbounds grid.zᵃᵃᶜ[k]
@inline znode(::Type{Face},   k, grid::StretchedRectilinearGrid) = @inbounds grid.zᵃᵃᶠ[k]
all_x_nodes(::Type{Center},      grid::StretchedRectilinearGrid) = grid.xᶜᵃᵃ
all_x_nodes(::Type{Face},        grid::StretchedRectilinearGrid) = grid.xᶠᵃᵃ
all_y_nodes(::Type{Center},      grid::StretchedRectilinearGrid) = grid.yᵃᶜᵃ
all_y_nodes(::Type{Face},        grid::StretchedRectilinearGrid) = grid.yᵃᶠᵃ
all_z_nodes(::Type{Center},      grid::StretchedRectilinearGrid) = grid.zᵃᵃᶜ
all_z_nodes(::Type{Face},        grid::StretchedRectilinearGrid) = grid.zᵃᵃᶠ
