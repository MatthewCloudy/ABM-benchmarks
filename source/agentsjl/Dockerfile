FROM julia:1.12.2

WORKDIR /app

COPY model.jl .

RUN julia -e 'using Pkg; Pkg.add(["Agents", "Statistics", "Random", "Dates", "ArgParse"])'

ENTRYPOINT ["julia", "/app/model.jl"]
