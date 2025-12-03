FROM julia:1.12.2

WORKDIR /app

COPY predator_prey.jl .

RUN julia -e 'using Pkg; Pkg.add.(["Agents", "Random", "Statistics"])'

ENTRYPOINT ["julia", "/app/predator_prey.jl"]
