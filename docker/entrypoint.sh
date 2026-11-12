#!/bin/bash
# Applies settings from environment variables, then starts HLDS in the foreground.
# Crashes and "quit" end the container; the compose restart policy brings it back.
set -euo pipefail

# The container starts as root only to prepare the mounted folders: Docker creates missing
# bind-mount folders (data/logs/...) as root, and the server can't write logs there. Fix the
# owner, then run the rest of this script as the unprivileged "steam" user.
if [ "$(id -u)" = 0 ]; then
  for d in "$CSTRIKE/addons/amxmodx/logs" "$CSTRIKE/logs" \
           "$CSTRIKE/addons/amxmodx/data/vault" "$CSTRIKE/addons/yapb/data" /fastdl; do
    mkdir -p "$d"
    [ "$(stat -c %u "$d")" = 1000 ] || chown -R steam:steam "$d"
  done
  export HOME=/home/steam USER=steam
  exec setpriv --reuid=steam --regid=steam --init-groups "$0" "$@"
fi

CFG="$CSTRIKE/addons/amxmodx/configs"
DEF=/home/steam/defaults

: "${SERVER_NAME:=CoD Mod}"
: "${SV_LAN:=1}"
: "${MAXPLAYERS:=12}"
: "${START_MAP:=de_dust2}"
: "${PORT:=27015}"
: "${RCON_PASSWORD:=}"
: "${SV_PASSWORD:=}"
: "${SV_DOWNLOADURL:=}"
: "${DB_HOST:=db}"
: "${DB_USER:=codmod}"
: "${DB_PASS:?DB_PASS must be set}"
: "${DB_NAME:=codmod}"
: "${ADMIN_NAME:=}"
: "${ADMIN_PASSWORD:=}"
: "${YAPB_ENABLED:=1}"
: "${YAPB_QUOTA:=6}"
: "${YAPB_DIFFICULTY:=2}"
: "${YAPB_PASSWORD:=}"
: "${YAPB_CAMP_MIN:=5}"
: "${YAPB_CAMP_MAX:=15}"
: "${YAPB_NAMES:=}"
: "${YAPB_CHAT:=}"
: "${COD_ITEMS:=default}"
: "${COD_CLASSES:=default}"
: "${REUNION_SALT:=}"
: "${EXTRA_ARGS:=}"
# Engine memory pool in KB. ReHLDS starts with a small one; the mod's models and sounds plus the
# next map then don't fit and the server dies at map change ("Cache_TryAlloc ... free hunk").
: "${HEAPSIZE:=131072}"

# Escape a value for use inside a "quoted" cfg string
q() { printf '%s' "$1" | sed 's/"/'"'"'/g'; }

# 1. Start from the files shipped in the image
cp "$DEF/server.cfg"  "$CSTRIKE/server.cfg"
cp "$DEF/cod_mod.cfg" "$CFG/cod_mod.cfg"
cp "$DEF/users.ini"   "$CFG/users.ini"
cp "$DEF/yapb.cfg"    "$CSTRIKE/addons/yapb/conf/yapb.cfg"
cp "$DEF/plugins-cod.ini" "$CFG/plugins-cod.ini"
cp "$DEF/en_names.cfg" "$CSTRIKE/addons/yapb/conf/lang/en_names.cfg"
cp "$DEF/en_chat.cfg"  "$CSTRIKE/addons/yapb/conf/lang/en_chat.cfg"
cp "$DEF/reunion.cfg"  "$CSTRIKE/reunion.cfg"

# Reunion refuses to start without a salt (>= 16 chars). The salt changes every non-Steam
# player's SteamID, so keep it fixed in .env; a random one is used only as a fallback.
if [ -z "$REUNION_SALT" ]; then
  REUNION_SALT=$(od -An -tx1 -N16 /dev/urandom | tr -d ' \n')
  echo "[entrypoint] WARNING: REUNION_SALT not set, using a random salt (non-Steam SteamIDs change on every restart)"
