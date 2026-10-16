# overleaf

[Overleaf Community Edition](https://github.com/overleaf/overleaf) at
`overleaf.jorisjonkers.dev`, as the estate runs it: the upstream
`sharelatex/sharelatex` image, changed only so that it runs under the estate's
restricted posture, and delivered by deploy-kit as the Project `overleaf`.

## What the image changes

Upstream starts as root under phusion's `my_init`, which runs setup scripts,
cron, syslog-ng and sshd, then drops to `www-data` for the Node services. This
image runs every process as `www-data` (uid 33) with a read-only root
filesystem and every capability dropped:

- `overleaf-start` does what the `my_init.d` scripts did that still applies:
  the per-start service secrets, the data directories, the Mongo and Redis
  checks, the migrations and the doc version check. Then it execs `runsvdir`.
- Every runit service runs as the user it starts as and logs to stdout. Its
  supervise state lives under `/run`.
- nginx serves on port 8000, since clsi's own nginx holds 8080, and writes its
  pid and temporary files under `/run` and `/tmp`.
- cron and sshd are gone. The `periodic` service runs the project-history
  flushes and retries the crontabs ran. The deletion jobs only run when
  `ENABLE_CRON_RESOURCE_DELETION` is true, which it is not here.
- `OVERLEAF_S3_KEY_HEX` becomes the S3 access key id `GK` plus its first 24
  hex digits, the shape Garage requires.

`/var/lib/overleaf`, `/run` and `/tmp` are the only writable paths. Every
project file and history chunk is stored in Garage, so nothing there outlives
the pod.

`redis/` builds Overleaf's own Redis: 7.4, the minimum Overleaf 6 needs, with
an append-only log, a memory bound and no eviction.

## Running it

`deploy/overleaf.project.yml` and `deploy/env/` declare the Project. Each
release builds both images and publishes the Intent Fragment that the estate
composes.

`scripts/smoke-test.sh` starts the image restricted beside Mongo and the Redis
image, then compiles a document. CI runs it on every change.

## Licence

Overleaf is licensed under the GNU Affero General Public License v3, and so is
this repository: see [LICENSE](LICENSE).
