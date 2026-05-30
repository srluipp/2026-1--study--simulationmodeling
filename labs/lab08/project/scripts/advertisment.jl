using DifferentialEquations
using Plots


N = 1150         
n0 = 12           


function equation2!(du, u, p, t)
    du[1] = 0.000076 + 0.76 * (N - u[1])
end


tspan = (0.0, 200.0)
u0 = [n0]


prob2 = ODEProblem(equation2!, u0, tspan)
sol2 = solve(prob2, Tsit5())


p = plot(
    sol2.t, sol2[1, :],
    label = "Количество людей, знающих о товаре (уравнение 2)",
    xlabel = "Время",
    ylabel = "Количество",
    legend = :topright,
    title = "Распространение рекламы (Уравнение 2)",
    grid = true,
    linewidth = 2,
    dpi = 300
)


speed_vals = [0.000076 + 0.76 * (N - u_val) for u_val in sol2[1, :]]
max_speed_idx = argmax(speed_vals)
max_speed_value = speed_vals[max_speed_idx]
max_speed_time = sol2.t[max_speed_idx]

println("Максимальная скорость распространения рекламы: ", round(max_speed_value, digits=6))
println("Достигается в момент времени: ", round(max_speed_time, digits=2), " ед. времени")

plot_dir = "plots"
isdir(plot_dir) || mkpath(plot_dir)

savefig(p, joinpath(plot_dir, "advertisement_plot.png"))
println("График сохранён в: ", joinpath(plot_dir, "advertisement_plot.png"))

