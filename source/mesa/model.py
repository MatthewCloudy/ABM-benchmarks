import time
import random
import numpy as np
from mesa import Agent, Model
from mesa.time import RandomActivation
from mesa.space import MultiGrid
import argparse

parser = argparse.ArgumentParser(description="Prey-Predator ABM (Mesa)")

parser.add_argument(
    "--steps",
    type=int,
    default=2000,
    help="Liczba kroków symulacji"
)

parser.add_argument(
    "--preys",
    type=int,
    default=200,
    help="Początkowa liczba prey"
)

parser.add_argument(
    "--predators",
    type=int,
    default=20,
    help="Początkowa liczba predatorów"
)

args = parser.parse_args()

STEPS_TO_RUN = args.steps
NB_PREYS_INIT = args.preys
NB_PREDATORS_INIT = args.predators
WIDTH = 50
HEIGHT = 50

PREY_MAX_ENERGY = 1.0
PREY_MAX_TRANSFER = 0.1
PREY_ENERGY_CONSUM = 0.05
PREY_PROBA_REPRODUCE = 0.01
PREY_NB_MAX_OFFSPRINGS = 5
PREY_ENERGY_REPRODUCE = 0.5

PREDATOR_MAX_ENERGY = 1.0
PREDATOR_ENERGY_TRANSFER = 0.5
PREDATOR_ENERGY_CONSUM = 0.02
PREDATOR_PROBA_REPRODUCE = 0.01
PREDATOR_NB_MAX_OFFSPRINGS = 3
PREDATOR_ENERGY_REPRODUCE = 0.5

CELL_MAX_FOOD = 1.0




class GenericAgent(Agent):
    __slots__ = ('max_energy', 'energy_consum', 'proba_reproduce',
                 'nb_max_offsprings', 'energy_reproduce', 'energy')

    def __init__(self, unique_id, model, max_energy, energy_consum,
                 proba_reproduce, nb_max_offsprings, energy_reproduce):
        super().__init__(unique_id, model)
        self.max_energy = max_energy
        self.energy_consum = energy_consum
        self.proba_reproduce = proba_reproduce
        self.nb_max_offsprings = nb_max_offsprings
        self.energy_reproduce = energy_reproduce
        self.energy = random.uniform(0, max_energy)

    def basic_move(self):
        possible_steps = self.model.grid.get_neighborhood(
            self.pos, moore=True, include_center=False
        )
        if possible_steps:
            new_position = random.choice(possible_steps)
            self.model.grid.move_agent(self, new_position)

    def attempt_reproduce(self, agent_class):
        if self.energy >= self.energy_reproduce and random.random() < self.proba_reproduce:
            nb_offsprings = random.randint(1, self.nb_max_offsprings)
            energy_share = self.energy / nb_offsprings

            for _ in range(nb_offsprings):
                offspring = agent_class(self.model.next_id(), self.model)
                offspring.energy = energy_share
                self.model.grid.place_agent(offspring, self.pos)
                self.model.schedule.add(offspring)

            self.energy /= nb_offsprings

    def die_check(self):
        if self.energy <= 0:
            self.model.grid.remove_agent(self)
            self.model.schedule.remove(self)
            return True
        return False


class Prey(GenericAgent):
    def __init__(self, unique_id, model):
        super().__init__(unique_id, model,
                         PREY_MAX_ENERGY, PREY_ENERGY_CONSUM,
                         PREY_PROBA_REPRODUCE, PREY_NB_MAX_OFFSPRINGS,
                         PREY_ENERGY_REPRODUCE)

    def step(self):
        if not self.pos: return
        self.basic_move()
        self.energy -= self.energy_consum

        x, y = self.pos
        available_food = self.model.vegetation_food[x, y]
        if available_food > 0:
            transfer = min(PREY_MAX_TRANSFER, available_food)
            self.model.vegetation_food[x, y] -= transfer
            self.energy += transfer

        if self.energy > self.max_energy: self.energy = self.max_energy
        if self.die_check(): return
        self.attempt_reproduce(Prey)


class Predator(GenericAgent):
    def __init__(self, unique_id, model):
        super().__init__(unique_id, model,
                         PREDATOR_MAX_ENERGY, PREDATOR_ENERGY_CONSUM,
                         PREDATOR_PROBA_REPRODUCE, PREDATOR_NB_MAX_OFFSPRINGS,
                         PREDATOR_ENERGY_REPRODUCE)

    def step(self):
        if not self.pos: return
        self.basic_move()
        self.energy -= self.energy_consum

        cell_mates = self.model.grid.get_cell_list_contents([self.pos])
        reachable_preys = [obj for obj in cell_mates if type(obj) is Prey]

        if reachable_preys:
            victim = random.choice(reachable_preys)
            self.model.grid.remove_agent(victim)
            self.model.schedule.remove(victim)
            self.energy += PREDATOR_ENERGY_TRANSFER

        if self.energy > self.max_energy: self.energy = self.max_energy
        if self.die_check(): return
        self.attempt_reproduce(Predator)



class PreyPredatorModel(Model):
    def __init__(self, nb_preys=NB_PREYS_INIT, nb_predators=NB_PREDATORS_INIT):
        super().__init__()
        self.width = WIDTH
        self.height = HEIGHT
        self.schedule = RandomActivation(self)
        self.grid = MultiGrid(self.width, self.height, torus=True)

        self.vegetation_food = np.random.rand(self.width, self.height)
        self.vegetation_prod = np.random.rand(self.width, self.height) * 0.01
        self.max_food = CELL_MAX_FOOD

        for _ in range(nb_preys):
            a = Prey(self.next_id(), self)
            self.schedule.add(a)
            self.grid.place_agent(a, (random.randrange(self.width), random.randrange(self.height)))

        for _ in range(nb_predators):
            b = Predator(self.next_id(), self)
            self.schedule.add(b)
            self.grid.place_agent(b, (random.randrange(self.width), random.randrange(self.height)))

    def step(self):
        self.vegetation_food += self.vegetation_prod
        np.clip(self.vegetation_food, 0, self.max_food, out=self.vegetation_food)

        self.schedule.step()

    def count_agents(self):
        preys = 0
        predators = 0
        for agent in self.schedule.agents:
            if type(agent) is Prey:
                preys += 1
            elif type(agent) is Predator:
                predators += 1
        return preys, predators



if __name__ == "__main__":
    print(f"=== START BENCHMARKU ({STEPS_TO_RUN} kroków) ===")
    print(f"Konfiguracja: {WIDTH}x{HEIGHT}, Prey: {NB_PREYS_INIT}, Predator: {NB_PREDATORS_INIT}")

    setup_start = time.time()
    model = PreyPredatorModel()
    setup_time = time.time() - setup_start
    print(f"Czas inicjalizacji: {setup_time:.4f} s")

    loop_start = time.time()

    for i in range(STEPS_TO_RUN):
        model.step()

        if i % 100 == 0:
            n_prey, n_pred = model.count_agents()
            print(f"Krok {i}: Prey={n_prey}, Pred={n_pred}")
            if n_prey == 0 and n_pred == 0:
                print("Wszyscy zginęli - przerywam test.")
                break

    loop_end = time.time()
    total_time = loop_end - loop_start
    avg_fps = (i + 1) / total_time

    print("\n=== WYNIKI ===")
    print(f"Całkowity czas pętli: {total_time:.4f} s")
    print(f"Średnia wydajność:    {avg_fps:.2f} kroków/s (FPS)")
    print("==================")