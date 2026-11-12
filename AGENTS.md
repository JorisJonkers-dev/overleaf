# Agents

Guidance for any coding agent working in this repository. It holds the estate's Overleaf Community Edition image and its Redis image, delivered as the Project overleaf.

The repo's agent contract is [CLAUDE.md](CLAUDE.md); the estate-wide conventions are at https://github.com/JorisJonkers-dev/workspace/blob/main/CLAUDE.md.

## Build and test

- Lint shell: `shellcheck rootfs/usr/local/bin/overleaf-start scripts/*.sh`
- Build the images: `docker build -t overleaf:ci .` and `docker build -t overleaf-redis:ci redis`
- Smoke test under the restricted posture: `scripts/smoke-test.sh overleaf:ci overleaf-redis:ci`
- Lint workflows: `actionlint .github/workflows/*.yml`
