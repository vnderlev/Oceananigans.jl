module Oceananigans

if VERSION < v"1.5"
    error("This version of Oceananigans.jl requires Julia v1.5 or newer.")
end

export
    # Architectures
    CPU, GPU,

    # Logging
    OceananigansLogger,

    # Grids
    Center, Face,
    Periodic, Bounded, Flat,
    RegularRectilinearGrid, VerticallyStretchedRectilinearGrid, RegularLatitudeLongitudeGrid,
    xnodes, ynodes, znodes, nodes,

    # Advection schemes
    CenteredSecondOrder, CenteredFourthOrder, UpwindBiasedThirdOrder, UpwindBiasedFifthOrder, WENO5,

    # Boundary conditions
    BoundaryCondition,
    Flux, Value, Gradient, NormalFlow,
    FluxBoundaryCondition, ValueBoundaryCondition, GradientBoundaryCondition,
    CoordinateBoundaryConditions, FieldBoundaryConditions,
    UVelocityBoundaryConditions, VVelocityBoundaryConditions, WVelocityBoundaryConditions,
    TracerBoundaryConditions, PressureBoundaryConditions,

    # Fields and field manipulation
    Field, CenterField, XFaceField, YFaceField, ZFaceField,
    AveragedField, ComputedField, KernelComputedField, BackgroundField,
    interior, interiorparent, set!, compute!,

    # Forcing functions
    Forcing, Relaxation, LinearTarget, GaussianMask,

    # Coriolis forces
    FPlane, BetaPlane, NonTraditionalFPlane, NonTraditionalBetaPlane,

    # Buoyancy and equations of state
    BuoyancyTracer, SeawaterBuoyancy,
    LinearEquationOfState, RoquetIdealizedNonlinearEquationOfState, TEOS10,

    # Surface wave Stokes drift via Craik-Leibovich equations
    UniformStokesDrift,

    # Turbulence closures
    IsotropicDiffusivity, AnisotropicDiffusivity,
    AnisotropicBiharmonicDiffusivity,
    ConstantSmagorinsky, AnisotropicMinimumDissipation,

    # Lagrangian particle tracking
    LagrangianParticles,

    # Models
    IncompressibleModel, NonDimensionalIncompressibleModel, HydrostaticFreeSurfaceModel, fields,

    # Time stepping
    Clock, TimeStepWizard, time_step!,

    # Simulations
    Simulation, run!,
    iteration_limit_exceeded, stop_time_exceeded, wall_time_limit_exceeded,

    # Diagnostics
    NaNChecker, FieldMaximum,
    CFL, AdvectiveCFL, DiffusiveCFL,

    # Output writers
    FieldSlicer, NetCDFOutputWriter, JLD2OutputWriter, Checkpointer,
    TimeInterval, IterationInterval, AveragedTimeInterval,

    # Abstract operations
    ∂x, ∂y, ∂z, @at,

    # Utils
    prettytime


using Printf
using Logging
using Statistics
using LinearAlgebra

using CUDA
using Adapt
using OffsetArrays
using FFTW
using JLD2
using NCDatasets

using Base: @propagate_inbounds
using Statistics: mean

import Base:
    +, -, *, /,
    size, length, eltype,
    iterate, similar, show,
    getindex, lastindex, setindex!,
    push!

#####
##### Abstract types
#####

"""
    AbstractModel

Abstract supertype for models.
"""
abstract type AbstractModel{TS} end

"""
    AbstractDiagnostic

Abstract supertype for diagnostics that compute information from the current
model state.
"""
abstract type AbstractDiagnostic end

"""
    AbstractOutputWriter

Abstract supertype for output writers that write data to disk.
"""
abstract type AbstractOutputWriter end

#####
##### Place-holder functions
#####

function run_diagnostic! end
function write_output! end
function location end
function instantiated_location end
function tupleit end
function short_show end

function fields end

#####
##### Include all the submodules
#####

include("Architectures.jl")
include("Units.jl")
include("Grids/Grids.jl")
include("Utils/Utils.jl")
include("Logger.jl")
include("Operators/Operators.jl")
include("Advection/Advection.jl")
include("BoundaryConditions/BoundaryConditions.jl")
include("Fields/Fields.jl")
include("Coriolis/Coriolis.jl")
include("Buoyancy/Buoyancy.jl")
include("StokesDrift.jl")
include("TurbulenceClosures/TurbulenceClosures.jl")
include("LagrangianParticleTracking/LagrangianParticleTracking.jl")
include("Solvers/Solvers.jl")
include("Forcings/Forcings.jl")
include("TimeSteppers/TimeSteppers.jl")
include("Models/Models.jl")
include("Diagnostics/Diagnostics.jl")
include("OutputWriters/OutputWriters.jl")
include("Simulations/Simulations.jl")
include("AbstractOperations/AbstractOperations.jl")
include("Distributed/Distributed.jl")

#####
##### Needed so we can export names from sub-modules at the top-level
#####

using .Logger
using .Architectures
using .Utils
using .Advection
using .Grids
using .BoundaryConditions
using .Fields
using .Coriolis
using .Buoyancy
using .StokesDrift
using .TurbulenceClosures
using .LagrangianParticleTracking
using .Solvers
using .Forcings
using .Models
using .TimeSteppers
using .Diagnostics
using .OutputWriters
using .Simulations
using .AbstractOperations
using .Distributed

function __init__()
    threads = Threads.nthreads()
    if threads > 1
        @info "Oceananigans will use $threads threads"

        # See: https://github.com/CliMA/Oceananigans.jl/issues/1113
        FFTW.set_num_threads(4*threads)
    end

    @hascuda begin
        @debug "CUDA-enabled GPU(s) detected:"
        for (gpu, dev) in enumerate(CUDA.devices())
            @debug "$dev: $(CUDA.name(dev))"
        end

        CUDA.allowscalar(false)
    end
end

end # module
