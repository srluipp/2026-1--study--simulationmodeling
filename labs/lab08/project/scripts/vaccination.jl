using Plots
using Random  
using Statistics
using Printf


mutable struct Agent
    status::Symbol
    id::Int
end

mutable struct SIRModel
    agents::Vector{Agent}
    beta::Float64
    gamma::Float64
    vaccination_fraction::Float64
    vaccination_timer::Int
    next_vaccination_step::Int
    history::Vector{Tuple{Int, Int, Int}}
    time_step::Int
end

function initialize_model(n_agents::Int, beta::Float64, gamma::Float64;
                          vaccination_fraction::Float64=0.1,
                          vaccination_timer::Int=5)
    agents = [Agent(:S, i) for i in 1:n_agents]
    model = SIRModel(
        agents,
        beta,
        gamma,
        vaccination_fraction,
        vaccination_timer,
        vaccination_timer,
        [(n_agents, 0, 0)],
        0
    )
    return model
end

function vaccinate!(model::SIRModel)
    susceptible_agents = [agent for agent in model.agents if agent.status == :S]
    if isempty(susceptible_agents)
        return
    end

    num_to_vaccinate = ceil(Int, length(susceptible_agents) * model.vaccination_fraction)
    num_to_vaccinate = min(num_to_vaccinate, length(susceptible_agents))
    shuffled = shuffle(susceptible_agents)  
    agents_to_vaccinate = shuffled[1:num_to_vaccinate]

    for agent in agents_to_vaccinate
        agent.status = :R
    end

    @info "Вакцинировано $num_to_vaccinate агентов."
end

function update_statuses!(model::SIRModel)
    if model.time_step >= model.next_vaccination_step
        vaccinate!(model)
        model.next_vaccination_step = model.time_step + model.vaccination_timer
    end

    for agent in model.agents
        if agent.status == :I
            if rand() < model.gamma
                agent.status = :R
            end
        elseif agent.status == :S
            infected_fraction = count(a -> a.status == :I, model.agents) / length(model.agents)
            if infected_fraction > 0 && rand() < model.beta * infected_fraction
                agent.status = :I
            end
        end
    end

    push!(model.history, (
        count(a -> a.status == :S, model.agents),
        count(a -> a.status == :I, model.agents),
        count(a -> a.status == :R, model.agents)
    ))
    model.time_step += 1
end

function run_simulation(model::SIRModel, steps::Int)
    for _ in 1:steps
        update_statuses!(model)
    end
end

function plot_results(model::SIRModel)
    S_history = [h[1] for h in model.history]
    I_history = [h[2] for h in model.history]
    R_history = [h[3] for h in model.history]

    plot(
        1:length(S_history),
        [S_history I_history R_history],
        label=["S" "I" "R"],
        title="Модель SIR с вакцинацией",
        xlabel="Шаг симуляции",
        ylabel="Количество агентов",
        legend=:topleft,
        linewidth=2,
        color=[:blue :red :green]
    )
end

function main()
    Random.seed!(42)
    n_agents = 1000
    beta = 0.4
    gamma = 0.1
    vaccination_fraction = 0.15
    vaccination_timer = 5

    model = initialize_model(n_agents, beta, gamma;
                             vaccination_fraction=vaccination_fraction,
                             vaccination_timer=vaccination_timer)
    run_simulation(model, 100)
    plot_results(model)
end

main()










 









