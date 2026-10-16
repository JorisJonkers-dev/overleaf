FROM sharelatex/sharelatex:6.3.0@sha256:d2c20ae595d64f61dca224864b90a5594fb71df0c20c014c2dcaae595f2de7d8

# Run the Community Edition monolith as www-data, under a read-only root filesystem:
# - every runit service runs as the user it is started as, and logs to stdout;
# - runit keeps each service's supervise state under /run, the one writable place;
# - nginx serves on 8000 (clsi's own nginx holds 8080) and writes nothing outside /run and /tmp;
# - cron and sshd are gone; the periodic service runs what cron did.
RUN set -eux; \
    rm -rf /etc/service/cron /etc/service/sshd; \
    sed -i -E 's#/sbin/setuser www-data ##; s# >> /var/log/overleaf/[a-z0-9-]+\.log 2>&1# 2>\&1#' /etc/service/*/run; \
    if [ -f /etc/nginx/templates/nginx.conf.template ]; then \
      NGINX_KEEPALIVE_TIMEOUT=65 NGINX_WORKER_CONNECTIONS=768 NGINX_WORKER_PROCESSES=4 \
        envsubst '${NGINX_KEEPALIVE_TIMEOUT} ${NGINX_WORKER_CONNECTIONS} ${NGINX_WORKER_PROCESSES}' \
        < /etc/nginx/templates/nginx.conf.template > /etc/nginx/nginx.conf; \
      rm -rf /etc/nginx/templates; \
    fi; \
    sed -i -E '/^user /d; s#^pid .*#pid /run/nginx/nginx.pid;#; s#access_log [^;]+;#access_log /dev/stdout;#; s#error_log [^;]+;#error_log stderr;#' /etc/nginx/nginx.conf; \
    sed -i -E 's#^(http \{)#\1\n\tclient_body_temp_path /tmp/nginx/body;\n\tproxy_temp_path /tmp/nginx/proxy;\n\tfastcgi_temp_path /tmp/nginx/fastcgi;\n\tuwsgi_temp_path /tmp/nginx/uwsgi;\n\tscgi_temp_path /tmp/nginx/scgi;#' /etc/nginx/nginx.conf; \
    sed -i -E 's#listen( +)80;#listen\18000;#' /etc/nginx/sites-enabled/overleaf.conf; \
    printf '#!/bin/bash\nexec nginx\n' > /etc/service/nginx/run; \
    for d in /etc/service/*/; do rm -rf "${d}supervise"; ln -s "/run/runit/$(basename "$d")" "${d}supervise"; done

COPY rootfs/ /
RUN set -eux; \
    chmod 0755 /usr/local/bin/overleaf-start /etc/runit/runsvdir/default/periodic/run; \
    ln -s /run/runit/periodic /etc/runit/runsvdir/default/periodic/supervise; \
    nginx -t -c /etc/nginx/nginx.conf 2>&1 | grep -v 'Permission denied' || true

USER 33:33
EXPOSE 8000
ENV TEXMFVAR=/tmp/texmf-var HOME=/tmp
ENTRYPOINT ["/usr/local/bin/overleaf-start"]
