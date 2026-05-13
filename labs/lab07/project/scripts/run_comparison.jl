using DrWatson
@quickactivate

using DataFrames
using CSV
using Statistics
using Plots

include(srcdir("simulation2.jl"))  # просто подключаем функцию sim_repair

# параметры эксперимента
Ns = [5, 10, 15]
Ss = [2, 3, 5]
repairers_list = [1, 2, 3]

runs = 20

λ = 1/100
μ = 1.0

# гарантируем папки
mkpath(datadir("data"))
mkpath(plotsdir())

function safe_run(; N, S, R)

    times = Float64[]

    for i in 1:runs
        t = sim_repair(
            N=N,
            S=S,
            repairers=R,
            seed=100 + i,
            λ=λ,
            μ=μ
        )

        if isfinite(t)
            push!(times, t)
        end
    end

    return (
        mean_time = mean(times),
        std_time = std(times)
    )
end


results = DataFrame(
    N=Int[],
    S=Int[],
    R=Int[],
    mean_time=Float64[],
    std_time=Float64[]
)

for N in Ns, S in Ss, R in repairers_list
    println("Running N=$N S=$S R=$R")

    res = safe_run(N=N, S=S, R=R)

    push!(results, (
        N, S, R,
        res.mean_time,
        res.std_time
    ))
end

# ===== SAVE =====
CSV.write(datadir("data/ross_model.csv"), results)
@tagsave(datadir("data/ross_model.jld2"), @dict results)

println("Saved results.")

# ===== PLOT =====
gr()

p = plot()

for S in Ss
    sub = results[results.S .== S, :]
    sort!(sub, :R)

    plot!(sub.R, sub.mean_time,
        label="S=$S",
        marker=:o)
end

xlabel!("Repairers")
ylabel!("Mean crash time")
title!("Effect of repairers on system lifetime")

savefig(p, plotsdir("crash_time.png"))

println("Plot saved.")

