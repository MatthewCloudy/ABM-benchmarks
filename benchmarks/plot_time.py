import re
import pathlib
import pandas as pd
import matplotlib.pyplot as plt

# ============================================================
# Configuration
# ============================================================
BASE_DIR = pathlib.Path(".")

PLATFORMS = {
    "mesa": BASE_DIR / "benchmark_mesa" / "logs",
    "agentpy": BASE_DIR / "benchmark_agentpy" / "logs",
    "agentsjl": BASE_DIR / "benchmark_agentsjl" / "logs",
}

COLORS = {
    "mesa": "#150b5e",
    "agentpy": "#333338",
    "agentsjl": "#602985",
}

OUTPUT_DIR = BASE_DIR / "plots"
OUTPUT_DIR.mkdir(exist_ok=True)

# ============================================================
# Regex patterns
# ============================================================
TIME_RE = re.compile(r"Całkowity czas pętli:\s*([0-9.]+)")
FPS_RE = re.compile(r"Średnia wydajność:\s*([0-9.]+)")
STEP_RE = re.compile(r"Średni czas kroku:\s*([0-9.]+)")
AGENTS_RE = re.compile(r"run_(\d+)\.log")

# ============================================================
# Data extraction
# ============================================================
rows = []

for platform, log_dir in PLATFORMS.items():
    if not log_dir.exists():
        print(f"⚠️  Missing directory: {log_dir}")
        continue

    for log_file in log_dir.glob("run_*.log"):
        match = AGENTS_RE.search(log_file.name)
        if not match:
            continue

        agents = int(match.group(1))
        text = log_file.read_text(encoding="utf-8", errors="ignore")

        time_m = TIME_RE.search(text)
        fps_m = FPS_RE.search(text)
        step_m = STEP_RE.search(text)

        if not (time_m and fps_m and step_m):
            print(f"⚠️  Failed to parse {log_file}")
            continue

        rows.append({
            "platform": platform,
            "agents": agents,
            "time_sec": float(time_m.group(1)),
            "fps": float(fps_m.group(1)),
            "step_time": float(step_m.group(1)),
        })

df = pd.DataFrame(rows)
df = df.sort_values("agents")

print("✔ Parsed data:")
print(df)

# ============================================================
# Plot helper
# ============================================================
def plot_metric(y_col, y_label, title, filename):
    plt.figure(figsize=(8, 5))

    for platform in df["platform"].unique():
        subset = df[df["platform"] == platform]
        plt.plot(
            subset["agents"],
            subset[y_col],
            marker="o",
            label=platform
        )

    # plt.xscale("log")
    plt.xlabel("Liczba agentów")
    plt.ylabel(y_label)
    plt.title(title)
    plt.grid(True, which="both", linestyle="--", alpha=0.5)
    plt.legend()
    plt.tight_layout()

    out = OUTPUT_DIR / filename
    plt.savefig(out, dpi=150)
    plt.close()

    print(f"📈 Saved: {out}")

# ============================================================
# Generate plots
# ============================================================
plot_metric(
    "time_sec",
    "Czas symulacji [s]",
    "Czas symulacji vs liczba agentów",
    "time_vs_agents.png",
)

plot_metric(
    "fps",
    "Kroki na sekundę",
    "Średnia częstotliwość kroku symulacji vs liczba agentów",
    "fps_vs_agents.png",
)

plot_metric(
    "step_time",
    "Średni czas kroku [s]",
    "Średni czas kroku vs liczba agentów",
    "step_time_vs_agents.png",
)

print("All plots generated")
