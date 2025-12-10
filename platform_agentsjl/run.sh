#!/bin/bash

IMAGE_NAME="agents_test"
CONTAINER_NAME="agents_bench"

AGENTS_LIST=(100 1000 10000 100000)
STEPS=500
RATIO=0.2
DIMS="20x20"

SLEEP_INTERVAL=0.1
RESULTS_DIR="results"
mkdir -p $RESULTS_DIR

echo "=== Building Docker image ==="
docker build -t $IMAGE_NAME .

run_single_test() {
    local AGENTS=$1
    local OUTFILE="$RESULTS_DIR/metrics_agents${AGENTS}.csv"
    local LOGFILE="logs/output_agents${AGENTS}.log"

    echo "timestamp,cpu_percent,mem_mb" > "$OUTFILE"

    echo "=== Start test for agents=$AGENTS ==="

    # Uruchomienie kontenera z zamontowanym wolumenem
    docker run --rm --name "$CONTAINER_NAME" \
        -v $(pwd)/logs:/logs \
        "$IMAGE_NAME" \
        "agents=$AGENTS" "ratio=$RATIO" "steps=$STEPS" "dims=$DIMS" \
        > "$LOGFILE" 2>&1 &

    sleep 0.2

    # Pomiar zasobów
    while docker inspect -f '{{.State.Running}}' "$CONTAINER_NAME" 2>/dev/null | grep -q true; do
        LINE=$(docker stats --no-stream --format "{{.CPUPerc}},{{.MemUsage}}" "$CONTAINER_NAME")
        [[ -z "$LINE" ]] && break

        CPU=$(echo "$LINE" | cut -d',' -f1 | tr -d '%')
        MEM=$(echo "$LINE" | cut -d',' -f2 | awk '{print $1}' | sed 's/MiB//')
        TS=$(date +%s)

        echo "$TS,$CPU,$MEM" >> "$OUTFILE"
        sleep $SLEEP_INTERVAL
    done

    echo "Finished test → $OUTFILE (log: $LOGFILE)"
}


# Pętla główna
for A in "${AGENTS_LIST[@]}"; do
    run_single_test "$A"
done

echo "=== ALL TESTS COMPLETED ==="
