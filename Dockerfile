# Unprivileged nginx: runs as non-root and listens on 8080 by default
FROM nginxinc/nginx-unprivileged:1.27-alpine

# Static content + nginx config
COPY app/ /usr/share/nginx/html/
COPY nginx/default.conf /etc/nginx/conf.d/default.conf

# Single source of truth: read the version straight from the VERSION file
# and bake it into the file served at /version (trim any surrounding whitespace).
COPY VERSION /tmp/VERSION
USER root
RUN tr -d ' \t\r\n' < /tmp/VERSION > /usr/share/nginx/html/version.txt && rm /tmp/VERSION
USER nginx

EXPOSE 8080
