# Raccoon Studio — RunPod image recipe

Build recipe for `ghcr.io/finoo125/raccoon-studio-runpod`, the pre-installed
container image behind the **Raccoon Studio Version 1.2** RunPod template.

**The application lives in [Finoo125/raccoon-studio](https://github.com/Finoo125/raccoon-studio).**
This repo holds only the Dockerfile and the workflow that builds it. Nothing
here ends up inside the image except the build instructions themselves — the
image's contents are that repo, checked out at a published release tag.

## Why it is separate

Two RunPod templates exist, and this one is the fat half:

| template | first boot | how |
|---|---|---|
| thin | 375–1040 s | stock `ubuntu:24.04`, installs onto the volume on the pod |
| **pre-installed (this)** | ~383 s, of which **10 s is the app** | the install ships inside the image |

Keeping the recipe out of the app repo means a Dockerfile change is a commit and
a workflow dispatch, rather than an app release — which would prompt every
desktop installation to re-run its installer for a change that cannot affect it.

## Building

Actions → **RunPod image** → *Run workflow*, with the published version to build
(e.g. `1.2.3`). It pushes `ghcr.io/finoo125/raccoon-studio-runpod:<version>`.

The three optional inputs (`dockerfile`, `tag`, `compression`) exist for
pull-speed experiments; their defaults reproduce the shipping image exactly.

## Where the time goes

A pod's boot is almost entirely the registry pull — measured 2026-08-20 from
RunPod's own system log:

| phase | |
|---|---|
| image pull + extract | **373 s** |
| container start | +2 s |
| entrypoint → ComfyUI → `next start` → login page | **+10 s** |

So the install-in-the-image design does what it promised; the remaining cost is
moving ~10.6 GB out of a registry. `Dockerfile.split` is the variant that cuts
the single 10.57 GB layer in two so it can download in parallel.
