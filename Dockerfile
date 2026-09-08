FROM cm2network/steamcmd:root-bookworm

ARG GE_PROTON_VERSION=GE-Proton10-4

ENV STEAM_APP_ID=4550060 \
    SERVER_DIR=/opt/alchemyfactory \
    DATA_DIR=/data \
    PROTON_DIR=/opt/proton \
    DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl python3 xz-utils tini procps \
 && rm -rf /var/lib/apt/lists/*

RUN mkdir -p "${PROTON_DIR}" \
 && curl -sSL "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/${GE_PROTON_VERSION}/${GE_PROTON_VERSION}.tar.gz" \
    | tar -xz -C "${PROTON_DIR}" --strip-components=1

COPY scripts/entrypoint.sh scripts/config.sh scripts/mods.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/config.sh /usr/local/bin/mods.sh \
 && mkdir -p "${SERVER_DIR}" "${DATA_DIR}" \
 && chown -R steam:steam "${SERVER_DIR}" "${DATA_DIR}" "${PROTON_DIR}"

# Unreal dedicated servers refuse to run as root.
USER steam
WORKDIR ${SERVER_DIR}
VOLUME ["/data"]
EXPOSE 27015/udp

STOPSIGNAL SIGTERM
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
