import re
import pathlib
import pandas as pd
import matplotlib.pyplot as plt

# ============================================================
# Configuration
# ============================================================
BASE_DIR = pathlib.Path(".")
OUTPUT_DIR = BASE_DIR / "plots"
OUTPUT_DIR.mkdir(exist_ok=True)

PLATFORMS = ["mesa", "agentpy", "agentsjl"]

COLORS = {
    "mesa": "#9F8383",
    "agentpy": "#E8B176",
    "agentsjl": "#602985",
}

# ============================================================
# Regex patterns (logs)
# ============================================================
TIME_RE = re.compile(r"Całkowity czas pętli:\s*([0-9.]+)")
FPS_RE = re.compile(r"Średnia wydajność:\s*([0-9.]+)")
STEP_RE = re.compile(r"Średni czas kroku:\s*([0-9.]+)")
AGENTS_RE = re.compile(r"run_(\d+)\.log")

# ============================================================
# Load CPU / RAM CSVs
# ============================================================
cpu_rows = []

for platform in PLATFORMS:
    csv_path = BASE_DIR / f"benchmark_{platform}" / "results.csv"
    if not csv_path.exists():
        print(f"⚠️ Missing CSV: {csv_path}")
        continue

    df = pd.read_csv(csv_path)
    df["platform"] = platform
    cpu_rows.append(df)

cpu_df = pd.concat(cpu_rows, ignore_index=True)

# ============================================================
# Parse log files (time / fps / step)
# ============================================================
time_rows = []

for platform in PLATFORMS:
    log_dir = BASE_DIR / f"benchmark_{platform}" / "logs"
    if not log_dir.exists():
        print(f"⚠️ Missing logs dir: {log_dir}")
        continue

    for log_file in log_dir.glob("run_*.log"):
        m = AGENTS_RE.search(log_file.name)
        if not m:
            continue

        agents = int(m.group(1))
        text = log_file.read_text(encoding="utf-8", errors="ignore")

        t = TIME_RE.search(text)
        f = FPS_RE.search(text)
        s = STEP_RE.search(text)

        if not (t and f and s):
            print(f"⚠️ Failed to parse {log_file}")
            continue

        time_rows.append({
            "platform": platform,
            "agents": agents,
            "time_sec": float(t.group(1)),
            "fps": float(f.group(1)),
            "step_time": float(s.group(1)),
        })

time_df = pd.DataFrame(time_rows)

# ============================================================
# Merge everything
# ============================================================
df = pd.merge(cpu_df, time_df, on=["platform", "agents"], how="inner")
df = df.sort_values("agents")

print("✔ Combined data:")
print(df)

# ============================================================
# Plot helper
# ============================================================
def plot_metric(y_col, y_label, title, filename):
    plt.figure(figsize=(8, 5))

    for platform in PLATFORMS:
        subset = df[df["platform"] == platform]
        if subset.empty:
            continue

        plt.plot(
            subset["agents"],
            subset[y_col],
            marker="o",
            color=COLORS[platform],
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
plot_metric("avg_cpu", "Średnie CPU [%]", "Średnie CPU vs liczba agentów", "avg_cpu.png")
plot_metric("max_cpu", "Maksymalne CPU [%]", "Maksymalne CPU vs liczba agentów", "max_cpu.png")

plot_metric("avg_mem_mb", "Średni RAM [MiB]", "Średni RAM vs liczba agentów", "avg_ram.png")
plot_metric("max_mem_mb", "Maksymalny RAM [MiB]", "Maksymalny RAM vs liczba agentów", "max_ram.png")

plot_metric("time_sec", "Czas symulacji [s]", "Czas symulacji vs liczba agentów", "time.png")
plot_metric("fps", "Kroki / s", "Częstotliwość kroku vs liczba agentów", "fps.png")
plot_metric("step_time", "Czas kroku [s]", "Średni czas kroku vs liczba agentów", "step_time.png")

print("All plots generated")
