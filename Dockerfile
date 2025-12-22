# syntax=docker/dockerfile:1
FROM julia:1.12.2

# Install some dependencies
RUN /bin/sh -c 'export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get install -y ca-certificates earlyoom git gpg jq \
    && apt-get --purge autoremove -y \
    && apt-get autoclean \
    && rm -rf /var/lib/apt/lists/*'

# Docker is awful and doesn't allow conditionally setting environment variables in a decent
# way, so we have to keep an external script and source it every time we need it.
COPY julia_cpu_target.sh /julia_cpu_target.sh

# Explicitly set the Julia depot path: on GitHub Actions the user's home
# directory may be somewhere else (e.g. `/github`), so we need to be sure we
# have a consistent and persistent depot path.
ENV JULIA_DEPOT_PATH=/usr/local/share/julia:
# Set a default version-independent project.
ENV JULIA_PROJECT='@breeze'
# Add the environment to the load path
ENV JULIA_LOAD_PATH=:${JULIA_PROJECT}

# Follow https://github.com/JuliaGPU/CUDA.jl/blob/5d9474ae73fab66989235f7ff4fd447d5ee06f8e/Dockerfile

ARG CUDA_VERSION=13.0

# pre-install the CUDA toolkit from an artifact. we do this separately from CUDA.jl so that
# this layer can be cached independently. it also avoids double precompilation of CUDA.jl in
# order to call `CUDA.set_runtime_version!`.
RUN . /julia_cpu_target.sh && julia --color=yes -e '#= make bundled depot non-writable (JuliaLang/Pkg.jl#4120) =# \
              bundled_depot = last(DEPOT_PATH); \
              run(`find $bundled_depot/compiled -type f -writable -exec chmod -w \{\} \;`); \
              #= configure the preference =# \
              env = "/usr/local/share/julia/environments/breeze"; \
              mkpath(env); \
              write("$env/LocalPreferences.toml", \
                    "[CUDA_Runtime_jll]\nversion = \"'${CUDA_VERSION}'\""); \
              \
              #= install the JLL =# \
              using Pkg; \
              Pkg.add("CUDA_Runtime_jll"); \
              #= revert bundled depot changes =# \
              run(`find $bundled_depot/compiled -type f -writable -exec chmod +w \{\} \;`)' && \
    #= demote the JLL to an [extras] dep =# \
    find /usr/local/share/julia/environments -name Project.toml -exec sed -i 's/deps/extras/' {} +

# install CUDA.jl itself, for both configurations
RUN . /julia_cpu_target.sh && julia --color=yes -e 'using Pkg; Pkg.add("CUDA"); \
    using CUDA; CUDA.precompile_runtime()'
RUN . /julia_cpu_target.sh && julia --color=yes --check-bounds=yes -e 'using Pkg; Pkg.add("CUDA"); \
    using CUDA; CUDA.precompile_runtime()'

# Clone Breeze
RUN git clone --depth=1 https://github.com/NumericalEarth/Breeze.jl /tmp/Breeze.jl

# Instantiate docs environment
RUN . /julia_cpu_target.sh && julia --color=yes --project=/tmp/Breeze.jl/docs -e 'using Pkg; Pkg.instantiate()'
# Instantiate test environment (we need to use the same flags as used when
# running the tests)
RUN cp /usr/local/share/julia/environments/breeze/LocalPreferences.toml /tmp/Breeze.jl/test/.
RUN . /julia_cpu_target.sh && julia --color=yes --project=/tmp/Breeze.jl/test --check-bounds=yes -e 'using Pkg; Pkg.instantiate()'

# Clean up Breeze clone
RUN rm -rf /tmp/Breeze.jl
