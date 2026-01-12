import time
import random
import numpy as np
import agentpy as ap

import argparse

parser = argparse.ArgumentParser(description="Prey-Predator ABM (AgentPy)")

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

parser.add_argument(
    "--grid",
    type=int,
    default=20,
    help="Szerokość i długość siatki"
)

args = parser.parse_args()

STEPS_TO_RUN = args.steps
NB_PREYS_INIT = args.preys
NB_PREDATORS_INIT = args.predators
WIDTH = args.predators
HEIGHT = args.predators

# Parametry Agentów
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


# ==========================================
# KLASY AGENTÓW – agentpy
# ==========================================

class GenericAgent(ap.Agent):
    """Wspólne rzeczy dla Prey i Predator."""

    def setup(self):
        # skróty do środowiska i RNG
        self.grid = self.model.grid
        self.random = self.model.random
        # atrybuty typu max_energy itd. ustawiają podklasy

    def basic_move(self):
        """Losowy krok w sąsiedztwie Moore’a (8 kierunków)."""
        dx, dy = self.random.choice(self.model.move_directions)
        # torus=True, więc zawijanie obsługuje grid
        self.grid.move_by(self, (dx, dy))

    def attempt_reproduce(self, agent_class):
        """Reprodukcja w tym samym polu, jak w wersji Mesa."""
        if self.energy >= self.energy_reproduce and self.random.random() < self.proba_reproduce:
            nb_offsprings = self.random.randint(1, self.nb_max_offsprings)
            if nb_offsprings <= 0:
                return

            energy_share = self.energy / nb_offsprings

            for _ in range(nb_offsprings):
                offspring = agent_class(self.model)
                offspring.energy = energy_share
                # pozycja rodzica
                pos = self.grid.positions[self]
                self.grid.add_agents([offspring], positions=[pos])
                self.model.agents.append(offspring)

            # energia rodzica też dzielona (tak jak w Twoim kodzie)
            self.energy /= nb_offsprings

    def die_check(self):
        """Usunięcie agenta z grida i listy modelu."""
        if self.energy <= 0:
            self.grid.remove_agents([self])
            if self in self.model.agents:
                self.model.agents.remove(self)
            return True
        return False


class Prey(GenericAgent):

    def setup(self):
        super().setup()
        self.max_energy = PREY_MAX_ENERGY
        self.energy_consum = PREY_ENERGY_CONSUM
        self.proba_reproduce = PREY_PROBA_REPRODUCE
        self.nb_max_offsprings = PREY_NB_MAX_OFFSPRINGS
        self.energy_reproduce = PREY_ENERGY_REPRODUCE
        self.energy = self.random.uniform(0, self.max_energy)

    def step(self):
        # jeśli agent został usunięty w tym kroku – nic nie rób
        if self not in self.model.agents:
            return

        self.basic_move()
        self.energy -= self.energy_consum

        # Jedzenie (NumPy jako bufor wegetacji)
        x, y = self.grid.positions[self]
        available_food = self.model.vegetation_food[x, y]
        if available_food > 0:
            transfer = min(PREY_MAX_TRANSFER, available_food)
            self.model.vegetation_food[x, y] -= transfer
            self.energy += transfer

        if self.energy > self.max_energy:
            self.energy = self.max_energy

        if self.die_check():
            return

        self.attempt_reproduce(Prey)


class Predator(GenericAgent):

    def setup(self):
        super().setup()
        self.max_energy = PREDATOR_MAX_ENERGY
        self.energy_consum = PREDATOR_ENERGY_CONSUM
        self.proba_reproduce = PREDATOR_PROBA_REPRODUCE
        self.nb_max_offsprings = PREDATOR_NB_MAX_OFFSPRINGS
        self.energy_reproduce = PREDATOR_ENERGY_REPRODUCE
        self.energy = self.random.uniform(0, self.max_energy)

    def step(self):
        if self not in self.model.agents:
            return

        self.basic_move()
        self.energy -= self.energy_consum

        # Jedzenie – inne agenty w tej samej komórce
        pos = self.grid.positions[self]
        cell_mates = self.grid.agents[pos].to_list()
        reachable_preys = [obj for obj in cell_mates if isinstance(obj, Prey)]

        if reachable_preys:
            victim = self.random.choice(reachable_preys)
            self.grid.remove_agents([victim])
            if victim in self.model.agents:
                self.model.agents.remove(victim)
            self.energy += PREDATOR_ENERGY_TRANSFER

        if self.energy > self.max_energy:
            self.energy = self.max_energy

        if self.die_check():
            return

        self.attempt_reproduce(Predator)


