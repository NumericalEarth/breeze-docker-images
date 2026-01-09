# Docker images for Breeze.jl

This repo contains [Docker images](https://github.com/NumericalEarth/breeze-docker-images/pkgs/container/breeze-docker-images) to be used for the Julia package [`Breeze.jl`](https://github.com/NumericalEarth/Breeze.jl).

## `Dockerfile`

The [`Dockerfile`](./Dockerfile) precompiles environments of `Breeze.jl` (`docs` and `test`), used to speed up continuous integration (CI) jobs, with [`CUDA.jl`](https://github.com/JuliaGPU/CUDA.jl) configured to target GPUs.

## Deployment

A [GitHub Actions workflow](./.github/workflows/DockerPublish.yml) builds two images on regular (non-GPU) GitHub-hosted runners:

* `ghcr.io/numericalearth/breeze-docker-images:docs` to precompile the `docs` environment with the Julia flag `--check-bounds=auto`
* `ghcr.io/numericalearth/breeze-docker-images:test` to precompile the `test` environment with the Julia flag `--check-bounds=yes`

### For `Breeze.jl` developers: trigger deployments

A new deployment is done automatically on schedule every week, to keep the images up-to-date.
If for some reason you want to force a new deployment (e.g. to get updated packages in the image), go to the [workflow page](https://github.com/NumericalEarth/breeze-docker-images/actions/workflows/DockerPublish.yml), and click on the "Run workflow" button.
