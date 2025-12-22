# syntax=docker/dockerfile:1
FROM julia:1.12.2

# Install some dependencies
RUN /bin/sh -c 'export DEBIAN_FRONTEND=noninteractive \
    && apt-get update \
    && apt-get install -y git jq \
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

# Follow https://github.com/JuliaGPU/CUDA.jl/blob/5d9474ae73fab66989235f7ff4fd447d5ee06f8e/Dockerfile

ARG CUDA_VERSION=13.0

# pre-install the CUDA toolkit from an artifact. we do this separately from CUDA.jl so that
# this layer can be cached independently. it also avoids double precompilation of CUDA.jl in
# order to call `CUDA.set_runtime_version!`.
RUN . /julia_cpu_target.sh && julia --color=yes -e '#= make bundled depot non-writable (JuliaLang/Pkg.jl#4120) =# \
              bundled_depot = last(DEPOT_PATH); \
              run(`find $bundled_depot/compiled -type f -writable -exec chmod -w \{\} \;`); \
              #= configure the preference =# \
              env = "/usr/local/share/julia/environments/v$(VERSION.major).$(VERSION.minor)"; \
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
    find /usr/local/share/julia/environments -name Project.toml -exec sed -i 's/deps/extras/' {} + && \
    #= remove nondeterminisms =# \
    find -exec touch -h -d "@0" {} + && \
    touch -h -d "@0" /usr/local/share

# install CUDA.jl itself
RUN . /julia_cpu_target.sh && julia --color=yes -e 'using Pkg; Pkg.add("CUDA"); \
              using CUDA; CUDA.precompile_runtime()'

# # Clone Breeze
# RUN git clone --depth=1 https://github.com/NumericalEarth/Breeze.jl /tmp/Breeze.jl

# # Instantiate docs environment
# RUN . /julia_cpu_target.sh && julia --color=yes --project=/tmp/Breeze.jl/docs -e 'using Pkg; Pkg.instantiate(); using CUDA; CUDA.set_runtime_version!(v"13.1"); CUDA.precompile_runtime(); Base.compilecache(Base.PkgId(Base.UUID("76a88914-d11a-5bdc-97e0-2f5a05c973a2"), "CUDA_Runtime_jll"))'
# # Instantiate test environment (we need to use the same flags as used on CI)
# RUN . /julia_cpu_target.sh && julia --color=yes --project=/tmp/Breeze.jl/test --check-bounds=yes --warn-overwrite=yes --depwarn=yes --inline=yes --startup-file=no -e 'using Pkg; Pkg.instantiate(); using CUDA; CUDA.set_runtime_version!(v"13.1"); CUDA.precompile_runtime(); Base.compilecache(Base.PkgId(Base.UUID("76a88914-d11a-5bdc-97e0-2f5a05c973a2"), "CUDA_Runtime_jll"))'

# # Clean up Breeze clone
# RUN rm -rf /tmp/Breeze.jl
