import agentpy as ap
import numpy as np
import random
import time


# =========================
# === PARAMETRY ===========
# =========================

STEPS_TO_RUN = 2000

parameters = dict(
    steps_to_run=STEPS_TO_RUN,
    nb_preys_init=200,
    nb_predators_init=20,
    width=50,
    height=50,

    prey_max_energy=1.0,
    prey_max_transfer=0.1,
    prey_energy_consum=0.05,
    prey_proba_reproduce=0.01,
    prey_nb_max_offsprings=5,
    prey_energy_reproduce=0.5,

    predator_max_energy=1.0,
    predator_energy_transfer=0.5,
    predator_energy_consum=0.02,
    predator_proba_reproduce=0.01,
    predator_nb_max_offsprings=3,
    predator_energy_reproduce=0.5,

    cell_max_food=1.0,
)


# =========================
# === AGENT BAZOWY ========
# =========================

class Animal(ap.Agent):

    def setup(self):
        self.energy = random.random() * self.p.max_energy

    def move(self):
        grid = self.model.grid
        pos = grid.positions[self]

        neighbors = grid.neighbors(pos, moore=True, include_center=False)
        if neighbors:
            grid.move_to(self, random.choice(neighbors))

    def die_if_needed(self):
        if self.energy <= 0:
            self.remove()
            return True
        return False


# =========================
# === PREY ================
# =========================

class Prey(Animal):

    def setup(self):
        self.max_energy = self.p.prey_max_energy
        self.energy_consum = self.p.prey_energy_consum
        self.proba_reproduce = self.p.prey_proba_reproduce
        self.nb_max_offsprings = self.p.prey_nb_max_offsprings
        self.energy_reproduce = self.p.prey_energy_reproduce
        self.max_transfer = self.p.prey_max_transfer
        super().setup()

    def step(self):
        grid = self.model.grid
        self.move()
        self.energy -= self.energy_consum

        x, y = grid.positions[self]
        food = self.model.vegetation_food[x, y]

        if food > 0:
            transfer = min(self.max_transfer, food)
            self.model.vegetation_food[x, y] -= transfer
            self.energy += transfer

        self.energy = min(self.energy, self.max_energy)
        if self.die_if_needed():
            return

        if self.energy >= self.energy_reproduce and random.random() < self.proba_reproduce:
            n = random.randint(1, self.nb_max_offsprings)
            share = self.energy / n
            for _ in range(n):
                child = self.model.new_agent(Prey)
                child.energy = share
                grid.place_agent(child, grid.positions[self])
            self.energy /= n


# =========================
# === PREDATOR ============
# =========================

class Predator(Animal):

    def setup(self):
        self.max_energy = self.p.predator_max_energy
        self.energy_consum = self.p.predator_energy_consum
        self.proba_reproduce = self.p.predator_proba_reproduce
        self.nb_max_offsprings = self.p.predator_nb_max_offsprings
        self.energy_reproduce = self.p.predator_energy_reproduce
        self.energy_transfer = self.p.predator_energy_transfer
        super().setup()

    def step(self):
        grid = self.model.grid
        self.move()
        self.energy -= self.energy_consum

        pos = grid.positions[self]
        preys_here = list(self.model.preys.at(pos))

        if preys_here:
            victim = random.choice(preys_here)
            victim.remove()
            self.energy += self.energy_transfer

        self.energy = min(self.energy, self.max_energy)
        if self.die_if_needed():
            return

        if self.energy >= self.energy_reproduce and random.random() < self.proba_reproduce:
            n = random.randint(1, self.nb_max_offsprings)
            share = self.energy / n
            for _ in range(n):
                child = self.model.new_agent(Predator)
                child.energy = share
                grid.place_agent(child, pos)
            self.energy /= n


# =========================
# === MODEL ===============
# =========================

class PreyPredatorModel(ap.Model):

    def setup(self):
        self.grid = ap.Grid(
            self,
            shape=(self.p.width, self.p.height),
            torus=True
        )

        self.vegetation_food = np.random.rand(self.p.width, self.p.height)
        self.vegetation_prod = np.random.rand(self.p.width, self.p.height) * 0.01

        self.preys = ap.AgentSet(self, self.p.nb_preys_init, Prey)
        self.predators = ap.AgentSet(self, self.p.nb_predators_init, Predator)

        self.grid.add_agents(self.preys, random=True)
        self.grid.add_agents(self.predators, random=True)

    def step(self):
        self.vegetation_food += self.vegetation_prod
        np.clip(
            self.vegetation_food,
            0,
            self.p.cell_max_food,
            out=self.vegetation_food
        )

        self.preys.step()
        self.predators.step()

    def update(self):
        if self.t % 100 == 0:
            print(
                f"Krok {self.t}: "
                f"Prey={len(self.preys)}, "
                f"Pred={len(self.predators)}"
            )

        if (
            self.t >= self.p.steps_to_run
            or (len(self.preys) == 0 and len(self.predators) == 0)
        ):
            self.stop()


# =========================
# === MAIN ================
# =========================

if __name__ == "__main__":
    print(f"=== START BENCHMARKU ({STEPS_TO_RUN} kroków) ===")

    start = time.time()
    model = PreyPredatorModel(parameters)
    model.run()
    total_time = time.time() - start

    fps = model.t / total_time if total_time > 0 else 0

    print("\n=== WYNIKI ===")
    print(f"Całkowity czas pętli: {total_time:.4f} s")
    print(f"Średnia wydajność:    {fps:.2f} kroków/s (FPS)")
    print("==================")
