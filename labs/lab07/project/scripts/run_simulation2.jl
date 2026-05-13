using DrWatson

@quickactivate "project"

include(srcdir("simulation2.jl"))

const RUNS = 10

results = Float64[]

for i in 1:RUNS
    result = sim_repair(
        N = 10,
        S = 3,
        λ = 100.0,
        μ = 1.0,
        repairers = 1
    )

    push!(results, result.crash_time)
end

println("Average crash time = ", mean(results))
