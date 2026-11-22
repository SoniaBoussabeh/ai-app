# Unprivileged nginx: runs as non-root and listens on 8080 by default
FROM nginxinc/nginx-unprivileged:1.30.6-alpine

# Static content + nginx config
COPY app/ /usr/share/nginx/html/
COPY nginx/default.conf /etc/nginx/conf.d/default.conf

# Single source of truth: read the version straight from the VERSION file
# and bake it into the file served at /version (trim any surrounding whitespace).
COPY VERSION /tmp/VERSION
USER root
# Pull Alpine security fixes released after the base image was built; the Trivy
# gate in the pipeline fails the build on any HIGH or CRITICAL finding.
#
# SCRUM-12 (CM-08): nginx 1.30.6-r1 has 4 CRITICAL + 2 HIGH CVEs fixed in 1.30.7.
# nginx comes from the nginx.org repository and is version-pinned, so `apk upgrade`
# cannot reach the fix, and no 1.30.7-alpine base image is published yet. Install
# nginx and its modules at the fixed version from nginx.org (signing key already in
# the base image). Remove this block once nginx-unprivileged:1.30.7-alpine exists.
ARG NGINX_PATCH=1.30.7
ARG NJS_VERSION=1.0.2
RUN apk upgrade --no-cache \
 && apk add --no-cache \
      --repository "https://nginx.org/packages/alpine/v$(cut -d. -f1,2 /etc/alpine-release)/main" \
      "nginx=${NGINX_PATCH}-r1" \
      "nginx-module-geoip=${NGINX_PATCH}-r1" \
      "nginx-module-image-filter=${NGINX_PATCH}-r1" \
      "nginx-module-njs=${NGINX_PATCH}.${NJS_VERSION}-r1" \
      "nginx-module-xslt=${NGINX_PATCH}-r1"
RUN tr -d ' \t\r\n' < /tmp/VERSION > /usr/share/nginx/html/version.txt && rm /tmp/VERSION
USER nginx

EXPOSE 8080
