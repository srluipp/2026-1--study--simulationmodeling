using ResumableFunctions
using ConcurrentSim
using Distributions
using Random
using StableRNGs
const RUNS = 5
const N = 10
const S = 3
const SEED = 150
const LAMBDA = 100
const MU = 1
const rng = StableRNG(42) # setting a random seed for reproducibility
const F = Exponential(LAMBDA)
const G = Exponential(MU)
repair_queue = Int[]
queue_times = Float64[]

working_machines = Int[]
working_times = Float64[]

busy_time = Ref(0.0)
@resumable function machine(
env::Environment,
repair_facility::Resource,
spares::Store{Process},
)
while true
try
@yield timeout(env, Inf)
catch
end
@yield timeout(env, rand(rng, F))
get_spare = take!(spares)
@yield get_spare | timeout(env)
if state(get_spare) != ConcurrentSim.idle
@yield interrupt(value(get_spare))
else
throw(StopSimulation("No more spares!"))
end
push!(queue_times, now(env))
push!(repair_queue, length(repair_facility.put_queue))

t_start = now(env)

@yield request(repair_facility)

busy_time[] += now(env) - t_start
crash_time = Ref(0.0)
@yield timeout(env, rand(rng, G))
push!(working_times, now(env))
push!(working_machines, length(spares.items) + N)
@yield unlock(repair_facility)
@yield put!(spares, active_process(env))
end
end
@resumable function start_sim(
env::Environment,
repair_facility::Resource,
spares::Store{Process},
)
for i = 1:N
proc = @process machine(env, repair_facility, spares)
@yield interrupt(proc)
end
for i = 1:S
proc = @process machine(env, repair_facility, spares)
@yield put!(spares, proc)
end
end
function sim_repair(; N=10, S=3, repairers=1, seed=42)
sim = Simulation()
crash_time = Ref(0.0)
repair_facility = Resource(sim)
spares = Store{Process}(sim)
@process start_sim(sim, repair_facility, spares)
msg = run(sim)
stop_time = now(sim)
crash_time[] = stop_time
println("At time $stop_time: $msg")
return (
    crash_time = crash_time[],
    avg_queue = mean(repair_queue),
    utilization = busy_time[] / crash_time[],
    times = working_times,
    machines = working_machines
)
end
results = []
for i = 1:RUNS
push!(results, sim_repair())
end
avg = mean(r.crash_time for r in results)
println("Average crash time: ", avg)
