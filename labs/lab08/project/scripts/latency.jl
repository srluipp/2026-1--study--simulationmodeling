using Plots
using Random
using Distributions
using Statistics

mutable struct Agent
    status::Symbol          # :S, :E, :I, :R
    id::Int
    recovery_time::Float64  # Время до выздоровления (для :I)
    incubation_time::Float64 # Время до инфекции (для :E)
end

mutable struct SEIRModel
    agents::Vector{Agent}
    beta::Float64           # Темп заражения
    sigma::Float64          # Скорость перехода :E → :I (1/σ)
    gamma::Float64          # Скорость выздоровления (1/γ)
    vaccination_fraction::Float64
    vaccination_timer::Int
    next_vaccination_step::Int
    history::Vector{NTuple{4,Int}}  # История (S, E, I, R)
    time_step::Float64
    events::Vector{Tuple{Float64, Int, Symbol}}  # (время, id агента, событие)
end

# Подсчет агентов по статусам
function count_agents_status(model::SEIRModel)
    S = count(a -> a.status == :S, model.agents)
    E = count(a -> a.status == :E, model.agents)
    I = count(a -> a.status == :I, model.agents)
    R = count(a -> a.status == :R, model.agents)
    return (S, E, I, R)
end

# Инициализация модели
function initialize_model(n_agents::Int, beta::Float64, sigma::Float64, gamma::Float64;
                          vaccination_fraction::Float64=0.1, vaccination_timer::Int=5)
    agents = [Agent(:S, i, 0.0, 0.0) for i in 1:n_agents]
    return SEIRModel(
        agents,
        beta, sigma, gamma,
        vaccination_fraction,
        vaccination_timer,
        vaccination_timer,
        [count_agents_status(SEIRModel(agents, beta, sigma, gamma, 0.0, 0, 0, [], 0.0, []))],
        0.0,
        []
    )
end

# Планирование события (аналог @yield timeout)
function schedule_event!(model::SEIRModel, agent_id::Int, event_time::Float64, event_type::Symbol)
    push!(model.events, (model.time_step + event_time, agent_id, event_type))
    sort!(model.events, by=x->x[1])  # Сортируем по времени
end

# Обработка событий (переходы :E→:I и :I→:R)
function process_events!(model::SEIRModel)
    while !isempty(model.events) && model.events[1][1] ≤ model.time_step
        event_time, agent_id, event_type = popfirst!(model.events)
        agent = model.agents[agent_id]

        if event_type == :I
            agent.status = :I
            agent.recovery_time = rand(Exponential(1/model.gamma))
            schedule_event!(model, agent_id, agent.recovery_time, :R)
        elseif event_type == :R
            agent.status = :R
        end
    end
end

# Вакцинация (уже реализовано)
function vaccinate!(model::SEIRModel)
    susceptible_indices = findall(a -> a.status == :S, model.agents)
    num_to_vaccinate = min(length(susceptible_indices),
                          ceil(Int, length(susceptible_indices) * model.vaccination_fraction))

    if num_to_vaccinate > 0
        vaccinated_indices = sample(1:length(susceptible_indices), num_to_vaccinate, replace=false)
        for i in vaccinated_indices
            model.agents[susceptible_indices[i]].status = :R
        end
    end
end

# Обновление статусов (ключевые изменения: переходы :S→:E→:I)
function update_statuses!(model::SEIRModel)
    # Вакцинация
    if model.time_step ≥ model.next_vaccination_step
        vaccinate!(model)
        model.next_vaccination_step = model.time_step + model.vaccination_timer
    end

    # Обработка событий (переходы :E→:I и :I→:R)
    process_events!(model)

    # Заражение (с переходом :S→:E)
    for agent in model.agents
        if agent.status == :S
            infected_fraction = count(a->a.status ∈ (:I,:E), model.agents) / length(model.agents)
            if rand() < model.beta * infected_fraction
                agent.status = :E  # Переход в латентное состояние
                incubation_time = rand(Exponential(1/model.sigma))
                schedule_event!(model, agent.id, incubation_time, :I)  # Планируем :E→:I
            end
        end
    end

    # Запись истории
    counts = count_agents_status(model)
    push!(model.history, counts)
    model.time_step += 1.0
end

# Построение графика с сохранением
function plot_results(model::SEIRModel; filename="plots/seir_vaccination.png")
    mkpath("plots")  # Создаем папку, если её нет

    # Данные для построения
    S_data = [h[1] for h in model.history]
    E_data = [h[2] for h in model.history]
    I_data = [h[3] for h in model.history]
    R_data = [h[4] for h in model.history]

    # Создание графика
    p = plot(S_data, label="Susceptible (S)", linewidth=2,
             title="SEIR Model with Vaccination\n(β=$(round(model.beta; digits=2)), σ=$(round(model.sigma; digits=2)), γ=$(round(model.gamma; digits=2)))",
             xlabel="Time step", ylabel="Number of individuals")

    # Добавляем остальные данные
    plot!(p, E_data, label="Exposed (E)", linewidth=2)
    plot!(p, I_data, label="Infected (I)", linewidth=2, linestyle=:dash)
    plot!(p, R_data, label="Recovered (R)", linewidth=2)

    # Настройка легенды
    p = plot!(p, legend=:topright)

    # Сохранение и вывод
    savefig(p, filename)
    display(p)  # Отображаем график в REPL (если запускаем в интерактивной сессии)
    println("График сохранён в: ", abspath(filename))
end


# Основная функция
function main()
    Random.seed!(123)
    model = initialize_model(1000, 0.3, 0.3, 0.1, vaccination_fraction=0.15)

    # Запуск модели
    for _ in 1:100
        update_statuses!(model)
    end

    # Построение и сохранение графика
    plot_results(model)
end

main()






