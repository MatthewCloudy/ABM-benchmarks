using Agents
using Random
using Statistics
using Dates
using ArgParse

function parse_commandline()
    s = ArgParseSettings()

    @add_arg_table s begin
        "--steps"
            help = "Liczba kroków symulacji"
            arg_type = Int
            default = 2000

        "--preys"
            help = "Początkowa liczba ofiar"
            arg_type = Int
            default = 200

        "--predators"
            help = "Początkowa liczba drapieżników"
            arg_type = Int
            default = 20
    end

    return parse_args(s)
end

ARGS_PARSED = parse_commandline()


STEPS_TO_RUN = ARGS_PARSED["steps"]
NB_PREYS_INIT = ARGS_PARSED["preys"]
NB_PREDATORS_INIT = ARGS_PARSED["predators"]
const DIMS = (50, 50)

const PREY_MAX_ENERGY = 1.0
const PREY_MAX_TRANSFER = 0.1
const PREY_ENERGY_CONSUM = 0.05
const PREY_PROBA_REPRODUCE = 0.01
const PREY_NB_MAX_OFFSPRINGS = 5
const PREY_ENERGY_REPRODUCE = 0.5

const PREDATOR_MAX_ENERGY = 1.0
const PREDATOR_ENERGY_TRANSFER = 0.5
const PREDATOR_ENERGY_CONSUM = 0.02
const PREDATOR_PROBA_REPRODUCE = 0.01
const PREDATOR_NB_MAX_OFFSPRINGS = 3
const PREDATOR_ENERGY_REPRODUCE = 0.5

const CELL_MAX_FOOD = 1.0


@agent struct Animal(GridAgent{2})
    type::Symbol
    energy::Float64
    max_energy::Float64
    energy_consum::Float64
    proba_reproduce::Float64
    nb_max_offsprings::Int
    energy_reproduce::Float64
end



function animal_step!(agent, model)
    move_agent!(agent, model)

    agent.energy -= agent.energy_consum

    pos = agent.pos
    if agent.type == :prey
        available_food = model.vegetation_food[pos...]
        if available_food > 0
            transfer = min(PREY_MAX_TRANSFER, available_food)
            model.vegetation_food[pos...] -= transfer
            agent.energy += transfer
        end
    else
        agents_here = agents_in_position(pos, model)
        preys = [a for a in agents_here if a.type == :prey]
        if !isempty(preys)
            victim = rand(abmrng(model), preys)
            remove_agent!(victim, model)
            agent.energy += PREDATOR_ENERGY_TRANSFER
        end
    end

    if agent.energy > agent.max_energy
        agent.energy = agent.max_energy
    end

    if agent.energy <= 0
        remove_agent!(agent, model)
        return
    end

    if agent.energy >= agent.energy_reproduce && rand(abmrng(model)) < agent.proba_reproduce
        nb_offsprings = rand(abmrng(model), 1:agent.nb_max_offsprings)
        energy_share = agent.energy / nb_offsprings

        for _ in 1:nb_offsprings
            add_agent!(
                agent.pos, model,
                agent.type,
                energy_share,
                agent.max_energy, agent.energy_consum, agent.proba_reproduce,
                agent.nb_max_offsprings, agent.energy_reproduce
            )
        end
        agent.energy /= nb_offsprings
    end
end

function vegetation_step!(model)
    model.vegetation_food .+= model.vegetation_prod
    clamp!(model.vegetation_food, 0.0, model.max_food)
end



function initialize_model()
    space = GridSpace(DIMS; periodic = true, metric = :chebyshev)

    properties = Dict(
        :vegetation_food => rand(DIMS...),
        :vegetation_prod => rand(DIMS...) .* 0.01,
        :max_food => CELL_MAX_FOOD
    )

    model = StandardABM(
        Animal,
        space;
        agent_step! = animal_step!,
        model_step! = vegetation_step!,
        properties = properties,
        scheduler = Schedulers.Randomly()
    )

    for _ in 1:NB_PREYS_INIT
        add_agent!(
            model, :prey, rand() * PREY_MAX_ENERGY,
            PREY_MAX_ENERGY, PREY_ENERGY_CONSUM, PREY_PROBA_REPRODUCE,
            PREY_NB_MAX_OFFSPRINGS, PREY_ENERGY_REPRODUCE
        )
    end

    for _ in 1:NB_PREDATORS_INIT
        add_agent!(
            model, :predator, rand() * PREDATOR_MAX_ENERGY,
            PREDATOR_MAX_ENERGY, PREDATOR_ENERGY_CONSUM, PREDATOR_PROBA_REPRODUCE,
            PREDATOR_NB_MAX_OFFSPRINGS, PREDATOR_ENERGY_REPRODUCE
        )
    end

    return model
end



println("=== START BENCHMARKU (Julia) ===")
println("Konfiguracja: $(DIMS[1])x$(DIMS[2]), Prey: $NB_PREYS_INIT, Predator: $NB_PREDATORS_INIT")

t_start = now()
model = initialize_model()
t_init = now() - t_start
println("Czas inicjalizacji: $(Dates.value(t_init)/1000) s")

t_loop_start = time()

for i in 1:STEPS_TO_RUN
    step!(model, 1)

    if i % 100 == 0
        n_prey = count(a -> a.type == :prey, allagents(model))
        n_pred = count(a -> a.type == :predator, allagents(model))
        println("Krok $i: Prey=$n_prey, Pred=$n_pred")

        if n_prey == 0 && n_pred == 0
            println("Wszyscy zginęli - przerywam test.")
            break
        end
    end
end

t_loop_end = time()
total_time = t_loop_end - t_loop_start
avg_fps = STEPS_TO_RUN / total_time

println("\n=== WYNIKI (Julia) ===")
println("Całkowity czas pętli: $(round(total_time, digits=4)) s")
println("Średnia wydajność:    $(round(avg_fps, digits=2)) kroków/s (FPS)")
println("======================")