FROM cm2network/steamcmd:root-bookworm@sha256:7cc96a9ec113ed6752f81e44ac62a367f1db7d8a055f2680d1aecd35dc2ff516

ARG GE_PROTON_VERSION=GE-Proton11-6

ENV STEAM_APP_ID=4550060 \
    GAME_APP_ID=3669570 \
    SERVER_DIR=/opt/alchemyfactory \
    DATA_DIR=/data \
    PROTON_DIR=/opt/proton \
    DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl python3 xz-utils tini procps \
 && rm -rf /var/lib/apt/lists/*

RUN mkdir -p "${PROTON_DIR}" \
 && base="https://github.com/GloriousEggroll/proton-ge-custom/releases/download/${GE_PROTON_VERSION}" \
 && curl -sSLo /tmp/proton.tar.gz "${base}/${GE_PROTON_VERSION}-x86_64.tar.gz" \
 && curl -sSLo /tmp/proton.sha512 "${base}/${GE_PROTON_VERSION}-x86_64.sha512sum" \
 && (cd /tmp && sha512sum -c --ignore-missing proton.sha512 < /dev/null 2>/dev/null \
     || echo "$(cut -d' ' -f1 /tmp/proton.sha512)  /tmp/proton.tar.gz" | sha512sum -c -) \
 && tar -xzf /tmp/proton.tar.gz -C "${PROTON_DIR}" --strip-components=1 \
 && rm -f /tmp/proton.tar.gz /tmp/proton.sha512

COPY scripts/entrypoint.sh scripts/config.sh scripts/mods.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/config.sh /usr/local/bin/mods.sh \
 && mkdir -p "${SERVER_DIR}" "${DATA_DIR}" \
 && chown -R steam:steam "${SERVER_DIR}" "${DATA_DIR}" "${PROTON_DIR}"

# Unreal dedicated servers refuse to run as root.
USER steam
WORKDIR ${SERVER_DIR}
VOLUME ["/data"]
EXPOSE 27015/udp

# No RCON or query protocol exists, so liveness is process-level only.
HEALTHCHECK --interval=30s --timeout=5s --start-period=180s --retries=3 \
  CMD pgrep -f AlchemyFactoryServer >/dev/null || exit 1

LABEL org.opencontainers.image.title="alchemy-factory-server" \
      org.opencontainers.image.description="Alchemy Factory dedicated server on Linux via Proton" \
      org.opencontainers.image.source="https://github.com/idarlafish/alchemy-factory-server" \
      org.opencontainers.image.licenses="Apache-2.0"

STOPSIGNAL SIGTERM
ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
