#FROM gamaplatform/gama:latest
#WORKDIR /workspace

#COPY KodGamaPodDockera.gaml /workspace/model.gaml


#ENTRYPOINT ["/opt/gama-platform/headless/gama-headless.sh", "-m", "2048m", "-v", "-batch", "prey_predator", "model.gaml"]


FROM gamaplatform/gama:latest

WORKDIR /workspace

# Kopiujemy model do obrazu
COPY KodGamaPodDockera.gaml /workspace/model.gaml

# Ustawiamy punkt wejścia na skrypt GAMA, ale NIE podajemy argumentów.
# Argumenty poda nasz skrypt Bash.
ENTRYPOINT ["/opt/gama-platform/headless/gama-headless.sh"]
