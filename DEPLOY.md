# Deploying CoD Mod (English) on a Linux CS 1.6 server

Step-by-step guide for the `english-translation` branch. It was written from a working
setup with these versions:

| Component | Version used |
|---|---|
| OS | Debian/Ubuntu Linux (64-bit, with 32-bit libraries) |
| Game server | Standard HLDS, Counter-Strike 1.6 (SteamCMD app `90`) |
| Metamod | Metamod-r 1.3.0.149 |
| AMX Mod X | 1.10.0.5474 |
| Database | MariaDB 10.11 (MySQL works too) |
| Bots (optional) | YaPB 4.4.957 |

In the commands below, `~/cs16` is the server folder and `~/cs16/cstrike` is the game folder.
Adjust the paths to your own layout.

ReHLDS and ReGameDLL (recommended by the original mod author) are optional: this setup runs on
the standard engine and game DLL from SteamCMD.

---

## 1. Install the game server

```bash
sudo dpkg --add-architecture i386
sudo apt update
sudo apt install lib32gcc-s1 lib32stdc++6 screen git curl wget unzip xz-utils

mkdir -p ~/steamcmd && cd ~/steamcmd
curl -sqL https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz | tar zxvf -
./steamcmd.sh +force_install_dir ~/cs16 +login anonymous \
  +app_set_config 90 mod cstrike +app_update 90 validate +quit

# The server needs Steam's client library here, or it logs "SteamAPI_Init() failed"
mkdir -p ~/.steam/sdk32
cp ~/steamcmd/linux32/steamclient.so ~/.steam/sdk32/
```

SteamCMD sometimes stops early when installing app 90. If `~/cs16/cstrike` is incomplete,
run the same command again until it reports success. Quick check:
```bash
test -f ~/cs16/hlds_run && test -f ~/cs16/cstrike/maps/de_dust2.bsp && echo "Server files OK"
```

## 2. Install Metamod-r

```bash
mkdir -p ~/downloads/metamod && cd ~/downloads/metamod
# Download the latest metamod-bin-*.zip from https://github.com/theAsmodai/metamod-r/releases
unzip -qo metamod-bin-*.zip
mkdir -p ~/cs16/cstrike/addons/metamod/dlls
# The archive ships the library as metamod_i386.so; install it as metamod.so
cp "$(find . -name 'metamod*.so' | head -n 1)" ~/cs16/cstrike/addons/metamod/dlls/metamod.so
```

Point the Linux game DLL at Metamod in `~/cs16/cstrike/liblist.gam`:
```bash
sed -i 's/^gamedll_linux.*/gamedll_linux "addons\/metamod\/dlls\/metamod.so"/' ~/cs16/cstrike/liblist.gam
sed -i 's/\r$//' ~/cs16/cstrike/liblist.gam   # strip Windows line endings, which break this line
grep gamedll_linux ~/cs16/cstrike/liblist.gam
```

## 3. Install AMX Mod X 1.10

amxmodx.org downloads can hang over IPv6, so force IPv4 with `-4`:
```bash
mkdir -p ~/downloads/amxx && cd ~/downloads/amxx
wget -4 -O amx-base.tar.gz    https://www.amxmodx.org/amxxdrop/1.10/amxmodx-latest-base-linux.tar.gz
wget -4 -O amx-cstrike.tar.gz https://www.amxmodx.org/amxxdrop/1.10/amxmodx-latest-cstrike-linux.tar.gz
tar -xzf amx-base.tar.gz    -C ~/cs16/cstrike/
tar -xzf amx-cstrike.tar.gz -C ~/cs16/cstrike/

# Register AMX Mod X with Metamod
echo 'linux addons/amxmodx/dlls/amxmodx_mm_i386.so' > ~/cs16/cstrike/addons/metamod/plugins.ini

# Enable the MySQL module
sed -i 's/^;mysql/mysql/' ~/cs16/cstrike/addons/amxmodx/configs/modules.ini
```

The other modules the mod needs (fakemeta, hamsandwich, cstrike, csx, engine, fun, nvault)
load automatically.

Optional, in `addons/amxmodx/configs/amxx.cfg`, to keep the standard AMX Mod X plugins in English:
```
amx_language "en"
amx_client_languages 0
```

## 4. Create the database

The mod stores levels, accounts, clans, honor and stats in MySQL/MariaDB. It creates its own
tables on first start; you only need an empty database and a user.

