# Raccoon Studio — RunPod image recipe

Build recipe for `ghcr.io/finoo125/raccoon-studio-runpod`, the pre-installed
container image behind the **Raccoon Studio Version 1.2** RunPod template.

**The application lives in [Finoo125/raccoon-studio](https://github.com/Finoo125/raccoon-studio).**
This repo holds only the Dockerfile and the workflow that builds it. Nothing
here ends up inside the image except the build instructions themselves — the
image's contents are that repo, checked out at a published release tag.

## Why it is separate

Keeping the recipe out of the app repo means a Dockerfile change is a commit and
a workflow dispatch, rather than an app release — which would prompt every
desktop installation to re-run its installer for a change that cannot affect it.
It also owns the GHCR package, and GHCR grants push rights from the package's
linked repository, so this is the only place a build can push without borrowing
a credential.

## Building

Actions → **RunPod image** → *Run workflow*, with the published version to build
(e.g. `1.2.3`). It pushes `ghcr.io/finoo125/raccoon-studio-runpod:<version>`.

The optional `dockerfile`, `tag` and `compression` inputs exist for pull-speed
experiments; their defaults reproduce the shipping image exactly.

## Where a pod's boot time goes

Measured 2026-08-20 from RunPod's own system log:

| phase | |
|---|---|
| image pull + extract | **373 s — 97% of the boot** |
| container start | +2 s |
| entrypoint → ComfyUI → `next start` → login page | **+10 s** |

So the install-in-the-image design does exactly what it promised: the app is up
seconds after the container starts, and a host that already has the image boots
the whole studio in **34 s**. Everything else is one 10.6 GB download, paid once
per machine.

Cold boots measured **383 s** and **562 s** on two Community Cloud hosts — those
are individually owned machines on ordinary connections, and the ~180 s spread
between them is the host's uplink, not anything about the image.

## Experiments, and what came of them

Both were attempts to shorten that download. Neither shipped.

- **zstd layers** (`compression: zstd`) — 6.4% smaller (10.65 → 9.97 GB) and
  faster to decompress in principle. **Rejected:** a pod on the zstd image ran
  24 minutes without ever serving a page, on a host that had done the gzip image
  in 562 s. The mechanism was never identified — RunPod exposes no log API and
  the console keeps only the last ~99 lines — but a variant that will not boot is
  not shippable.
- **`Dockerfile.split`** — cuts the single 10.57 GB layer in two by seeding torch
  and its CUDA libraries in an earlier layer, so the two can download in
  parallel. **Built and correct, but never measured**, and it is not what the
  template uses. Measuring it honestly needs both images rebuilt so neither is
  cached on the candidate hosts, plus several paired pods; that was not worth the
  spend against a cost users pay once per machine. Kept here because the approach
  is sound and the two traps in it are written down in the file.

A methodology note for anyone repeating this: **do not deploy the variants
concurrently.** Six simultaneous pulls of a 10 GB image saturate the very
resource under test — nothing had booted at 1400 s on hosts that managed 383 s
alone.
