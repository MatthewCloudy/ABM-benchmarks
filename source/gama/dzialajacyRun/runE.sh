#!/bin/bash

IMAGE_NAME="gama_bench"
RESULTS_DIR="results_gama"

# Upewniamy się, że folder na wyniki istnieje
mkdir -p $RESULTS_DIR

# Budowanie obrazu (dla pewności, że jest aktualny)
echo "=== Sprawdzanie obrazu Docker ==="
docker build -t $IMAGE_NAME .
if [ $? -ne 0 ]; then
    echo "Błąd budowania obrazu Docker. Sprawdź Dockerfile."
    exit 1
fi

# Lista liczby ofiar do przetestowania
AGENTS_LIST=(220 500)
STEPS=2000

# Nagłówek pliku CSV
echo "timestamp,agents,duration_sec,fps" > "$RESULTS_DIR/gama_metrics.csv"

run_test() {
    local PREYS=$1
    local PREDATORS=$((PREYS / 10))
    local CONFIG_FILE="config_${PREYS}.xml"

    echo "=== Start test: Prey=$PREYS, Pred=$PREDATORS ==="

    # 1. GENEROWANIE PLIKU XML
    # sourcePath musi wskazywać na /workspace/model.gaml (tak jak w Dockerfile)
    cat <<EOF > $CONFIG_FILE
<?xml version="1.0" encoding="UTF-8"?>
<Experiment_plan>
    <Simulation id="1" sourcePath="/workspace/model.gaml" finalStep="$STEPS" experiment="prey_predator">
        <Parameters>
            <Parameter name="Preys Init" type="INT" value="$PREYS" />
            <Parameter name="Predators Init" type="INT" value="$PREDATORS" />
            <Parameter name="Steps" type="INT" value="$STEPS" />
        </Parameters>
    </Simulation>
</Experiment_plan>
EOF

    # 2. URUCHOMIENIE DOCKERA
    # ZMIANA: Usunięto flagę "-xml". 
    # Składnia to: nazwa_obrazu plik_wejsciowy plik_wyjsciowy
    LOG_FILE="$RESULTS_DIR/output_${PREYS}.log"

docker run --rm \
  -v "$(pwd)/$CONFIG_FILE:/workspace/input.xml" \
  -v "$(pwd)/$RESULTS_DIR:/workspace/output" \
  "$IMAGE_NAME" \
  /workspace/input.xml /workspace/output 2>&1 | tee "$LOG_FILE"

DURATION=$(grep "Calkowity czas petli" "$LOG_FILE" | awk '{print $4}')
FPS=$(grep "Srednia wydajnosc" "$LOG_FILE" | awk '{print $3}')

    TS=$(date +%s)

    # Jeśli zmienne są puste (np. błąd GAMA), wpisz NaN
    if [[ -z "$DURATION" ]]; then DURATION="NaN"; fi
    if [[ -z "$FPS" ]]; then FPS="NaN"; fi

    echo "Wynik: Czas=$DURATION s, FPS=$FPS"
    echo "$TS,$PREYS,$DURATION,$FPS" >> "$RESULTS_DIR/gama_metrics.csv"

    # Sprzątanie
    rm $CONFIG_FILE
}

for A in "${AGENTS_LIST[@]}"; do
    run_test "$A"
done

echo "=== WSZYSTKIE TESTY ZAKONCZONE ==="
echo "Wyniki w pliku: $RESULTS_DIR/gama_metrics.csv"