```bash
sudo apt install mariadb-server
sudo mysql
```
```sql
CREATE DATABASE codmod CHARACTER SET utf8mb4;
CREATE USER 'codmod'@'127.0.0.1' IDENTIFIED BY 'choose-a-strong-password';
GRANT ALL PRIVILEGES ON codmod.* TO 'codmod'@'127.0.0.1';
FLUSH PRIVILEGES;
```

## 5. Get the mod

```bash
cd ~
git clone -b english-translation https://github.com/chefakhri/CoDMod.git
```

Repository layout:

| Path | Contents |
|---|---|
| `*.sma` (root) | Core plugins (`cod_mod.sma`, accounts, shop, clans, ...) |
| `classes/` | One plugin per class |
| `items/` | One plugin per item |
| `cod.inc` | Include file needed to compile everything |
| `resources/` | Models, sounds, sprites, configs and `vip.txt` to copy onto the server |

## 6. Copy the resources

```bash
cp -r ~/CoDMod/resources/* ~/cs16/cstrike/
```

This adds `models/CoDMod`, `sound/CoDMod`, `sprites/CoDMod`, `vip.txt` and the configs in
`addons/amxmodx/configs/` (`cod_mod.cfg`, `plugins-cod.ini`, `cod_menu.ini`,
`cod_missions.ini`, `cod_skins.ini`).

Linux file names are **case-sensitive**: the folders must be named exactly `CoDMod`.

## 7. Compile the plugins

```bash
S=~/cs16/cstrike/addons/amxmodx/scripting
cp ~/CoDMod/cod.inc $S/include/
mkdir -p ~/codmod-build
cd $S
for f in ~/CoDMod/*.sma ~/CoDMod/classes/*.sma ~/CoDMod/items/*.sma; do
  ./amxxpc "$f" -o"$HOME/codmod-build/$(basename "${f%.sma}").amxx" | grep -E "error|warning"
done
cp ~/codmod-build/*.amxx ~/cs16/cstrike/addons/amxmodx/plugins/
```

Every plugin should compile with no errors. AMX Mod X loads `plugins-cod.ini` automatically,
next to the standard `plugins.ini`.

## 8. Configure the mod

**`addons/amxmodx/configs/cod_mod.cfg`**: set the database login from step 4:
```
cod_sql_host "127.0.0.1"
cod_sql_user "codmod"
cod_sql_pass "choose-a-strong-password"
cod_sql_db "codmod"
```
Every other cvar in that file has a short description. Defaults in this branch:
- `cod_points_limit "0"`: no per-stat point cap.
- `cod_bot_level "0"`: bots copy the average level of the human players.

**`addons/amxmodx/configs/plugins-cod.ini`**: turn plugins on or off. A line starting with
`;` is disabled. In this branch all classes, the admin menu and the Electromagnet item are on.
Keep a newline at the end of the file: if you append a line to a file without one,
the two entries merge and both fail to load.

**`~/cs16/cstrike/server.cfg`**: recommended additions:
```
// The mod also sets this itself at every map start
sv_maxspeed 800

// Even teams: balance at round start, teams may differ by at most 1 player
mp_autoteambalance 1
mp_limitteams 1

// Dead players can only spectate their own team
mp_forcecamera 1
mp_forcechasecam 1
```

## 9. Admins

Admins are listed in `addons/amxmodx/configs/users.ini`, **one line per admin**. Each one has
their own name, password and rights:
```
; "name"       "password"     "access flags"            "account flags"
"YourName"     "OwnerPass"    "abcdefghijklmnopqrstu"   "a"
"FriendOne"    "FriendPass1"  "bcdefgijmu"              "a"
"FriendTwo"    "FriendPass2"  "cdeiju"                  "a"
"VipFriend"    "VipPass"      "t"                       "a"
```
Account flag `a` means: log in by **name + password**. Anyone who uses that name without the
right password is kicked, so nobody can impersonate an admin. Keep `a` on every line, and don't
use SteamID or IP logins: on a LAN server (`sv_lan 1`) everyone has the SteamID `STEAM_ID_LAN`,
and behind a proxy everyone also has the same IP.

Useful access flags:

