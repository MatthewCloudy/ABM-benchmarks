#!/usr/bin/env bash
set -e

# ============================================================
#  Paths (independent of where script is run from)
# ============================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ============================================================
#  Input
# ============================================================
PLATFORM="$1"

if [ -z "$PLATFORM" ]; then
  echo "Usage: ./benchmark.sh <mesa|agentsjl|gama>"
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

if [ -z "${DOCKERFILE[$PLATFORM]}" ]; then
  echo "Unknown platform: $PLATFORM"
  echo "Available platforms: ${!DOCKERFILE[@]}"
  exit 1
fi

if [ ! -f "${DOCKERFILE[$PLATFORM]}" ]; then
  echo "Dockerfile not found: ${DOCKERFILE[$PLATFORM]}"
  exit 1
fi

# ============================================================
#  Benchmark configuration
# ============================================================
IMAGE_NAME="abm-${PLATFORM}"

AGENT_LIST=(100 1000 10000 100000)
PREY_RATIO=0.8
STEPS=2000

INTERVAL=0.5          # seconds between samples
STARTUP_DELAY=0.2     # wait after container start
MIN_SAMPLES=5         # guarantee minimum samples
WARMUP=true           # first run ignored

OUT_DIR="$PROJECT_ROOT/benchmarks/benchmark_${PLATFORM}"
OUT_FILE="$OUT_DIR/results.csv"

mkdir -p "$OUT_DIR"

# ============================================================
#  CSV header
# ============================================================
echo "platform,agents,preys,predators,avg_cpu,max_cpu,avg_mem_mb,max_mem_mb" \
  > "$OUT_FILE"

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
for AGENTS in "${AGENT_LIST[@]}"; do

  PREYS=$(printf "%.0f" "$(echo "$AGENTS * $PREY_RATIO" | bc)")
  PREDATORS=$((AGENTS - PREYS))

  echo "▶ Benchmark: agents=$AGENTS (prey=$PREYS predator=$PREDATORS)"

  for RUN in warmup real; do

    if [ "$RUN" = "warmup" ] && [ "$WARMUP" = true ]; then
      echo "  → Warm-up run (ignored)"
    elif [ "$RUN" = "warmup" ]; then
      continue
    else
      echo "  → Measured run"
    fi

    CID=$(docker run -d \
      "$IMAGE_NAME" \
      --steps "$STEPS" \
      --preys "$PREYS" \
      --predators "$PREDATORS")

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

    if [ "$RUN" = "real" ]; then
      AVG_CPU=$(printf "%s\n" "${CPU_VALUES[@]}" | awk '{s+=$1} END {print (NR>0)?s/NR:0}')
      MAX_CPU=$(printf "%s\n" "${CPU_VALUES[@]}" | sort -nr | head -1)

      AVG_MEM=$(printf "%s\n" "${MEM_VALUES[@]}" | awk '{s+=$1} END {print (NR>0)?s/NR:0}')
      MAX_MEM=$(printf "%s\n" "${MEM_VALUES[@]}" | sort -nr | head -1)

      echo "$PLATFORM,$AGENTS,$PREYS,$PREDATORS,$AVG_CPU,$MAX_CPU,$AVG_MEM,$MAX_MEM" \
        >> "$OUT_FILE"
    fi

  done

  echo "✔ Done: agents=$AGENTS"
done

echo "✅ Benchmark finished"
echo "📄 Results saved to: $OUT_FILE"
