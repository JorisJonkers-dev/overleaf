#!/usr/bin/env bash
# Starts the image restricted beside Mongo and its Redis, waits for /status, and compiles a
# document through clsi. Usage: scripts/smoke-test.sh <overleaf-image> <redis-image>
set -euo pipefail
overleaf_image=$1
redis_image=$2
net=overleaf-smoke

cleanup() { docker rm -f smoke-overleaf smoke-mongo smoke-redis >/dev/null 2>&1 || true; docker network rm "$net" >/dev/null 2>&1 || true; }
trap cleanup EXIT
cleanup
docker network create "$net" >/dev/null

docker run -d --name smoke-mongo --network "$net" mongo:8.0 --replSet overleaf --bind_ip_all >/dev/null
docker run -d --name smoke-redis --network "$net" --user 999:1000 --read-only --cap-drop ALL \
  --tmpfs /data:uid=999,gid=1000 "$redis_image" >/dev/null
until docker exec smoke-mongo mongosh --quiet --eval \
  'try { rs.status().ok } catch (e) { rs.initiate({_id: "overleaf", members: [{_id: 0, host: "smoke-mongo:27017"}]}).ok }' \
  2>/dev/null | grep -q 1; do sleep 2; done

docker run -d --name smoke-overleaf --network "$net" --user 33:33 --read-only --cap-drop ALL \
  --security-opt no-new-privileges \
  --tmpfs /var/lib/overleaf:uid=33,gid=33,exec --tmpfs /run:uid=33,gid=33,exec \
  --tmpfs /tmp:uid=33,gid=33,mode=1777,exec \
  -e OVERLEAF_MONGO_URL='mongodb://smoke-mongo:27017/sharelatex?replicaSet=overleaf' \
  -e OVERLEAF_REDIS_HOST=smoke-redis -e OVERLEAF_REDIS_PORT=6379 \
  -e OVERLEAF_INVITE_TOKEN_SECRET=smoke -e OVERLEAF_SESSION_SECRET=smoke \
  -e OVERLEAF_SITE_URL=http://localhost:8000 -e OVERLEAF_TRUSTED_PROXY_IPS=loopback \
  "$overleaf_image" >/dev/null

for _ in $(seq 1 90); do
  if docker exec smoke-overleaf curl -fsS http://127.0.0.1:8000/status >/dev/null 2>&1; then
    break
  fi
  if [ "$(docker inspect -f '{{.State.Running}}' smoke-overleaf)" != true ]; then
    docker logs smoke-overleaf
    echo "overleaf exited before it served /status" >&2
    exit 1
  fi
  sleep 5
done
docker exec smoke-overleaf curl -fsS http://127.0.0.1:8000/status

result=$(docker exec smoke-overleaf curl -fsS -X POST -H 'Content-Type: application/json' \
  --data '{"compile":{"options":{"compiler":"pdflatex","timeout":60},"rootResourcePath":"main.tex","resources":[{"path":"main.tex","content":"\\documentclass{article}\\begin{document}smoke\\end{document}"}]}}' \
  http://127.0.0.1:3013/project/aaaaaaaaaaaaaaaaaaaaaaaa/user/bbbbbbbbbbbbbbbbbbbbbbbb/compile)
echo "$result" | head -c 300
echo
if ! echo "$result" | grep -q '"status":"success"'; then
  docker logs smoke-overleaf | tail -50
  exit 1
fi
if docker exec smoke-overleaf ps -eo user= | grep -qvx www-data; then
  docker exec smoke-overleaf ps -eo user,args
  echo "a process runs as someone other than www-data" >&2
  exit 1
fi
