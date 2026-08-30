FROM debian:trixie-slim@sha256:d7e12182ce18b85b93007c1dedf31f2d29e01ccf3182cc4017c709b6259bc132
LABEL org.opencontainers.image.authors="seth@falco.fun"

ARG DOCKER_USER=maid

RUN groupadd -g 1000 "$DOCKER_USER" && \
  useradd -m -g "$DOCKER_USER" -u 1000 -s /bin/bash "$DOCKER_USER" && \
  apt-get update && \
  apt-get install -y --no-install-recommends ca-certificates curl git jq locales && \
  localedef -i en_GB -c -f UTF-8 -A /usr/share/locale/locale.alias en_GB.UTF-8 && \
  su "$DOCKER_USER" -c 'git config --global --add safe.directory /builds/*' && \
  rm -rf /var/lib/apt/lists/*

# So printf can format numbers.
ENV LANG=en_GB.utf8

USER 1000

CMD ["bash"]
