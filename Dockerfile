# syntax=docker/dockerfile:1
# Raccoon Studio — RunPod pre-installed image ("Raccoon Studio Version 1.2").
#
# The counterpart to the thin template, not a replacement: that one boots stock
# ubuntu and installs on the pod, this one ships the finished install so a pod
# reaches a login page in seconds instead of 6–25 minutes.
#
# The build CONTEXT is always this repo checked out at a release TAG (see
# .github/workflows/runpod-image.yml), never a branch — so an image can only
# ever contain content that was published and tested under a version number.
#
# Base is plain ubuntu:24.04, NOT nvidia/cuda: the cu128 torch wheels carry
# their own CUDA runtime and only the driver comes from the host. The thin
# template has run exactly this base live since v1.2.0, so that is measured
# rather than assumed — and it saves ~3 GB of duplicated CUDA libraries.
FROM ubuntu:24.04

# $RACCOON_ROOT must NOT be under /workspace. RunPod mounts the volume there and
# the mount hides whatever the image baked underneath it — an install at
# /workspace/raccoon would simply vanish on first boot. Both entrypoint.sh and
# the app read this variable, so /opt is pure env wiring.
ENV DEBIAN_FRONTEND=noninteractive \
    RACCOON_ROOT=/opt/raccoon \
    RACCOON_WORKSPACE=/workspace

# Only what install-linux.sh needs before it can install everything else itself.
# python3.12 is included so the installer's deadsnakes-PPA branch never fires:
# noble already ships the package and deadsnakes has no noble build, so that
# path is a guaranteed-wasted network round trip.
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      ca-certificates curl git python3.12 python3.12-venv \
 && rm -rf /var/lib/apt/lists/*

COPY . /opt/raccoon
WORKDIR /opt/raccoon

# The ordinary desktop installer, unchanged, baked into the image. It is
# idempotent (that is what the Repair button needs) and it handles root with no
# sudo binary, so a container is already a supported shape for it.
#
#   RS_FROM_ENGINE=1  no tty on a build runner — skips the "relaunch me in a
#                     terminal" block that would otherwise re-exec.
#   --gpu=nvidia      there is no nvidia-smi at build time, so auto-detect would
#                     resolve to the CPU stack and bake CPU torch. Forcing it
#                     keeps the cu128 wheels; the "No GPU acceleration" warning
#                     the installer prints at the end is expected here and does
#                     not fail the build.
#   --skip-controlnet ~9 GB the Models page fetches on demand, matching the
#                     desktop installer's own opt-in default.
#
# The caches go in the SAME layer they were filled in, which is the only place
# deleting them shrinks anything — uv holds a second copy of the 2.5 GB torch
# download and npm keeps its own, so this is several GB off both the finished
# image and the build's peak disk. Nothing needs them afterwards: the venv and
# node_modules are already populated.
RUN RS_FROM_ENGINE=1 bash install-linux.sh --gpu=nvidia --skip-controlnet \
 && rm -rf /root/.cache /root/.npm

# The installer deliberately never builds — desktop installs run `next dev` —
# but entrypoint.sh needs .next/BUILD_ID to run `next start`, and a rented GPU
# deserves the production build.
#
# RACCOON_KIOSK has to be set for the BUILD, not only the run: statically
# rendered routes read process.env at build time, so a flag exported only by the
# entrypoint comes out false in exactly the pages that need it.
RUN cd app && RACCOON_KIOSK=1 npm run build

# Informational — RunPod publishes ports from the template, not from here.
EXPOSE 8080

# No boot.sh: there is nothing left to install. entrypoint.sh wires the volume,
# starts ComfyUI and Next on loopback, and hands the foreground to the proxy.
CMD ["bash", "/opt/raccoon/runpod/entrypoint.sh"]
