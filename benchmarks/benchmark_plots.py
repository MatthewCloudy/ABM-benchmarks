import pandas as pd
import matplotlib.pyplot as plt

# Ścieżki do plików
mesa_path = "benchmark_mesa/results.csv"
agentsjl_path = "benchmark_agentsjl/results.csv"
agentpy_path = "benchmark_agentpy/results.csv"

# Wczytanie danych
mesa = pd.read_csv(mesa_path)
agentsjl = pd.read_csv(agentsjl_path)
agentpy = pd.read_csv(agentpy_path)

# Upewniamy się, że dane są posortowane po liczbie agentów
mesa = mesa.sort_values("agents")
agentsjl = agentsjl.sort_values("agents")
agentpy = agentpy.sort_values("agents")

# Pomocnicza funkcja do rysowania wykresów
def plot_metric(y_col, y_label, title):
    plt.figure(figsize=(8, 5))
    plt.plot(mesa["agents"], mesa[y_col], marker="o", label="Mesa")
    plt.plot(agentsjl["agents"], agentsjl[y_col], marker="o", label="Agents.jl")
    plt.plot(agentpy["agents"], agentpy[y_col], marker="o", label="AgentPy")
    
    plt.xscale("log") 
    
    plt.xlabel("Liczba agentów")
    plt.ylabel(y_label)
    plt.title(title)
    plt.legend()
    plt.grid(True)
    plt.tight_layout()
    plt.show()

# 1. Średnie zużycie CPU
plot_metric(
    y_col="avg_cpu",
    y_label="Średnie zużycie CPU [%]",
    title="Średnie zużycie CPU vs liczba agentów"
)

# 2. Maksymalne zużycie CPU
plot_metric(
    y_col="max_cpu",
    y_label="Maksymalne zużycie CPU [%]",
    title="Maksymalne zużycie CPU vs liczba agentów"
)

# 3. Średnie zużycie RAM
plot_metric(
    y_col="avg_mem_mb",
    y_label="Średnie zużycie RAM [MB]",
    title="Średnie zużycie RAM vs liczba agentów"
)

# 4. Maksymalne zużycie RAM
plot_metric(
    y_col="max_mem_mb",
    y_label="Maksymalne zużycie RAM [MB]",
    title="Maksymalne zużycie RAM vs liczba agentów"
)
