# Homarr Rich iCal image

This repository builds a stock Homarr release with one deliberate source replacement: the upstream iCal integration is replaced with a Seanime-aware adapter before Homarr's own Dockerfile is built.

The adapter in `patches/ical-integration.rich.ts` preserves calendar images, colors, event URLs, and styled Seanime/AniList links. The build fails if Homarr moves the upstream adapter path or the replacement produces no diff.

## Images

- Exact release: `ghcr.io/hyperclaw79/homarr:<version>-rich-ical`
- Current channel: `ghcr.io/hyperclaw79/homarr:rich-ical`

Exact tags are immutable by convention. Pin an exact tag for deterministic deployments and rollback; use `rich-ical` only when automatic updates are wanted.

## Automatic releases

GitHub Actions checks the latest stable `homarr-labs/homarr` release every six hours. If the exact GHCR tag is absent, it builds the patched source with Homarr's stock Dockerfile and pushes the exact image. Only a successful exact publication can advance the moving tag.

Pushes and pull requests perform dry builds. The workflow can also be run manually with a specific Homarr version. Details are in `docs/release-automation.md`.

Published builds require the repository Actions secret `SEANIME_ICON_URL`. The committed source contains only `__SEANIME_ICON_URL__`; CI injects the secret after producing the redacted diff artifact. GitHub masks the secret in logs, but the URL is necessarily present in the final client image and may be observable in browser network requests.

## Local dry build

With Git, Docker, and Buildx available:

```bash
export SEANIME_ICON_URL="https://your-seanime-host.example/icons/favicon.ico"
version="$(bash scripts/resolve-homarr-version.sh)"
bash scripts/build-rich-ical.sh --homarr-version "$version" --load
```

Use `bash scripts/build-rich-ical.sh --help` for registry, image, platform, and work-directory options. Work directories are disposable and recreated for clean builds.

## Build evidence

Each run uploads `build-metadata.json` and `artifacts/homarr-rich-ical.patch.diff`. The diff intentionally retains the icon placeholder rather than the configured secret value.

## Scope

This repository publishes images only. It does not access Arcane, redeploy Homarr, edit a NAS compose stack, run Watchtower, connect over SSH, or communicate with the local Forgejo instance.

Homarr is licensed under Apache-2.0. This project carries a modified integration source derived from Homarr and preserves the same license.

