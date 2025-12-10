using Agents, Random
using Statistics
using CSV, DataFrames

println("Threads: ", Threads.nthreads())

# -------------------- PARSOWANIE ARGUMENTÓW --------------------

function parse_args()
    params = Dict(
        :agents => 1000,
        :ratio  => 0.2,
        :steps  => 500,
        :dims   => (20, 20),
        :outfile => "/logs/times.csv"   # <-- domyślny plik CSV
    )

    for arg in ARGS
        if occursin("=", arg)
            key, val = split(arg, "=", limit=2)
            key = Symbol(key)

            if key == :dims
                x, y = split(val, "x")
                params[:dims] = (parse(Int, x), parse(Int, y))

            elseif key == :ratio
                params[:ratio] = parse(Float64, val)

            elseif key == :outfile
                params[:outfile] = val

            elseif haskey(params, key)
                params[key] = parse(Int, val)

            else
                @warn "Nieznany argument: $key"
            end
        end
    end

    return params
end

# -------------------- DEFINICJE AGENTÓW --------------------

@agent struct Sheep(GridAgent{2})
    energy::Float64
    reproduction_prob::Float64
    Δenergy::Float64
end

@agent struct Wolf(GridAgent{2})
    energy::Float64
    reproduction_prob::Float64
    Δenergy::Float64
end

# -------------------- INICJALIZACJA MODEL --------------------

function initialize_model(;
        n_sheep = 100,
        n_wolves = 50,
        dims = (20, 20),
        regrowth_time = 30,
        Δenergy_sheep = 4,
        Δenergy_wolf = 20,
        sheep_reproduce = 0.04,
        wolf_reproduce = 0.05,
        seed = 23182,
    )

    rng = MersenneTwister(seed)
    space = GridSpace(dims, periodic = true)
    properties = (
        fully_grown = falses(dims),
        countdown = zeros(Int, dims),
        regrowth_time = regrowth_time,
    )

    model = StandardABM(Union{Sheep, Wolf}, space;
        agent_step! = sheepwolf_step!, model_step! = grass_step!,
        properties, rng, scheduler = Schedulers.Randomly(), warn = false
    )

    for _ in 1:n_sheep
        energy = rand(abmrng(model), 1:(Δenergy_sheep*2)) - 1
        add_agent!(Sheep, model, energy, sheep_reproduce, Δenergy_sheep)
    end
    for _ in 1:n_wolves
        energy = rand(abmrng(model), 1:(Δenergy_wolf*2)) - 1
        add_agent!(Wolf, model, energy, wolf_reproduce, Δenergy_wolf)
    end

    for p in positions(model)
        fully_grown = rand(abmrng(model), Bool)
        countdown = fully_grown ? regrowth_time : rand(abmrng(model), 1:regrowth_time) - 1
        model.countdown[p...] = countdown
        model.fully_grown[p...] = fully_grown
    end
    return model
end

# -------------------- ZACHOWANIA AGENTÓW --------------------

function sheepwolf_step!(sheep::Sheep, model)
    randomwalk!(sheep, model)
    sheep.energy -= 1
    if sheep.energy < 0
        remove_agent!(sheep, model)
        return
    end
    eat!(sheep, model)
    if rand(abmrng(model)) ≤ sheep.reproduction_prob
        sheep.energy /= 2
        replicate!(sheep, model)
    end
end

function sheepwolf_step!(wolf::Wolf, model)
    randomwalk!(wolf, model; ifempty=false)
    wolf.energy -= 1
    if wolf.energy < 0
        remove_agent!(wolf, model)
        return
    end
    dinner = first_sheep_in_position(wolf.pos, model)
    !isnothing(dinner) && eat!(wolf, dinner, model)
    if rand(abmrng(model)) ≤ wolf.reproduction_prob
        wolf.energy /= 2
        replicate!(wolf, model)
    end
end

function first_sheep_in_position(pos, model)
    ids = ids_in_position(pos, model)
    j = findfirst(id -> model[id] isa Sheep, ids)
    isnothing(j) ? nothing : model[ids[j]]::Sheep
end

function eat!(sheep::Sheep, model)
    if model.fully_grown[sheep.pos...]
        sheep.energy += sheep.Δenergy
        model.fully_grown[sheep.pos...] = false
    end
end

function eat!(wolf::Wolf, sheep::Sheep, model)
    remove_agent!(sheep, model)
    wolf.energy += wolf.Δenergy
end

function grass_step!(model)
    @inbounds for p in positions(model)
        if !model.fully_grown[p...]
            if model.countdown[p...] ≤ 0
                model.fully_grown[p...] = true
                model.countdown[p...] = model.regrowth_time
            else
                model.countdown[p...] -= 1
            end
        end
    end
end

# -------------------- SYMULACJA --------------------

params = parse_args()

total = params[:agents]
ratio = params[:ratio]

wolves = round(Int, total * ratio)
sheep  = total - wolves

println("\n=== PARAMETRY ===")
println("Całkowita liczba agentów: $total")
println("Udział wilków (ratio): $ratio")
println("Wilków: $wolves")
println("Owiec:  $sheep")

model = initialize_model(
    n_sheep = sheep,
    n_wolves = wolves,
    dims = params[:dims]
)

n_steps = params[:steps]
times = Float64[]

for step in 1:n_steps
    t = @elapsed step!(model)
    push!(times, t)
end

println("\n=== PODSUMOWANIE ===")
println("Całkowity czas: ", sum(times))
println("Średni czas kroku: ", mean(times))
println("Mediana: ", median(times))
println("Min: ", minimum(times))
println("Max: ", maximum(times))

# -------------------- ZAPIS DO CSV --------------------

df = DataFrame(step = 1:n_steps, time = times)
CSV.write(params[:outfile], df)

println("\n>> Zapisano czasy kroków do pliku CSV:")
println(params[:outfile])
