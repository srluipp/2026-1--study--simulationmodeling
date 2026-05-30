using DrWatson
using CSV, Dates
filename = "sir_$(u0[1])_$(u0[2])_$(p[1])_$(p[2])_$(p[3]).csv"
CSV.write(datadir("sims", filename), data_des)
@quickactivate "project"
include(srcdir("sir_model.jl"))
using Random, StatsPlots, BenchmarkTools
tmax = 40.0
u0 = [990, 10, 0] # S, I, R
p = [0.05, 10.0, 0.25] # β, c, γ
Random.seed!(1234)
des_model = MakeSIRModel(u0, p)
activate(des_model)
sir_run(des_model, tmax)
data_des = out(des_model)
@df data_des plot(
:t,
[:S :I :R],
labels = ["S" "I" "R"],
xlab = "Время",
ylab = "Численность",
title = "Дискретно-событийная SIR модель",
)
savefig(plotsdir("sir_des.png"))
