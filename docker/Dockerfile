# CS 1.6 dedicated server with CoD Mod (english-translation branch).
# Build from the repository root:
#   docker build -f docker/Dockerfile -t codmod .
#
# Same stack as DEPLOY.md: standard HLDS (SteamCMD app 90), Metamod-r,
# AMX Mod X 1.10, YaPB. The mod's plugins are compiled during the build.

FROM debian:bookworm-slim

ARG METAMOD_VERSION=1.3.0.149
ARG AMXX_BUILD=1.10.0-git5474
ARG YAPB_VERSION=4.4.957

RUN dpkg --add-architecture i386 \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
      lib32gcc-s1 lib32stdc++6 libc6:i386 \
      ca-certificates curl unzip xz-utils \
 && rm -rf /var/lib/apt/lists/* \
 && useradd -m -u 1000 steam \
 && mkdir /fastdl && chown steam:steam /fastdl

USER steam
WORKDIR /home/steam
ENV HLDS=/home/steam/hlds
ENV CSTRIKE=/home/steam/hlds/cstrike

# --- 1. Game server ----------------------------------------------------------
# SteamCMD often stops early on app 90, so retry until the files are there.
RUN mkdir steamcmd \
 && curl -fsSL https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz | tar xz -C steamcmd \
 && for i in 1 2 3 4 5 6; do \
      ./steamcmd/steamcmd.sh +force_install_dir "$HLDS" +login anonymous \
        +app_set_config 90 mod cstrike +app_update 90 validate +quit || true; \
      test -f "$HLDS/hlds_linux" && test -f "$CSTRIKE/maps/de_dust2.bsp" && break; \
    done \
 && test -f "$HLDS/hlds_linux" && test -f "$CSTRIKE/maps/de_dust2.bsp" \
 && mkdir -p .steam/sdk32 && cp steamcmd/linux32/steamclient.so .steam/sdk32/ \
 && rm -rf steamcmd/package /home/steam/Steam/logs

# --- 2. Metamod-r ------------------------------------------------------------
RUN mkdir -p /tmp/mm "$CSTRIKE/addons/metamod/dlls" && cd /tmp/mm \
 && curl -fsSL -o mm.zip "https://github.com/rehlds/Metamod-R/releases/download/${METAMOD_VERSION}/metamod-bin-${METAMOD_VERSION}.zip" \
 && unzip -q mm.zip \
 && cp "$(find . -name 'metamod*.so' | head -n 1)" "$CSTRIKE/addons/metamod/dlls/metamod.so" \
 && cd / && rm -rf /tmp/mm \
 && sed -i 's/\r$//' "$CSTRIKE/liblist.gam" \
 && sed -i 's/^gamedll_linux.*/gamedll_linux "addons\/metamod\/dlls\/metamod.so"/' "$CSTRIKE/liblist.gam" \
 && grep -q 'metamod.so' "$CSTRIKE/liblist.gam"

# --- 3. AMX Mod X ------------------------------------------------------------
RUN curl -4 -fsSL "https://www.amxmodx.org/amxxdrop/1.10/amxmodx-${AMXX_BUILD}-base-linux.tar.gz"    | tar xz -C "$CSTRIKE" \
 && curl -4 -fsSL "https://www.amxmodx.org/amxxdrop/1.10/amxmodx-${AMXX_BUILD}-cstrike-linux.tar.gz" | tar xz -C "$CSTRIKE" \
 && echo 'linux addons/amxmodx/dlls/amxmodx_mm_i386.so' >  "$CSTRIKE/addons/metamod/plugins.ini" \
 && sed -i 's/^;mysql/mysql/' "$CSTRIKE/addons/amxmodx/configs/modules.ini" \
 && printf '\namx_language "en"\namx_client_languages 0\n' >> "$CSTRIKE/addons/amxmodx/configs/amxx.cfg"

# --- 4. YaPB bots (enabled/disabled at runtime with YAPB_ENABLED) ------------
RUN curl -fsSL "https://github.com/yapb/yapb/releases/download/${YAPB_VERSION}/yapb-${YAPB_VERSION}-linux.tar.xz" | tar xJ -C "$CSTRIKE" \
 && find "$CSTRIKE/addons/yapb" -type d -exec chmod 775 {} +

# --- 5. The mod: resources, then compile the plugins -------------------------
COPY --chown=steam:steam resources/ /tmp/codmod/resources/
COPY --chown=steam:steam cod.inc *.sma /tmp/codmod/
COPY --chown=steam:steam classes/ /tmp/codmod/classes/
COPY --chown=steam:steam items/ /tmp/codmod/items/
RUN cp -r /tmp/codmod/resources/. "$CSTRIKE/" \
 && S="$CSTRIKE/addons/amxmodx/scripting" \
 && cp /tmp/codmod/cod.inc "$S/include/" \
 && cd "$S" && fail=0 \
 && for f in /tmp/codmod/*.sma /tmp/codmod/classes/*.sma /tmp/codmod/items/*.sma; do \
      out="$CSTRIKE/addons/amxmodx/plugins/$(basename "${f%.sma}").amxx"; \
      ./amxxpc "$f" -o"$out" > /tmp/amxxpc.log 2>&1; \
      if [ ! -s "$out" ] || grep -q ' : error ' /tmp/amxxpc.log; then echo "FAILED: $f"; cat /tmp/amxxpc.log; fail=1; fi; \
    done \
 && [ "$fail" = 0 ] \
 && rm -rf /tmp/codmod /tmp/amxxpc.log

# Pristine copies of the files the entrypoint edits, so every start begins clean
RUN mkdir -p /home/steam/defaults \
 && cp "$CSTRIKE/server.cfg" "$CSTRIKE/addons/amxmodx/configs/cod_mod.cfg" \
       "$CSTRIKE/addons/amxmodx/configs/users.ini" "$CSTRIKE/addons/yapb/conf/yapb.cfg" \
       /home/steam/defaults/ \
 && mkdir -p "$CSTRIKE/addons/amxmodx/data/vault" "$CSTRIKE/addons/amxmodx/logs" "$CSTRIKE/logs"

COPY --chown=steam:steam --chmod=755 docker/entrypoint.sh /home/steam/entrypoint.sh

WORKDIR /home/steam/hlds
EXPOSE 27015/udp
ENTRYPOINT ["/home/steam/entrypoint.sh"]
