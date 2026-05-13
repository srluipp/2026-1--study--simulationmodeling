using Plots

N = 12800
I0 = 180
R0 = 58
S0 = N - I0 - R0

alpha = 0.0002
beta = 0.1

t_max = 160
dt = 0.1
t = 0:dt:t_max

S = zeros(length(t))
I = zeros(length(t))
R = zeros(length(t))

S[1] = S0
I[1] = I0
R[1] = R0

for i in 1:length(t)-1
    dS = -alpha * S[i] * I[i]
    dI = alpha * S[i] * I[i] - beta * I[i]
    dR = beta * I[i]

    S[i+1] = S[i] + dS * dt
    I[i+1] = I[i] + dI * dt
    R[i+1] = R[i] + dR * dt
end

plot(t, S, label="S(t)")
plot!(t, I, label="I(t)")
plot!(t, R, label="R(t)")

xlabel!("Время")
ylabel!("Численность")
title!("Модель эпидемии SIR")
