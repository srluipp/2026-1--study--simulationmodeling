using ConcurrentSim
using Distributions
using Plots
using DataFrames
using CSV

# Тип агента: S (восприимчивый), I (инфицированный), R (выздоровевший), D (умерший)
@enum AgentStatus S I R D

mutable struct SIRPerson
    id::Int64
    status::AgentStatus
    infection_time::Float64
end

mutable struct SIRModel
    sim::ConcurrentSim.Simulation
    β::Float64         # Коэффициент заражения
    c::Float64         # Скорость контактов
    γ::Float64         # Скорость выздоровления
    μ::Float64         # Интенсивность смертности
    ta::Vector{Float64}
    Sa::Vector{Int64}
    Ia::Vector{Int64}
    Ra::Vector{Int64}
    Da::Vector{Int64}
    allIndividuals::Vector{SIRPerson}

    # Параметры вакцинации
    vaccination_time::Union{Float64, Nothing}   # Время начала вакцинации (или `null`)
    vaccination_threshold::Union{Int64, Nothing} # Порог инфицированных (или `null`)
    vaccination_fraction::Float64              # Доля вакцинируемых от восприимчивых
end

function MakeSIRModel(
    u0::NamedTuple{S,I,R},
    p::NamedTuple{β,c,γ,μ};
    vaccination_time::Union{Float64,Nothing}=nothing,
    vaccination_threshold::Union{Int64,Nothing}=nothing,
    vaccination_fraction::Float64=0.0,
)
    N = u0.S + u0.I + u0.R
    sim = ConcurrentSim.Simulation()
    allIndividuals = Vector{SIRPerson}()

    # Инициализация агентов
    for id in 1:N
        if id ≤ u0.S
            push!(allIndividuals, SIRPerson(id, S, 0.0))
        elseif id ≤ u0.S + u0.I
            push!(allIndividuals, SIRPerson(id, I, 0.0))
        else
            push!(allIndividuals, SIRPerson(id, R, 0.0))
        end
    end

    m = SIRModel(
        sim,
        p.β, p.c, p.γ, p.μ,
        [0.0], [u0.S], [u0.I], [u0.R], [0],
        allIndividuals,
        vaccination_time, vaccination_threshold, vaccination_fraction
    )

    return m
end

function out(m::SIRModel)
    return (t=m.ta, S=m.Sa, I=m.Ia, R=m.Ra, D=m.Da)
end

@resumable function live(env::ConcurrentSim.Simulation, individual::SIRPerson, m::SIRModel)
    current_status = individual.status
    infection_time = individual.infection_time

    while true
        # Проверка вакцинации
        vaccinate!(m, individual)

        if current_status == S
            # Время до заражения: экспоненциальное распределение
            contact_rate = m.β * (m.Ia[end] / length(m.allIndividuals))
            @yield timeout(env, rand(Exponential(contact_rate)))
            individual.status = I
            individual.infection_time = ConcurrentSim.now(env)
            push!(m.ta, ConcurrentSim.now(env))
            push!(m.Sa, length(filter(x -> x.status == S, m.allIndividuals)))
            push!(m.Ia, length(filter(x -> x.status == I, m.allIndividuals)))
            push!(m.Ra, length(filter(x -> x.status == R, m.allIndividuals)))
            push!(m.Da, length(filter(x -> x.status == D, m.allIndividuals)))
            current_status = I

        elseif current_status == I
            # Время выздоровления: экспоненциальное распределение
            @yield timeout(env, rand(Exponential(m.γ)))
            individual.status = R
            push!(m.ta, ConcurrentSim.now(env))
            push!(m.Sa, length(filter(x -> x.status == S, m.allIndividuals)))
            push!(m.Ia, length(filter(x -> x.status == I, m.allIndividuals)))
            push!(m.Ra, length(filter(x -> x.status == R, m.allIndividuals)))
            push!(m.Da, length(filter(x -> x.status == D, m.allIndividuals)))
            current_status = R

        elseif current_status == R
            # Время до смерти: экспоненциальное распределение
            @yield timeout(env, rand(Exponential(m.μ)))
            individual.status = D
            push!(m.ta, ConcurrentSim.now(env))
            push!(m.Sa, length(filter(x -> x.status == S, m.allIndividuals)))
            push!(m.Ia, length(filter(x -> x.status == I, m.allIndividuals)))
            push!(m.Ra, length(filter(x -> x.status == R, m.allIndividuals)))
            push!(m.Da, length(filter(x -> x.status == D, m.allIndividuals)))
            current_status = D

        elseif current_status == D
            # Агент умер, ничего не происходит
            @yield timeout(env, Inf)  # Бесконечный тайм-аут
        end
    end
end

function vaccinate!(m::SIRModel, individual::SIRPerson)
    current_time = ConcurrentSim.now(m.sim)
    if !isnothing(m.vaccination_time) && current_time ≥ m.vaccination_time
        trigger = true
    elseif !isnothing(m.vaccination_threshold)
        trigger = m.Ia[end] ≥ m.vaccination_threshold
    else
        trigger = false
    end

    # Проводим вакцинацию, только если агент восприимчив
    if trigger && individual.status == S
        if rand() ≤ m.vaccination_fraction
            individual.status = R
            println("Вакцинация агента $individual.id в момент $current_time.")
        end
    end

    # Обновляем статистику
    push!(m.ta, current_time)
    push!(m.Sa, length(filter(x -> x.status == S, m.allIndividuals)))
    push!(m.Ia, length(filter(x -> x.status == I, m.allIndividuals)))
    push!(m.Ra, length(filter(x -> x.status == R, m.allIndividuals)))
    push!(m.Da, length(filter(x -> x.status == D, m.allIndividuals)))
end

function activate(m::SIRModel)
    for i in m.allIndividuals
        async(m.sim, live(m.sim, i, m))
    end
end

function sir_run(m::SIRModel, stop_time::Float64)
    ConcurrentSim.run(m.sim, stop_time)
end

function plot_results(m::SIRModel; filename::String="sir_model.png")
    results = out(m)
    plot(results.t, results.S, label="Восприимчивые (S)", linewidth=2, color=:blue)
    plot!(results.t, results.I, label="Инфицированные (I)", linewidth=2, color=:red)
    plot!(results.t, results.R, label="Выздоровевшие (R)", linewidth=2, color=:green)
    plot!(results.t, results.D, label="Умершие (D)", linewidth=2, color=:black)

    # Показать время вакцинации, если оно установлено
    if !isnothing(m.vaccination_time)
        vline!([m.vaccination_time], label="Вакцинация", color=:purple, linestyle=:dash, linewidth=1)
    end

    xlabel!("Время")
    ylabel!("Количество")
    title!("Модель SIRD с вакцинацией")
    savefig(filename)
end

# Пример использования
function run_example()
    # Параметры начального состояния и модели
    u0 = (S=990, I=10, R=0)
    p = (β=0.3, c=10.0, γ=0.1, μ=0.005)

    # Вакцинация в момент времени t=20 с долей 30%
    model = MakeSIRModel(u0, p;
        vaccination_time=20.0,
        vaccination_fraction=0.3)

    activate(model)
    sir_run(model, 50.0)  # Время симуляции: 50 единиц

    plot_results(model)
end

run_example()

