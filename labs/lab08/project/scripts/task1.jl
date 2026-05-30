using DifferentialEquations, Plots, CSV, DataFrames


betas = [0.03, 0.05, 0.07]  # Варьируем β
c = 10.0                     # Контактная скорость
γ = 0.25                     # Скорость выздоровления


u0 = [990.0, 10.0, 0.0]      # S(0), I(0), R(0)

tspan = (0.0, 100.0)        # От 0 до 100 дней
tsteps = 1000                # Количество шагов


function sir_model(du, u, p, t)
    S, I, R = u
    β, c, γ = p
    du[1] = -β * c * S * I / 1000   # dS/dt
    du[2] = β * c * S * I / 1000 - γ * I  # dI/dt
    du[3] = γ * I                     
end


results = []  
metrics = []


for β in betas
    p = (β, c, γ)
    prob = ODEProblem(sir_model, u0, tspan, p)
    sol = solve(prob, Tsit5(), saveat=collect(range(tspan[1], tspan[2], length=tsteps)))

    # --- Вычисляем метрики ---
    max_I = maximum(sol[2, :])            
    time_max_I = sol.t[argmax(sol[2, :])]  
    final_R = sol[3, end]                  
    final_S = sol[1, end]               
    R0 = β * c / γ                       

    push!(metrics, Dict(
        "β" => β,
        "R0" => R0,
        "max_I" => max_I,
        "time_max_I" => time_max_I,
        "final_R" => final_R,
        "final_S" => final_S,
    ))


    df = DataFrame(
        Time = sol.t,
        S = sol[1, :],
        I = sol[2, :],
        R = sol[3, :],
        β = β,
    )
    push!(results, df)

    plot(sol, labels=["S" "I" "R"],
         title="SIR Model (β = $(β))",
         xlabel="Time (days)", ylabel="Population",
         linewidth=2, legend=:topright,
         backend=:png)  # Сохраняется в файл
    savefig("sir_beta_$(round(β, digits=2)).png")
end


CSV.write("sir_metrics.csv", metrics)
println("Метрики сохранены в sir_metrics.csv")


plot(layout=(1, length(betas)))
for (i, β) in enumerate(betas)
    plot!(results[i].Time, results[i].I,
          label="β = $(β)", linewidth=2, color=i)
end
title!("Peak Infections for Different β")
xlabel!("Time (days)")
ylabel!("Infected (I)")
savefig("sir_comparison.png")

 




