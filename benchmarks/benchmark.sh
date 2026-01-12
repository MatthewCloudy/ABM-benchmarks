#!/usr/bin/env bash
set -e

# ============================================================
#  Paths
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ============================================================
#  Input
# ============================================================
PLATFORM="$1"

if [ -z "$PLATFORM" ]; then
  echo "Usage: ./benchmark.sh <mesa|agentsjl|gama|agentpy>"
  exit 1
fi

# ============================================================
#  Dockerfile + context mapping
# ============================================================
declare -A DOCKERFILE
declare -A CONTEXT

DOCKERFILE[mesa]="$PROJECT_ROOT/source/mesa/Dockerfile"
CONTEXT[mesa]="$PROJECT_ROOT/source/mesa"

DOCKERFILE[agentsjl]="$PROJECT_ROOT/source/agentsjl/Dockerfile"
CONTEXT[agentsjl]="$PROJECT_ROOT/source/agentsjl"

DOCKERFILE[gama]="$PROJECT_ROOT/source/gama/Dockerfile"
CONTEXT[gama]="$PROJECT_ROOT/source/gama"

DOCKERFILE[agentpy]="$PROJECT_ROOT/source/agentpy/Dockerfile"
CONTEXT[agentpy]="$PROJECT_ROOT/source/agentpy"

if [ -z "${DOCKERFILE[$PLATFORM]}" ]; then
  echo "Unknown platform: $PLATFORM"
  exit 1
fi

# ============================================================
#  Benchmark configuration
# ============================================================
IMAGE_NAME="abm-${PLATFORM}"

AGENT_LIST=(200 400 600 800 1000)
PREY_RATIO=0.85
CELL_DENSITY=0.15
STEPS=2000

INTERVAL=0.5
STARTUP_DELAY=0.2
MIN_SAMPLES=5

OUT_DIR="$PROJECT_ROOT/benchmarks/benchmark_${PLATFORM}"
OUT_FILE="$OUT_DIR/results.csv"
LOG_DIR="$OUT_DIR/logs"

mkdir -p "$OUT_DIR" "$LOG_DIR"

# ============================================================
#  CSV header
# ============================================================
if [ ! -f "$OUT_FILE" ]; then
  echo "platform,agents,preys,predators,grid,avg_cpu,max_cpu,avg_mem_mb,max_mem_mb" \
    > "$OUT_FILE"
fi
# ============================================================
#  Build Docker image
# ============================================================
echo "▶ Building Docker image: $IMAGE_NAME"
docker build \
  -f "${DOCKERFILE[$PLATFORM]}" \
  -t "$IMAGE_NAME" \
  "${CONTEXT[$PLATFORM]}"

# ============================================================
#  Benchmark loop
# ============================================================
FIRST_RUN=true

for AGENTS in "${AGENT_LIST[@]}"; do

  PREYS=$(printf "%.0f" "$(echo "$AGENTS * $PREY_RATIO" | bc)")
  PREDATORS=$((AGENTS - PREYS))

  CELLS=$(echo "$AGENTS / $CELL_DENSITY" | bc -l)
  GRID_SIZE=$(echo "sqrt($CELLS)" | bc -l | awk '{print int($1)}')

  echo "▶ agents=$AGENTS prey=$PREYS predator=$PREDATORS grid=${GRID_SIZE}x${GRID_SIZE}"

  # ------------------------------------------------------------
  # Warm-up run (ONLY ONCE)
  # ------------------------------------------------------------
  if [ "$FIRST_RUN" = true ]; then
    echo "  → Warm-up run (once, ignored)"

    docker run --rm \
      "$IMAGE_NAME" \
      --steps "$STEPS" \
      --preys "$PREYS" \
      --predators "$PREDATORS" \
      --grid "$GRID_SIZE" \
      >/dev/null

    FIRST_RUN=false
  fi

  # ------------------------------------------------------------
  # Measured run
  # ------------------------------------------------------------
  echo "  → Measured run"

  CID=$(docker run -d \
    "$IMAGE_NAME" \
    --steps "$STEPS" \
    --preys "$PREYS" \
    --predators "$PREDATORS" \
    --grid "$GRID_SIZE")

  sleep "$STARTUP_DELAY"

  CPU_VALUES=()
  MEM_VALUES=()
  SAMPLES=0

  while docker ps -q | grep -q "$CID" || [ "$SAMPLES" -lt "$MIN_SAMPLES" ]; do
    STATS=$(docker stats "$CID" --no-stream \
      --format "{{.CPUPerc}},{{.MemUsage}}" 2>/dev/null || true)

    if [ -n "$STATS" ]; then
      CPU=$(echo "$STATS" | cut -d',' -f1 | tr -d '%')

      RAW_MEM=$(echo "$STATS" | cut -d',' -f2 | cut -d'/' -f1)
      if [[ "$RAW_MEM" == *GiB ]]; then
        MEM=$(echo "$RAW_MEM" | sed 's/GiB//' | awk '{print $1 * 1024}')
      else
        MEM=$(echo "$RAW_MEM" | sed 's/MiB//')
      fi

      CPU_VALUES+=("$CPU")
      MEM_VALUES+=("$MEM")
      SAMPLES=$((SAMPLES + 1))
    fi

    sleep "$INTERVAL"
  done

  # Czekamy aż kontener faktycznie się zakończy
  docker wait "$CID" >/dev/null

  # Zapis pełnych logów PO zakończeniu
  LOG_FILE="$LOG_DIR/run_${AGENTS}.log"
  docker logs "$CID" > "$LOG_FILE"

  # Statystyki
  AVG_CPU=$(printf "%s\n" "${CPU_VALUES[@]}" | awk '{s+=$1} END {print (NR>0)?s/NR:0}')
  MAX_CPU=$(printf "%s\n" "${CPU_VALUES[@]}" | sort -nr | head -1)

  AVG_MEM=$(printf "%s\n" "${MEM_VALUES[@]}" | awk '{s+=$1} END {print (NR>0)?s/NR:0}')
  MAX_MEM=$(printf "%s\n" "${MEM_VALUES[@]}" | sort -nr | head -1)

  echo "$PLATFORM,$AGENTS,$PREYS,$PREDATORS,$GRID_SIZE,$AVG_CPU,$MAX_CPU,$AVG_MEM,$MAX_MEM" \
    >> "$OUT_FILE"

  echo "✔ Done: agents=$AGENTS"
done

echo "✅ Benchmark finished"
echo "📄 Results saved to: $OUT_FILE"
echo "📂 Logs saved to: $LOG_DIR"
