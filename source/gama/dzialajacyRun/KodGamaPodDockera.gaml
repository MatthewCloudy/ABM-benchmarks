/**
* Name: Breeding of prey and predator agents (FIXED VERSION)
*/
model prey_predator

global torus: true {

	int steps_to_run <- 2000;
	float start_time;

	// Parametry modelu
	int nb_preys_init <- 200;
	int nb_predators_init <- 20;
	float prey_max_energy <- 1.0;
	float prey_max_transfer <- 0.1;
	float prey_energy_consum <- 0.05;
	float predator_max_energy <- 1.0;
	float predator_energy_transfer <- 0.5;
	float predator_energy_consum <- 0.02;
	float prey_proba_reproduce <- 0.01;
	int prey_nb_max_offsprings <- 5;
	float prey_energy_reproduce <- 0.5;
	float predator_proba_reproduce <- 0.01;
	int predator_nb_max_offsprings <- 3;
	float predator_energy_reproduce <- 0.5;

	int nb_preys -> {length(prey)};
	int nb_predators -> {length(predator)};

	init {
		// ZMIANA 2: Zamiast machine_time uzywamy float(#now)
		start_time <- float(#now);
		write "=== START BENCHMARKU (" + steps_to_run + " krokow) ===";
		write "Konfiguracja: 50x50, Prey: " + nb_preys_init + ", Predator: " + nb_predators_init;

		create prey number: nb_preys_init;
		create predator number: nb_predators_init;
	}

	reflex simulation_step_mixed {
		ask (prey + predator) {
			do step_behavior;
		}
	}

	reflex benchmarking {
		if (cycle mod 100 = 0) {
			write "Krok " + cycle + ": Prey=" + nb_preys + ", Pred=" + nb_predators;
		}

		bool stop_condition <- (cycle >= steps_to_run) or (nb_preys = 0 and nb_predators = 0);

		if (stop_condition) {
			if (nb_preys = 0 and nb_predators = 0) { write "Wszyscy zgineli - przerywam test."; }

			// ZMIANA 3: Tutaj tez uzywamy float(#now)
			float end_time <- float(#now);
			float total_time_seconds <- (end_time - start_time) / 1000;
			float avg_fps <- (cycle > 0 and total_time_seconds > 0) ? (cycle / total_time_seconds) : 0;

			write "\n=== WYNIKI ===";
			write "Calkowity czas petli: " + total_time_seconds + " s";
			write "Srednia wydajnosc:    " + avg_fps + " krokow/s (FPS)";
			write "==================";

			do die;
		}
	}
}

species generic_species {
	float size <- 1.0;
	rgb color;
	float max_energy;
	float max_transfer;
	float energy_consum;
	float proba_reproduce;
	int nb_max_offsprings;
	float energy_reproduce;
	vegetation_cell my_cell <- one_of(vegetation_cell);

	float energy <- rnd(max_energy) max: max_energy;

	init {
		location <- my_cell.location;
	}

	action step_behavior {
		do basic_move;
		energy <- energy - energy_consum;
		do eat;
		if (energy > max_energy) { energy <- max_energy; }

		if (energy <= 0) {
			do die;
		} else {
			do reproduce;
		}
	}

	action basic_move {
		list<vegetation_cell> possible_steps <- my_cell.neighbors;
		if (!empty(possible_steps)) {
			my_cell <- one_of(possible_steps);
			location <- my_cell.location;
		}
	}

	action eat {
		energy <- energy + energy_from_eat();
	}

	action reproduce {
		if (energy >= energy_reproduce) and (flip(proba_reproduce)) {
			int nb_offsprings <- rnd(1, nb_max_offsprings);
			create species(self) number: nb_offsprings {
				my_cell <- myself.my_cell;
				location <- my_cell.location;
				energy <- myself.energy / nb_offsprings;
			}
			energy <- energy / nb_offsprings;
		}
	}

	float energy_from_eat {
		return 0.0;
	}

	aspect base {
		draw circle(size) color: color;
	}
}

species prey parent: generic_species {
	rgb color <- #blue;
	float max_energy <- prey_max_energy;
	float max_transfer <- prey_max_transfer;
	float energy_consum <- prey_energy_consum;
	float proba_reproduce <- prey_proba_reproduce;
	int nb_max_offsprings <- prey_nb_max_offsprings;
	float energy_reproduce <- prey_energy_reproduce;

	float energy_from_eat {
		float energy_transfer <- 0.0;
		if(my_cell.food > 0) {
			energy_transfer <- min([max_transfer, my_cell.food]);
			my_cell.food <- my_cell.food - energy_transfer;
		}
		return energy_transfer;
	}
}

species predator parent: generic_species {
	rgb color <- #red;
	float max_energy <- predator_max_energy;
	float energy_transfer <- predator_energy_transfer;
	float energy_consum <- predator_energy_consum;
	float proba_reproduce <- predator_proba_reproduce;
	int nb_max_offsprings <- predator_nb_max_offsprings;
	float energy_reproduce <- predator_energy_reproduce;

	float energy_from_eat {
		list<prey> reachable_preys <- prey inside (my_cell);
		if(! empty(reachable_preys)) {
			ask one_of (reachable_preys) {
				do die;
			}
			return energy_transfer;
		}
		return 0.0;
	}
}

grid vegetation_cell width: 50 height: 50 neighbors: 8 {
	float max_food <- 1.0;
	float food_prod <- rnd(0.01);
	float food <- rnd(1.0) max: max_food update: food + food_prod;
	rgb color <- rgb(int(255 * (1 - food)), 255, int(255 * (1 - food)))
				 update: rgb(int(255 * (1 - food)), 255, int(255 * (1 - food)));
}

// ... (reszta kodu bez zmian, aż do sekcji experiment) ...

experiment prey_predator type: batch {
    // Te parametry wystawiamy "na świat", żeby Bash mógł je zmieniać
    parameter "Preys Init" var: nb_preys_init;
    parameter "Predators Init" var: nb_predators_init;
    parameter "Steps" var: steps_to_run;
}
