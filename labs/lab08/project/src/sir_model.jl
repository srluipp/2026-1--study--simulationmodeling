using ResumableFunctions, ConcurrentSim, Distributions, DataFrames, Random

# Функции обновления статистики
function increment!(a::Array{Int64})
    push!(a, a[end] + 1)
end
function decrement!(a::Array{Int64})
    push!(a, a[end] - 1)
end
function carryover!(a::Array{Int64})
    push!(a, a[end])
end

# Добавлен новый статус :D (умершие)
mutable struct SIRPerson
    id::Int64
    status::Symbol  # :S, :I, :R, :D
end

mutable struct SIRModel
    sim::ConcurrentSim.Simulation
    β::Float64         # Коэффициент заражения
    c::Float64         # Скорость контактов (1/c — среднее время поиска инфицированного)
    γ::Float64         # Скорость выздоровления (1/γ — средняя длительность болезни)
    μ::Float64         # Интенсивность смертности (1/μ — средний срок жизни)
    ta::Array{Float64} # Временная шкала
    Sa::Array{Int64}   # Восприимчивые
    Ia::Array{Int64}   # Инфицированные
    Ra::Array{Int64}   # Выздоровевшие
    Da::Array{Int64}   # Умершие
    allIndividuals::Array{SIRPerson}
end

# Функция обновления при заражении
function infection_update!(sim::ConcurrentSim.Simulation, m::SIRModel)
    push!(m.ta, ConcurrentSim.now(sim))
    decrement!(m.Sa)
    increment!(m.Ia)
    carryover!(m.Ra)
    carryover!(m.Da)
end

# Функция обновления при выздоровлении
function recovery_update!(sim::ConcurrentSim.Simulation, m::SIRModel)
    push!(m.ta, ConcurrentSim.now(sim))
    carryover!(m.Sa)
    decrement!(m.Ia)
    increment!(m.Ra)
    carryover!(m.Da)
end

# Функция обновления при смерти
function death_update!(sim::ConcurrentSim.Simulation, m::SIRModel, prev_status::Symbol)
    push!(m.ta, ConcurrentSim.now(sim))
    if prev_status == :S
        decrement!(m.Sa)
        carryover!(m.Ia)
        carryover!(m.Ra)
    elseif prev_status == :I
        decrement!(m.Ia)
        carryover!(m.Sa)
        carryover!(m.Ra)
    elseif prev_status == :R
        decrement!(m.Ra)
        carryover!(m.Sa)
        carryover!(m.Ia)
    end
    increment!(m.Da)
end

# Основная функция жизни агента (с учётом смерти)
@resumable function live(env::ConcurrentSim.Simulation, individual::SIRPerson, m::SIRModel)
    prev_status = individual.status
    while true
        if individual.status == :S
            @yield timeout(env, rand(Exponential(1/m.c)))  # Ожидание контакта
            N = length(m.allIndividuals)
            alter = individual
            while alter == individual
                index = rand(1:N)
                alter = m.allIndividuals[index]
            end
            if alter.status == :I && rand() < m.β
                individual.status = :I
                infection_update!(env, m)
                prev_status = :S
            end
            # Вероятность смерти в статусе :S
            if rand() < m.μ * ConcurrentSim.now(env)
                individual.status = :D
                death_update!(env, m, prev_status)
                return
            end
        elseif individual.status == :I
            @yield timeout(env, rand(Exponential(1/m.γ)))  # Ожидание выздоровления
            individual.status = :R
            recovery_update!(env, m)
            prev_status = :I
            # Вероятность смерти в статусе :I
            if rand() < m.μ * ConcurrentSim.now(env)
                individual.status = :D
                death_update!(env, m, prev_status)
                return
            end
        elseif individual.status == :R
            @yield timeout(env, rand(Exponential(1/m.μ)))  # Возможность смерти даже после выздоровления
            if rand() < m.μ * ConcurrentSim.now(env)
                individual.status = :D
                death_update!(env, m, prev_status)
                return
            end
        end
    end
end

# Создание модели
function MakeSIRModel(u0, p)
    (S, I, R) = u0
    N = S + I + R
    (β, c, γ, μ) = p
    sim = ConcurrentSim.Simulation()
    allIndividuals = SIRPerson[]
    for i = 1:S
        push!(allIndividuals, SIRPerson(i, :S))
    end
    for i = (S+1):(S+I)
        push!(allIndividuals, SIRPerson(i, :I))
    end
    for i = (S+I+1):N
        push!(allIndividuals, SIRPerson(i, :R))
    end
    ta = Float64[0.0]
    Sa = Int64[S]
    Ia = Int64[I]
    Ra = Int64[R]
    Da = Int64[0]   # Новый массив для умерших
    SIRModel(sim, β, c, γ, μ, ta, Sa, Ia, Ra, Da, allIndividuals)
end

# Активация агентов
function activate(m::SIRModel)
    @process live(m.sim, individual, m) for individual in m.allIndividuals
end

# Запуск симуляции
function sir_run(m::SIRModel, tf::Float64)
    ConcurrentSim.run(m.sim, tf)
end

# Вывод результатов
function out(m::SIRModel)
    result = DataFrame(
        t = m.ta,
        S = m.Sa,
        I = m.Ia,
        R = m.Ra,
        D = m.Da
    )
    return result
end

