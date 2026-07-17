# Release automation

GitHub Actions checks `homarr-labs/homarr` for its latest stable release every six hours. A scheduled run resolves the upstream release directly rather than relying on `HOMARR_VERSION`.

For a newly detected version, the workflow:

1. Verifies whether `ghcr.io/hyperclaw79/homarr:<version>-rich-ical` already exists.
2. Builds and pushes that exact tag only when it is missing.
3. Promotes the exact manifest to `ghcr.io/hyperclaw79/homarr:rich-ical` only after the exact image exists.
4. Records the detected version in `HOMARR_VERSION` after publication succeeds.

This ordering leaves the moving tag unchanged after a failed build or push. Existing exact tags are treated as immutable by convention. A manual run can build a selected version and optionally move the channel.

The repository secret `SEANIME_ICON_URL` is required for published builds. It prevents the private URL from appearing in Git history, workflow configuration, or the redacted diff artifact. It does not make the URL secret at runtime: the built client and browser requests can still reveal it.

Deployment is deliberately out of scope. The workflow does not access Arcane, the NAS, a compose stack, or the local Forgejo instance.

