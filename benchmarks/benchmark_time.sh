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
  echo "Usage: ./benchmark_time.sh <mesa|agentsjl|gama|agentpy>"
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

AGENT_LIST=(500 1000)
PREY_RATIO=0.8
CELL_DENSITY=0.2
STEPS=1000

OUT_DIR="$PROJECT_ROOT/benchmarks/benchmark_${PLATFORM}"
OUT_FILE="$OUT_DIR/benchmark_time.csv"
LOG_DIR="$OUT_DIR/logs"

mkdir -p "$OUT_DIR" "$LOG_DIR"

# ============================================================
#  CSV header
# ============================================================
echo "platform,agents,preys,predators,grid,time_seconds,fps" \
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
FIRST_RUN=true

for AGENTS in "${AGENT_LIST[@]}"; do

  PREYS=$(printf "%.0f" "$(echo "$AGENTS * $PREY_RATIO" | bc)")
  PREDATORS=$((AGENTS - PREYS))

  CELLS=$(echo "$AGENTS / $CELL_DENSITY" | bc -l)
  GRID_SIZE=$(echo "sqrt($CELLS)" | bc -l | awk '{print int($1)}')

  echo "▶ agents=$AGENTS prey=$PREYS predator=$PREDATORS grid=${GRID_SIZE}x${GRID_SIZE}"

  # ------------------------------------------------------------
  # Warm-up run (ONLY ONCE, for first agent count)
  # ------------------------------------------------------------
  if [ "$FIRST_RUN" = true ]; then
    echo "  → Warm-up run (only once)"

    docker run --rm \
      "$IMAGE_NAME" \
      --steps "$STEPS" \
      --preys "$PREYS" \
      --predators "$PREDATORS" \
      --grid "$GRID_SIZE" \
      > "$LOG_DIR/warmup.log"

    FIRST_RUN=false
  fi

  # ------------------------------------------------------------
  # Measured run
  # ------------------------------------------------------------
  echo "  → Measured run"

  LOG_FILE="$LOG_DIR/run_${AGENTS}.log"

  docker run --rm \
    "$IMAGE_NAME" \
    --steps "$STEPS" \
    --preys "$PREYS" \
    --predators "$PREDATORS" \
    --grid "$GRID_SIZE" \
    > "$LOG_FILE"

  TIME=$(grep -E "Całkowity czas pętli" "$LOG_FILE" | \
    sed -E 's/.*: *([0-9.]+).*/\1/')

  FPS=$(grep -E "Średnia wydajność" "$LOG_FILE" | \
    sed -E 's/.*: *([0-9.]+).*/\1/')

  if [ -z "$TIME" ] || [ -z "$FPS" ]; then
    echo "⚠️  Failed to parse time/FPS for agents=$AGENTS"
    continue
  fi

  echo "$PLATFORM,$AGENTS,$PREYS,$PREDATORS,$GRID_SIZE,$TIME,$FPS" \
    >> "$OUT_FILE"

  echo "✔ Done: agents=$AGENTS"
done

echo "✅ Time benchmark finished"
echo "📄 Results saved to: $OUT_FILE"
