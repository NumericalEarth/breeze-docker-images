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

RUN julia --color=yes -e 'using InteractiveUtils; versioninfo()'

# Clone Breeze
RUN git clone --depth=1 https://github.com/NumericalEarth/Breeze.jl /tmp/Breeze.jl

# Instantiate docs environment
RUN . /julia_cpu_target.sh && julia --color=yes --project=/tmp/Breeze.jl/docs -e 'using Pkg; Pkg.instantiate(); using CUDA; CUDA.set_runtime_version!(v"13"); CUDA.precompile_runtime()'
# Instantiate test environment (we need to use the same flags as used on CI)
RUN . /julia_cpu_target.sh && julia --color=yes --project=/tmp/Breeze.jl/test --check-bounds=yes --warn-overwrite=yes --depwarn=yes --inline=yes --startup-file=no -e 'using Pkg; Pkg.instantiate(); using CUDA; CUDA.set_runtime_version!(v"13"); CUDA.precompile_runtime()'

# Clean up Breeze clone
RUN rm -rf /tmp/Breeze.jl