elif [ ${#REUNION_SALT} -lt 16 ]; then
  echo "[entrypoint] ERROR: REUNION_SALT must be at least 16 characters" >&2; exit 1
fi
awk -v salt="$REUNION_SALT" '/^SteamIdHashSalt[ =]/ { print "SteamIdHashSalt = " salt; next } { print }' \
  "$CSTRIKE/reunion.cfg" > "$CSTRIKE/reunion.cfg.tmp" && mv "$CSTRIKE/reunion.cfg.tmp" "$CSTRIKE/reunion.cfg"

# 2. Overlay: anything mounted at /overlay is copied over cstrike/
#    (extra maps, mapcycle.txt, your own plugins-cod.ini, ...)
if [ -d /overlay ] && [ -n "$(ls -A /overlay 2>/dev/null)" ]; then
  echo "[entrypoint] applying /overlay"
  cp -r /overlay/. "$CSTRIKE/"
fi

# 3. Items and classes: "default" keeps plugins-cod.ini as it is, "all" enables every item / class plugin
if [ "$COD_ITEMS" = all ]; then
  sed -i 's/^;[[:space:]]*\(coditem_\)/\1/' "$CFG/plugins-cod.ini"
fi
if [ "$COD_CLASSES" = all ]; then
  sed -i 's/^;[[:space:]]*\(codclass_\)/\1/' "$CFG/plugins-cod.ini"
fi

# 4. Database login for the mod
sed -i \
  -e "s|^cod_sql_host .*|cod_sql_host \"$(q "$DB_HOST")\"|" \
  -e "s|^cod_sql_user .*|cod_sql_user \"$(q "$DB_USER")\"|" \
  -e "s|^cod_sql_pass .*|cod_sql_pass \"$(q "$DB_PASS")\"|" \
  -e "s|^cod_sql_db .*|cod_sql_db \"$(q "$DB_NAME")\"|" \
  "$CFG/cod_mod.cfg"

# 5. Server settings (server.cfg runs at every map change, so these stick)
cat >> "$CSTRIKE/server.cfg" <<EOF

// ---- added by docker/entrypoint.sh ----
hostname "$(q "$SERVER_NAME")"
rcon_password "$(q "$RCON_PASSWORD")"
sv_password "$(q "$SV_PASSWORD")"
sv_lan $SV_LAN
sv_maxspeed 800
mp_autoteambalance 1
mp_limitteams 1
mp_forcecamera 1
mp_forcechasecam 1
sv_allowdownload 1
sv_allowupload 1
// Network rates: ReHLDS defaults to 30 updates per second, which feels jerky
sv_maxupdaterate 101
sv_minupdaterate 20
sv_maxrate 0
sv_minrate 25000
EOF
if [ -n "$SV_DOWNLOADURL" ]; then
  echo "sv_downloadurl \"$(q "$SV_DOWNLOADURL")\"" >> "$CSTRIKE/server.cfg"
fi
if [ -f "$CSTRIKE/server-extra.cfg" ]; then
  echo 'exec server-extra.cfg' >> "$CSTRIKE/server.cfg"
fi

# 6. Admin
if [ -n "$ADMIN_NAME" ] && [ -n "$ADMIN_PASSWORD" ]; then
  echo "\"$(q "$ADMIN_NAME")\" \"$(q "$ADMIN_PASSWORD")\" \"abcdefghijklmnopqrstu\" \"a\"" >> "$CFG/users.ini"
fi

# 7. Bots
if [ "$YAPB_ENABLED" = 1 ]; then
  grep -q 'yapb.so' "$CSTRIKE/addons/metamod/plugins.ini" \
    || printf 'linux addons/yapb/bin/yapb.so\n' >> "$CSTRIKE/addons/metamod/plugins.ini"
  cat >> "$CSTRIKE/addons/yapb/conf/yapb.cfg" <<EOF

// ---- added by docker/entrypoint.sh ----
yb_quota "$YAPB_QUOTA"
yb_quota_mode "fill"
yb_join_after_player "1"
yb_difficulty "$YAPB_DIFFICULTY"
yb_check_enemy_rendering "1"
yb_display_welcome_text "0"
yb_password "$(q "$YAPB_PASSWORD")"
yb_camping_time_min "$YAPB_CAMP_MIN"
yb_camping_time_max "$YAPB_CAMP_MAX"
EOF
  # Bot chat: YAPB_CHAT=ms uses lang/ms_chat.cfg (casual Malay-English, some Penang loghat) instead of the English chat
  if [ -n "$YAPB_CHAT" ] && [ "$YAPB_CHAT" != en ]; then
    chatFile="$CSTRIKE/addons/yapb/conf/lang/${YAPB_CHAT}_chat.cfg"
    if [ -f "$chatFile" ]; then cp "$chatFile" "$CSTRIKE/addons/yapb/conf/lang/en_chat.cfg"
    else echo "[entrypoint] YAPB_CHAT=$YAPB_CHAT: $chatFile not found, keeping English bot chat"; fi
  fi
  # Bot names: YAPB_NAMES="Name 1,Name 2,..." replaces YaPB's own list (one name per line in en_names.cfg)
  if [ -n "$YAPB_NAMES" ]; then
    printf '; Bot names from YAPB_NAMES (docker/entrypoint.sh)\n' > "$CSTRIKE/addons/yapb/conf/lang/en_names.cfg"
    printf '%s\n' "$YAPB_NAMES" | tr ',' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^$' >> "$CSTRIKE/addons/yapb/conf/lang/en_names.cfg"
  fi
else
  sed -i '/yapb.so/d' "$CSTRIKE/addons/metamod/plugins.ini"
fi

# 8. FastDL: copy the files clients may download into /fastdl (served by the fastdl container).
#    Only game content types from content folders: no configs, plugins or passwords.
if [ -d /fastdl ] && [ -w /fastdl ]; then
  echo "[entrypoint] syncing download files to /fastdl"
  cd "$CSTRIKE"
  {
    find maps models sound sprites gfx overviews -type f \
      \( -iname '*.bsp' -o -iname '*.res' -o -iname '*.txt' -o -iname '*.wad' -o -iname '*.mdl' \
         -o -iname '*.wav' -o -iname '*.mp3' -o -iname '*.spr' -o -iname '*.tga' -o -iname '*.bmp' \) 2>/dev/null || true
    find . -maxdepth 1 -type f -iname '*.wad' -printf '%P\n'
  } | while IFS= read -r f; do
    if [ ! -e "/fastdl/$f" ] || [ "$f" -nt "/fastdl/$f" ]; then
      mkdir -p "/fastdl/$(dirname "$f")" && cp -p "$f" "/fastdl/$f"
    fi
  done
fi

# 9. Wait for the database, so the first map doesn't start without it
host="${DB_HOST%%:*}"; dbport=3306; [[ "$DB_HOST" == *:* ]] && dbport="${DB_HOST##*:}"
for i in $(seq 1 60); do
  (exec 3<>"/dev/tcp/$host/$dbport") 2>/dev/null && break
  [ "$i" = 1 ] && echo "[entrypoint] waiting for database at $host:$dbport ..."
  sleep 2
done

echo "[entrypoint] starting HLDS: map=$START_MAP maxplayers=$MAXPLAYERS sv_lan=$SV_LAN bots=$YAPB_ENABLED"
cd "$HLDS"
export LD_LIBRARY_PATH="$HLDS:${LD_LIBRARY_PATH:-}"
# shellcheck disable=SC2086
exec ./hlds_linux -game cstrike -console -heapsize "$HEAPSIZE" +ip 0.0.0.0 -port "$PORT" \
  +maxplayers "$MAXPLAYERS" +sv_lan "$SV_LAN" +map "$START_MAP" $EXTRA_ARGS
