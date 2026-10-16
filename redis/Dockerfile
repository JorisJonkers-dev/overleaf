# Overleaf's own Redis: 7.4, the floor Overleaf 6 needs, with its settings baked in so the
# Process runs without arguments, as the redis user.
FROM redis:7.4-alpine@sha256:858f009f9709ce576febc734aa78b8f6d624b82571f9ddb6bda4377c833b3499
COPY redis.conf /usr/local/etc/redis/redis.conf
USER 999:1000
CMD ["redis-server", "/usr/local/etc/redis/redis.conf"]
