using Plots, BenchmarkTools, Dates, CSV, DataFrames

struct DESModel
    N::Int      # Население
    I₀::Int     # Начальное число инфицированных
    β::Float64  # Коэффициент заражения
    γ::Float64  # Коэффициент выздоровления
    μ::Float64  # Интенсивность смертности/рождений
end

function sir_demographic(des_model::DESModel, tmax::Float64)
    N = des_model.N
    β = des_model.β
    γ = des_model.γ
    μ = des_model.μ
    I₀ = des_model.I₀

    history = [(0.0, Float64(N - I₀), Float64(I₀), 0.0)]
    S, I, R = N - I₀, I₀, 0.0
    t = 0.0

    while t < tmax
        # Демографические события
        deaths = μ * (S + I + R) * 0.01
        births = μ * N * 0.01

        # Обновление состояний
        S -= β * S * I / N * 0.01
        I += β * S * I / N * 0.01 - γ * I * 0.01 - deaths * I / (S + I + R) * 0.01
        R += γ * I * 0.01 - deaths * R / (S + I + R) * 0.01

        # Учёт смертей и рождений
        S += births * 0.01
        S = max(S - deaths * S / (S + I + R) * 0.01, 0)
        I = max(I - deaths * I / (S + I + R) * 0.01, 0)
        R = max(R - deaths * R / (S + I + R) * 0.01, 0)

        t += 0.01
        push!(history, (t, max(S, 0), max(I, 0), max(R, 0)))
    end

    return history
end

function plot_and_save(history, des_model::DESModel, tmax::Float64)
    df = DataFrame(history, [:time, :S, :I, :R])

    # Создание графика
    p = plot(df.time, df.S, label="Восприимчивые (S)", linewidth=2, color=:blue,
             title="Модель SIR с демографией (μ = $(des_model.μ))", xlabel="Время",
             ylabel="Численность", legend=:topright, size=(800, 500))
    plot!(p, df.time, df.I, label="Инфицированные (I)", linewidth=2, color=:red)
    plot!(p, df.time, df.R, label="Выздоровевшие (R)", linewidth=2, color=:green)

    # Сохранение графика в PNG
    dir_path = "plots/sims_dem"
    if !isdir(dir_path)
        mkdir(dir_path)
    end

    timestamp = Dates.format(Dates.now(), "yyyy-mm-dd_HH-MM")
    filename = "sir_dem_N$(des_model.N)_b$(des_model.β)_g$(des_model.γ)_μ$(des_model.μ)_t$(tmax)_$(timestamp).png"
    savefig(p, "$dir_path/$filename")
    display(p)  
end

# Параметры модели
des_model = DESModel(10_000, 10, 0.3, 0.1, 0.005)  # μ = 0.005 (демографическая смертность)
tmax = 200.0

println("Запуск модели и визуализация")
history = sir_demographic(des_model, tmax)
plot_and_save(history, des_model, tmax)