# ==========================================
# MODEL – agentpy
# ==========================================

class PreyPredatorModel(ap.Model):

    def setup(self):
        # Parametry z self.p (dostarczone w konstruktorze)
        self.width = self.p.width
        self.height = self.p.height
        self.nb_preys = self.p.nb_preys
        self.nb_predators = self.p.nb_predators

        # Kierunki ruchu (Moore, bez stania w miejscu)
        self.move_directions = [
            (dx, dy)
            for dx in (-1, 0, 1)
            for dy in (-1, 0, 1)
            if not (dx == 0 and dy == 0)
        ]

        # Grid typu torus (jak MultiGrid(..., torus=True))
        self.grid = ap.Grid(self, (self.width, self.height), torus=True)

        # Lista agentów – jeden kontener dla wszystkich typów
        self.agents = ap.AgentList(self)

        # Inicjalizacja trawy (NumPy – jak w Mesie)
        self.vegetation_food = np.random.rand(self.width, self.height)
        self.vegetation_prod = np.random.rand(self.width, self.height) * 0.01
        self.max_food = CELL_MAX_FOOD

        # Tworzenie agentów
        for _ in range(self.nb_preys):
            a = Prey(self)
            self.agents.append(a)

        for _ in range(self.nb_predators):
            b = Predator(self)
            self.agents.append(b)

        # Rozmieszczenie agentów losowo po gridzie
        self.grid.add_agents(self.agents, random=True)

    def step(self):
        # 1. Wzrost trawy (cała macierz na raz)
        self.vegetation_food += self.vegetation_prod
        np.clip(self.vegetation_food, 0, self.max_food, out=self.vegetation_food)

        # 2. Ruch / akcje agentów
        # iterujemy po kopii listy, żeby móc usuwać/dodawać
        for agent in list(self.agents):
            agent.step()

    def count_agents(self):
        """Pomocniczo, do logów — liczymy po typie klasy."""
        preys = 0
        predators = 0
        for agent in self.agents:
            if isinstance(agent, Prey):
                preys += 1
            elif isinstance(agent, Predator):
                predators += 1
        return preys, predators


# ==========================================
# RUNNER (BENCHMARK, jak w wersji Mesa)
# ==========================================

if __name__ == "__main__":
    print(f"=== START BENCHMARKU ({STEPS_TO_RUN} kroków) ===")
    print(f"Konfiguracja: {WIDTH}x{HEIGHT}, Prey: {NB_PREYS_INIT}, Predator: {NB_PREDATORS_INIT}")

    parameters = dict(
        steps=STEPS_TO_RUN,   # nie używamy model.run(), ale można zostawić
        nb_preys=NB_PREYS_INIT,
        nb_predators=NB_PREDATORS_INIT,
        width=WIDTH,
        height=HEIGHT,
    )

    # Inicjalizacja modelu
    setup_start = time.time()
    model = PreyPredatorModel(parameters)

    # WAŻNE: w agentpy setup nie odpala się automatycznie,
    # bo zwykle robi to model.run(). Tu robimy benchmark, więc:
    model.setup()

    setup_time = time.time() - setup_start
    print(f"Czas inicjalizacji: {setup_time:.4f} s")

    # Główna pętla pomiarowa
    loop_start = time.time()

    last_step = 0
    for i in range(STEPS_TO_RUN):
        model.step()

        if i % 100 == 0:
            n_prey, n_pred = model.count_agents()
            print(f"Krok {i}: Prey={n_prey}, Pred={n_pred}")
            if n_prey == 0 and n_pred == 0:
                print("Wszyscy zginęli - przerywam test.")
                last_step = i
                break
        last_step = i

    loop_end = time.time()
    total_time = loop_end - loop_start
    avg_fps = (last_step + 1) / total_time if total_time > 0 else 0.0
    avg_step = total_time / (last_step + 1)

    print("\n=== WYNIKI ===")
    print(f"Całkowity czas pętli: {total_time:.4f} s")
    print(f"Średnia wydajność:    {avg_fps:.2f} kroków/s (FPS)")
    print(f"Średni czas kroku: {avg_step:.4f} s")
    print("==================")