| Flag | Allows | Flag | Allows |
|---|---|---|---|
| `a` | immunity (can't be kicked/banned) | `h` | `amx_cfg` |
| `b` | reserved slot | `i` | `amx_chat` and admin chat |
| `c` | `amx_kick` | `j` | votes (`amx_vote`, `amx_votemap`) |
| `d` | `amx_ban` / `amx_unban` | `l` | `amx_rcon` (any server command) |
| `e` | `amx_slay` / `amx_slap` | `m`–`s` | custom levels (unused by the mod except below) |
| `f` | `amx_map` (change map) | `t` | **CoD VIP** (bonus exp and honor, VIP knife; `/vip` in game) |
| `g` | `amx_cvar`, and the **CoD admin menu** (`/ca`) | `u` | `amxmodmenu` |

`abcdefghijklmnopqrstu` = everything, for the owner. The examples above: `bcdefgijmu` is a trusted
admin without immunity or rcon, `cdeiju` is a moderator (kick/ban/slap/chat/votes, no CoD admin
menu), `t` is VIP only.

Changes take effect after `amx_reloadadmins` or a map change.

Each admin logs in by setting their password on their own PC (see [Player setup](#14-player-setup-client-config)):
```
setinfo _pw FriendPass1
```

In game:
- `say /ca` or `/codadmin`: CoD admin menu (give items, set levels/exp, add honor). Needs flag `g`.
- `amxmodmenu` in the console: kick, ban, change map, etc. Needs flag `u`.

`setinfo` values are sent to every server you join, so use a password here that you don't use
anywhere else.

## 10. Bots (optional, YaPB)

```bash
mkdir -p ~/yapb && cd ~/yapb
curl -LO https://github.com/yapb/yapb/releases/download/4.4.957/yapb-4.4.957-linux.tar.xz
tar -xJf yapb-4.4.957-linux.tar.xz -C ~/cs16/cstrike/
# some folders in the archive ship without the execute bit; YaPB can't save data without it
find ~/cs16/cstrike/addons/yapb -type d -exec chmod 775 {} +
```

Add YaPB to `addons/metamod/plugins.ini`, below the AMX Mod X line:
```
linux addons/yapb/bin/yapb.so
```

Recommended settings in `addons/yapb/conf/yapb.cfg`:
```
yb_quota "6"                  // humans + bots = 6; each human who joins replaces a bot
yb_quota_mode "fill"
yb_join_after_player "1"      // bots only join while a human is on the server
yb_difficulty "2"             // normal
yb_check_enemy_rendering "1"  // bots respect the mod's invisibility
yb_display_welcome_text "0"
yb_password "BotMenuPassword" // lets you open the bot menu in game
```

The mod gives every bot a random (non-premium) class and assigns its stat points.
Bots are never saved to the database or shown in the Top15.

The bot menu is separate from AMX Mod X admins: there is **one shared password**
(`yb_password`), and everyone who knows it can open the menu (add/kick bots, change difficulty,
...). Give it only to people you'd trust with that. Admins with flag `l` can also control bots
without it, with `amx_rcon yb <command>`.

To use the bot menu in game:
```
setinfo _ybpw BotMenuPassword
bind "=" "yb menu"
```
Then press `=`.

## 11. Start the server

```bash
cd ~/cs16
screen -S cs16 ./hlds_run -game cstrike -console -pidfile hlds.pid +ip 0.0.0.0 +port 27015 \
  +maxplayers 12 +map de_dust2 +sv_lan 1
```
- Detach with `Ctrl+A`, then `D`. Reattach with `screen -r cs16`.
- `hlds_run` restarts the server automatically when it exits, so `quit` in the console is a restart.
- **Always pass `-pidfile hlds.pid`.** Without it, `hlds_run`'s crash handler hangs (it runs `cat`
  with no file name and waits for keyboard input), so after a crash the server stays down instead
  of restarting. With it, the server is back within about 10 seconds.
- `+sv_lan 1` (LAN mode) lets non-Steam clients join, but only from private addresses or through
  a tunnel such as playit.gg. `+sv_lan 0` makes Steam validate every player, which kicks
  non-Steam clients.

Check that everything loaded, in the server console:
```
meta list       // AMX Mod X (and YaPB) should show RUN
amx_plugins     // last line should read "N plugins, N running"
```

## 12. Applying changes later

| What changed | How to apply |
|---|---|
| A plugin (`.amxx`) or `plugins-cod.ini` | Change map (`changelevel de_dust2`, or `amx_map` in game) |
| A cvar | Type it in the server console (live), and also put it in the `.cfg` so it survives restarts |
| Metamod's `plugins.ini` (e.g. adding YaPB) | Restart the server (`quit`) |
| `users.ini` | `amx_reloadadmins`, or change map |

## 13. Player controls (nothing to configure)

| Key | Action |
|---|---|
| E | Class skill. If the class has none, uses stocked rockets/mines/dynamite/medkits/poison/lightning |
| Crouch + E | Always uses stocked rockets/mines/... |
| F | Use your item |
| Chat | `/menu`, `/class`, `/shop`, `/clan`, `/missions`, `/market`, `/casino`, `/binds` |
| Chat | `/rocket`, `/mine`, `/dynamite`, `/medkit`, `/poison`, `/thunder`, `/teleport` |

Optional, in each player's `cstrike/userconfig.cfg`, to use speeds above 400:
```
cl_forwardspeed 800
cl_sidespeed 800
cl_backspeed 800
```
Recent CS 1.6 clients block servers from changing these, so players have to set them themselves.

## 14. Player setup (client config)

Every player can put their settings in one file on their own PC, so they never have to type them
again. Create (or edit) `Counter-Strike/cstrike/userconfig.cfg`, which the game runs at every
start. If your client doesn't run it (some older non-Steam builds), name the file `autoexec.cfg`
instead. Don't edit `config.cfg`: the game overwrites it.

```
// ---- CoD Mod: passwords (delete the lines you don't need) ----
setinfo _codpass "MyAccountPassword"   // your CoD account (/account): logs you in automatically
setinfo _pw      "MyAdminPassword"     // only for admins listed in users.ini
setinfo _ybpw    "BotMenuPassword"     // only if you were given the bot menu password

// ---- CoD Mod: keys ----
// E (class skill) and F (item) work without binds; these are extras.
bind "v"   "menu"          // CoD main menu
bind "z"   "+rocket"
bind "x"   "+mine"
bind "c"   "+dynamite"
bind "g"   "+medkit"
bind "h"   "+poison"
bind "j"   "+thunder"
bind "k"   "+teleport"
bind "="   "yb menu"       // bot menu (needs _ybpw)
bind "F10" "amxmodmenu"    // admin menu (needs _pw)
bind "F11" "say /ca"       // CoD admin menu (needs _pw and flag g)

// ---- CoD Mod: movement above 400 speed ----
cl_forwardspeed 800
cl_sidespeed 800
cl_backspeed 800

// ---- Connect quickly: type "cod" in the console ----
alias cod "connect your.server.address:27015"
```
- Pick other keys if these clash with your own binds (for example `c` is often radio).
- The CoD account password is the one you chose in the account menu when you first joined.
  Your name is your login, so always play with the same name.
- To check a value: type `setinfo` in the console with no arguments.

All the in-game chat commands are listed in step 13. `/binds` shows the key list in game.

## Docker

`docker/` contains a Dockerfile that builds steps 1–7 and 10 into one image (the plugins are
compiled during the build), and a compose file that also runs MariaDB.

```bash
cp docker/.env.example docker/.env     # set RCON_PASSWORD, DB_PASS, ADMIN_NAME/ADMIN_PASSWORD, ...
docker compose -f docker/compose.yaml up -d --build
```

- Every setting from steps 8–11 comes from `docker/.env` and is written again at each start.
  Change `.env`, then `docker compose -f docker/compose.yaml up -d` to apply it.
- After a `git pull` (new plugins or resources), add `--build`.
- Server console: `docker attach cs16-codmod` (detach with `Ctrl+P`, `Ctrl+Q`; `Ctrl+C` stops the server).
  Logs: `docker logs -f cs16-codmod`, plus `docker/data/logs/`.
- Extra files (maps, `mapcycle.txt`, your own `plugins-cod.ini`, `server-extra.cfg`, ...): put
  them in `docker/data/overlay/`, using the same layout as `cstrike/`. They are copied over the
  game folder at each start. A `server-extra.cfg` there is run after `server.cfg`.
- Admins: `ADMIN_NAME`/`ADMIN_PASSWORD` in `.env` add one admin with all rights. For more
  admins, put your own `users.ini` (step 9) in `docker/data/overlay/addons/amxmodx/configs/`.
  It replaces the default file, and the `.env` admin is still added to it. Apply with a container
  restart, or `amx_reloadadmins` after editing the file inside the container.
- The bot menu password is `YAPB_PASSWORD`, shared by everyone who uses the bot menu (step 10).
- The container runs `hlds_linux` directly. `quit` or a crash stops the container and the
  `restart: unless-stopped` policy starts it again, so the `hlds_run`/`-pidfile` issue from step 11 doesn't apply here.
- Only `27015/udp` needs to be published: GoldSrc uses UDP for both the game and rcon.

### FastDL (fast downloads of models, sounds and maps)

Without it, players download the mod's custom files (about 200 MB) from the game server itself,
which is very slow. The compose file runs a small nginx container (`fastdl`, port `27080/tcp`)
for this:

- At every start, the game server copies the files players may need (maps, models, sounds,
  sprites, `.wad` and overview files, including anything from the overlay) into a shared
  volume. nginx serves that volume read-only. Only those file types are served, and folder
  listing is off, so configs, plugins and passwords are never reachable.
- Set `SV_DOWNLOADURL` in `.env` to the public address with a trailing slash, for example
  `http://fastdl.example.com/`, then `docker compose ... up -d`.
- Use **plain HTTP**. Many CS 1.6 clients can't download over HTTPS, so if a proxy is in front
  (for example a Zoraxy HTTP rule pointing to `<server>:27080`), turn off its redirect to HTTPS
  for this host.
- If the URL can't be reached, clients fall back to downloading from the game server.
- Check it: `curl -I http://fastdl.example.com/models/CoDMod/bazooka.mdl` should return `200`.

### Behind a reverse proxy / tunnel (sv_lan 1 with non-Steam players)

With `sv_lan 1` the engine only accepts players from private addresses (10.x, 172.16–31.x,
192.168.x). Public players can still join if a **userspace** UDP proxy in front of the server
(for example a Zoraxy stream proxy on a VPS, connected to this machine over WireGuard) forwards
the traffic. The proxy opens its own connection to the server, so every player seems to come
from the proxy's tunnel address, which is private.

This does **not** work with a plain iptables DNAT port forward, because that keeps the player's
public IP. Add a MASQUERADE/SNAT rule for that traffic, or use a userspace proxy.

Trade-offs of this setup:
- Every internet player has the proxy's IP, and in LAN mode everyone's SteamID is `STEAM_ID_LAN`.
  The mod saves progress by name and protects names with `/account` passwords, so saving still
  works, but IP or SteamID bans would hit everyone. Ban by name instead.
- The server is not listed in the public server browser. Players connect with
  `connect <public-address>:27015` in the console, or add it to their favourites.

The alternative is `sv_lan 0` with ReHLDS + ReUnion, which accepts both Steam and non-Steam
clients on an internet server. This image doesn't include them.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `SteamAPI_Init() failed` / `steamclient.so` errors at start | Copy `steamclient.so` to `~/.steam/sdk32/` (step 1). |
| `meta list` says "Unknown command" (Metamod not loaded) | Check the `gamedll_linux` line in `liblist.gam`, and strip Windows line endings with `sed -i 's/\r$//' liblist.gam` (step 2). |
| amxmodx.org download hangs or fails | Use `wget -4` to force IPv4 (step 3). |
| After a crash the server never comes back; `screen -r cs16` shows the crash message and nothing after it | `hlds_run` is stuck in its crash handler. Start it with `-pidfile hlds.pid` (step 11). To unstick a running one: `pkill -P "$(pgrep -f 'sh ./hlds_run')" -x cat`. |
| A COD plugin shows as "paused"/"bad load" in `amx_plugins`; error log says "Missing file cod_menu.ini" (or skins/missions) | The configs from `resources/` weren't copied (step 6). |
| Map won't start, "can't find model" or "precache" error | A file path doesn't match the real folder name. Linux is case-sensitive (`CoDMod` ≠ `CodMod`). |
| `Load fails: Plugin file open error (plugin "a.amxxb.amxx")` | Two lines in `plugins-cod.ini` merged; add the missing line break. |
| HUD says "An error occurred while trying to connect to the database!" | Wrong `cod_sql_*` values in `cod_mod.cfg`, or MariaDB isn't running. |
| Bots join but have no class | `cod_accounts.amxx` from this branch is required; older versions block bots. |
| `/ca` does nothing | `cod_admin_menu.amxx` is disabled in `plugins-cod.ini`, or you are not logged in as admin. |
| YaPB: "Unable to open ... for writing" | Run the `chmod` command from step 10. |

Error logs are in `addons/amxmodx/logs/error_YYYYMMDD.log`.
