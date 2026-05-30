module SimulationModel
using StableRNGs
using Distributions
using ConcurrentSim
using DataFrames
using ResumableFunctions
export run_simulation
const rng = StableRNG(123)
@resumable function customer(
    env::Environment,
    server::Resource,
    id::Int,
    arrival_time::Float64,
    service_dist::Distribution,
    results::Vector
)

    @yield timeout(env, arrival_time)

    arrival = now(env)

    req = request(server)
    @yield req

    service_start = now(env)
    wait_time = service_start - arrival

    service_time = rand(rng, service_dist)

    @yield timeout(env, service_time)

    departure = now(env)

    @yield unlock(server)

    push!(results, (
        id = id,
        arrival = arrival,
        service_start = service_start,
        departure = departure,
        wait_time = wait_time,
        service_time = service_time,
        system_time = departure - arrival
    ))
end

function run_simulation(
    num_customers::Int,
    num_servers::Int,
    λ::Float64,
    μ::Float64
)

    sim = Simulation()

    server = Resource(sim, num_servers)

    arrival_dist = Exponential(1 / λ)
    service_dist = Exponential(1 / μ)

    results = []

    arrival_time = 0.0

    for i in 1:num_customers

        arrival_time += rand(rng, arrival_dist)

        @process customer(
            sim,
            server,
            i,
            arrival_time,
            service_dist,
            results
        )
    end

    run(sim)

    return DataFrame(results)
end
end
