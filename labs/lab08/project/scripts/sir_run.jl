using BenchmarkTools, Dates, CSV, DataFrames
struct DESModel
    N::Int      # Население
    I₀::Int     # Начальное число инфицированных
    β::Float64  # Коэффициент заражения
    γ::Float64  # Коэффициент выздоровления
end

function sir_model(des_model::DESModel, tmax::Float64)
    N = des_model.N
    β = des_model.β
    γ = des_model.γ
    I₀ = des_model.I₀

    history = Vector{Tuple{Float64, Float64, Float64, Float64}}()
    push!(history, (0.0, Float64(N - I₀), Float64(I₀), 0.0))

    S = Float64(N - I₀)
    I = Float64(I₀)
    R = 0.0
    t = 0.0

    while I > 0.1 && t < tmax
        new_infections = β * S * I / N
        S -= new_infections
        I += new_infections - γ * I
        R += γ * I
        t += 1.0

        push!(history, (t, S, I, R))
    end

    return history
end


function generate_filename(des_model::DESModel, tmax::Float64)
    timestamp = Dates.format(Dates.now(), "yyyy-mm-dd_HH-MM")
    return "sir_N$(des_model.N)_b$(des_model.β)_g$(des_model.γ)_t$(tmax)_$(timestamp).csv"
end

function save_to_csv(history, filename::String)
    df = DataFrame(history, [:time, :S, :I, :R])

    # Рекурсивное создание директории
    dir_path = "data/sims"
    if !isdir(dir_path)
        mkdir(dir_path)
    end

    # Сохранение в CSV
    CSV.write("$dir_path/$filename", df)
end

# Параметры модели
const des_model = DESModel(10_000, 10, 0.3, 0.1)
const tmax = 100.0

# Запуск модели и сохранение
println("Запуск модели SIR")
history = sir_model(des_model, tmax)
filename = generate_filename(des_model, tmax)
save_to_csv(history, filename)














