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

## 9. Add yourself as admin

Add a line to `addons/amxmodx/configs/users.ini`:
```
"YourName" "YourPassword" "abcdefghijklmnopqrstu" "a"
```
- `abcdefghijklmnopqrstu`: all admin rights except "user" flags.
- `a`: the player is kicked if the name matches but the password is wrong, which stops impersonation.

In your **game** console (or `cstrike/userconfig.cfg` on your PC):
```
setinfo _pw YourPassword
```

In game:
- `say /ca` or `/codadmin`: COD admin menu (give items, set levels/exp, add honor).
- `amxmodmenu` in the console: kick, ban, change map, etc.

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

To use the bot menu in game:
```
setinfo _ybpw BotMenuPassword
bind "=" "yb menu"
```
Then press `=` while alive.

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
