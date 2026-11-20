# Overleaf's own Redis: 7.4, the floor Overleaf 6 needs, with its settings baked in so the
# Process runs without arguments, as the redis user.
FROM redis:7.4-alpine@sha256:7f7d30b7fdd09467bac58198a1f166dd69789d348d4fe859cccb20e0cf287fbe
COPY redis.conf /usr/local/etc/redis/redis.conf
USER 999:1000
CMD ["redis-server", "/usr/local/etc/redis/redis.conf"]
