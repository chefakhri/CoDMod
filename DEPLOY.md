# Deploying CoD Mod (English) on a Linux CS 1.6 server

Step-by-step guide for the `english-translation` branch. It was written from a working
setup with these versions:

| Component | Version used |
|---|---|
| OS | Debian/Ubuntu Linux (64-bit, with 32-bit libraries) |
| Game server | HLDS, Counter-Strike 1.6 (SteamCMD app `90`) with the ReHLDS 3.15.0.896 engine |
| Metamod | Metamod-r 1.3.0.149 |
| Non-Steam clients (public server) | Reunion 0.2.0.25 |
| AMX Mod X | 1.10.0.5474 |
| Database | MariaDB 10.11 (MySQL works too) |
| Bots (optional) | YaPB 4.4.957 |

In the commands below, `~/cs16` is the server folder and `~/cs16/cstrike` is the game folder.
Adjust the paths to your own layout.

**ReHLDS is required.** AMX Mod X 1.10 was built for the engine layout from before Valve's 2023
(25th anniversary) update. On the current Valve engine, setting or resetting a player model
(`cs_set_user_model`, which the mod does at every spawn) makes AMX Mod X write into the wrong
memory: other players' network state. Symptoms include lag spikes for everyone and broken names.
With ReHLDS, AMX Mod X uses the ReHLDS API instead. ReGameDLL stays optional; the game DLL is
the standard one from SteamCMD.

---

## 1. Install the game server

```bash
sudo dpkg --add-architecture i386
sudo apt update
sudo apt install lib32gcc-s1 lib32stdc++6 screen git curl wget unzip xz-utils

mkdir -p ~/steamcmd && cd ~/steamcmd
curl -sqL https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz | tar zxvf -
./steamcmd.sh +force_install_dir ~/cs16 +login anonymous \
  +app_set_config 90 mod cstrike +app_update 90 -beta steam_legacy validate +quit

# The server needs Steam's client library here, or it logs "SteamAPI_Init() failed"
mkdir -p ~/.steam/sdk32
cp ~/steamcmd/linux32/steamclient.so ~/.steam/sdk32/
```

SteamCMD sometimes stops early when installing app 90. If `~/cs16/cstrike` is incomplete,
run the same command again until it reports success. Quick check:
```bash
test -f ~/cs16/hlds_run && test -f ~/cs16/cstrike/maps/de_dust2.bsp && echo "Server files OK"
```

### Replace the engine with ReHLDS

```bash
mkdir -p ~/downloads/rehlds && cd ~/downloads/rehlds
wget https://github.com/rehlds/ReHLDS/releases/download/3.15.0.896/rehlds-bin-3.15.0.896.zip
unzip -qo rehlds-bin-3.15.0.896.zip
cp -r bin/linux32/. ~/cs16/
```
ReHLDS needs the `steam_legacy` branch of app 90 (installed above). On Valve's current branch
it fails with `undefined symbol: SteamGameServer_Init`. Current Steam clients connect to it normally.
`version` in the console shows the ReHLDS build. SteamCMD updates put Valve's engine back, so copy
the ReHLDS files again after each one (always with `-beta steam_legacy`).

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

### Reunion (non-Steam players on a public server)

Only needed with `sv_lan 0`. Reunion is a Metamod plugin that lets non-Steam clients join a
ReHLDS server and gives them a stable SteamID. It only works on ReHLDS, and it only runs while
a player connects, so it costs nothing during play.

```bash
mkdir -p ~/downloads/reunion && cd ~/downloads/reunion
wget https://github.com/rehlds/ReUnion/releases/download/0.2.0.25/reunion-0.2.0.25.zip
unzip -qo reunion-0.2.0.25.zip
mkdir -p ~/cs16/cstrike/addons/reunion
cp bin/Linux/reunion_mm_i386.so ~/cs16/cstrike/addons/reunion/
# Reunion must be the first line of Metamod's plugins.ini
sed -i '1i linux addons/reunion/reunion_mm_i386.so' ~/cs16/cstrike/addons/metamod/plugins.ini
cp ~/CoDMod/resources/reunion.cfg ~/cs16/cstrike/reunion.cfg
```
Set `SteamIdHashSalt` in `~/cs16/cstrike/reunion.cfg` to a secret of 16+ characters
(`openssl rand -hex 16`); Reunion doesn't start without it. Keep it: changing it changes every
non-Steam player's SteamID. The mod's `reunion.cfg` differs from the default in three settings:
- `cid_NoSteam47` / `cid_NoSteam48 = 3`: non-Steam clients without an emulator get an IP-based
  SteamID instead of being dropped.
- `IDClientsLimit = 0`: several players may share a SteamID. Behind a proxy that hides player IPs,
  IP-based IDs collide. Set it back to `1` once players connect with their real IPs.
- `LoggingMode = 1`: Reunion logs each connection's client type to the console.

`meta list` in the console should show Reunion as `RUN`.

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
- `cod_server_owner "MaskMan"`: name in the welcome message ("server by MaskMan (original mod by O'Zone)"). Set your own, or `""` for the original message.
- `cod_points_limit "0"`: no per-stat point cap.
- `cod_bot_level "0"`: bots copy the average level of the human players.

**`addons/amxmodx/configs/plugins-cod.ini`**: turn plugins on or off. A line starting with
`;` is disabled. In this branch all classes, the admin menu and 10 balanced items are on
(see [step 15](#15-items-perks-enabling-and-disabling)).
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
yb_camping_time_min "5"       // seconds a bot waits in one spot (YaPB default 15)
yb_camping_time_max "15"      // (YaPB default 45)
```

Bot names come from `addons/yapb/conf/lang/en_names.cfg`, one name per line; bots only use the
names in that file. Replace its contents to give bots your own names (with Docker: `YAPB_NAMES`).

Bot chat (greetings, kill messages, dead chat, replies) comes from `addons/yapb/conf/lang/en_chat.cfg`.
This fork ships a casual Malay-English version with some Penang loghat, `ms_chat.cfg` (copied in with the resources in step 6):
to use it, copy it over `en_chat.cfg` and restart the server (with Docker: `YAPB_CHAT=ms`). Turn bot
chat off completely with `yb_chat "0"`; `yb_chat_percent` sets how often dead bots chat.

Bots sometimes stop and wait in one spot ("camping"); from spectator view that can look like a
stuck bot. It is normal YaPB behaviour. The two `yb_camping_time` lines keep the waits short;
`yb_camping_allowed "0"` turns camping off completely (bots then never hold positions).

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
  a tunnel such as playit.gg. `+sv_lan 0` makes Steam validate every player; non-Steam clients
  then need Reunion (step 3).

The server uses the machine's timezone. The night exp bonus hours (`cod_night_exp_from` /
`cod_night_exp_to`) are local time, so check it with `timedatectl` and set it if needed, e.g.
`sudo timedatectl set-timezone Asia/Kuala_Lumpur`, then restart the server.

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
| F | Use your item. With 2 item slots: your first item, or the second if the first has no use effect |
| `+item2` / `/item2` | Use your second item (only with 2 item slots) |
| Chat | `/menu`, `/class`, `/shop`, `/clan`, `/missions`, `/market`, `/casino`, `/binds` |
| Chat | `/rocket`, `/mine`, `/dynamite`, `/medkit`, `/poison`, `/thunder`, `/teleport` |
| Chat | `/commands` (or `/cmds`): **every chat command**, by category; pick one to run it |
| Chat | `/rtv`: vote to change the map (step 17). `/timeleft`, `/thetime`, `/nextmap`, `/currentmap` |

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
bind "MOUSE4" "+item2"     // second item (only when the server has 2 item slots)
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

Type `/commands` in game for the full list of chat commands (also in the `/menu`). `/binds` shows the key list.

## 15. Items (perks): enabling and disabling

Every item is its own plugin in `items/`. All 100 are compiled (step 7), but an item only exists
in the game when its plugin is enabled in `addons/amxmodx/configs/plugins-cod.ini`. A disabled
item can't drop, can't be bought or won, and doesn't appear in the admin menu's "give item" list.

How players get items:
- A player who kills someone **while holding no item** gets a random item.
- The shop (`/shop`) and the mystery box can also give a random item.
- `/items` lists every enabled item, `/item` describes yours, `/drop` throws yours away.

The random pick is from the enabled items only, so the list you enable **is** the game's item pool.

### Enabling or disabling an item

In `plugins-cod.ini`, a line starting with `;` is disabled:
```
coditem_regeneracja.amxx       <- enabled
;coditem_aimbot.amxx           <- disabled
```
Remove or add the `;`, then change map (`amx_map de_dust2`) or restart the server.
Keep a newline at the end of the file (see step 8).

Enable every item at once:
```bash
sed -i 's/^;\(coditem_\)/\1/' addons/amxmodx/configs/plugins-cod.ini
```
Classes (`codclass_*`) work the same way. All of them are enabled by default.

With Docker, set `COD_ITEMS=all` in `.env` to enable every item without editing the file, or
`COD_ITEMS=default` to use the list in `plugins-cod.ini`. To choose your own list, edit
`resources/addons/amxmodx/configs/plugins-cod.ini` and rebuild (`up -d --build`), or put your
own copy in `docker/data/overlay/addons/amxmodx/configs/` (that copy then replaces the file
from the repository, including future changes to it).

### The default set

This branch enables 10 items that keep fights fair: no instant kills, no invisibility, no
walking through walls, no respawns and no large damage multipliers. They cover healing, utility,
defence and progression, and Hawk Eye gives everyone a counter to the invisible classes:

Adrenaline, Boots of Hephaestus, Dark Glasses, Electromagnet, First Aid Kit, Hawk Eye,
Recoil Limiter, Regeneration, Ring of Experience, Titanium Bullets.

### All items

**on** = enabled by default. **strong** = can kill instantly, makes the player invisible or
immortal, respawns them, or gives a large boost. Fun on a server with friends, but they can
decide fights on their own; enable them deliberately. Most values are rolled at random within
the range shown when the item is received, and some items can be upgraded in game.

| Item | Plugin | Effect | Notes |
|---|---|---|---|
| Adrenaline | `coditem_adrenalina` | You get +40–60 HP for every frag | **on** |
| Agent 007 | `coditem_agent007` | You have a 1/4–6 chance to instantly kill with a silenced USP | strong |
| Aimbot | `coditem_aimbot` | When used, locks onto the head of the nearest enemy | strong |
| Alien | `coditem_obcy` | Killing an enemy makes them explode, dealing 100–150 (+int) damage | strong |
| Amulet of Agility | `coditem_amuletzwinnosci` | You get +25–50 condition |  |
| Anti Item | `coditem_antyitem` | When used, you can destroy any player's item along with your own |  |
| Archangel's Wings | `coditem_skrzydlaarchaniola` | You have lower gravity. Using the item mid-jump slams you to the ground, causing an earthquake |  |
| Bag of TNT | `coditem_worektnt` | Every round you get 1–3 dynamites |  |
| Bloody Bullets | `coditem_krwawenaboje` | The lower your health, the more damage you deal (-1% health = +1% damage) |  |
| Book of Experience | `coditem_ksiegadoswiadczenia` | You get an extra +80–100 exp for every frag |  |
| Boots of Hephaestus | `coditem_butyhefajstosa` | You take no fall damage. You get +20–25 condition | **on** |
| Brotherhood | `coditem_braterstwo` | When near a teammate you deal 35–50 percent more damage |  |
| Camouflage | `coditem_kamuflarz` | Your visibility drops to 25–35 percent |  |
| Camper's Jacket | `coditem_kurtkakampera` | You are invisible while standing still until you take damage. | strong |
| Captain's Notes | `coditem_notatkikapitana` | You have a 1/2–3 chance to reflect a bullet that hits you | strong |
| Chemist's Apron | `coditem_fartuchchemika` | Every round you get 1–3 poisons |  |
| Cold Bullets | `coditem_zimnekule` | You have a 1/5–7 chance to freeze the enemy for 3 seconds on hit |  |
| Commando's Knife | `coditem_nozkomandosa` | Instant kill with knife (RMB). | strong |
| Commando's Secret | `coditem_tajemnicakomandosa` | You get +25–40 condition and +25 health |  |
| Concrete Body | `coditem_betonowecialo` | When activated, for 10–15s you only take damage from headshots | strong |
| Corporal's Ghost | `coditem_duchkaprala` | When activated, for 7–8s you can walk through walls | strong |
| Croucher | `coditem_kucacz` | You are practically invisible while crouching | strong |
| Cursed Bullets | `coditem_przekletenaboje` | You have a 1/6–9 chance to launch the enemy into the air on hit |  |
| Dark Glasses | `coditem_ciemneokulary` | Flashbangs don't affect you. You get 2 flashes | **on** |
| Deadly AUG | `coditem_smiercionosnyaug` | You have a 1/6–8 chance to instantly kill with AUG | strong |
| Deadly MP5 | `coditem_zabojczemp5` | You get an MP5 that deals +7–12 damage and a 1/2 chance to refill the magazine after a kill |  |
| Deathly Silence | `coditem_grobowacisza` | When you die you explode, dealing 150–175 (+int) damage to nearby enemies | strong |
| Desertion | `coditem_dezercja` | You have a 1/6–7 chance to respawn at the enemy spawn, you get M4A1 or AK47 depending on team and +10 damage with it. | strong |
| Devil's P228 | `coditem_diabelskiep228` | You have a 1/5–7 chance to instantly kill with P228 and +15 damage with it | strong |
| Divine P90 | `coditem_boskiep90` | You get a P90 with unlimited ammo and no recoil | strong |
| Dose of LSD | `coditem_dawkalsd` | You get +15–25 to every stat | strong |
| Dynamite Generator | `coditem_generatordynamitow` | You get a dynamite every 10–15 seconds. |  |
| Electromagnet | `coditem_elektromagnes` | Every round you can place an electromagnet that pulls enemy weapons | **on** |
| Endless Ammo | `coditem_bezlikammo` | Your ammo never runs out | strong |
| Epic Deagle | `coditem_epickideagle` | You get a Deagle with a 1/6 chance to instantly kill and +20–35 damage | strong |
| Extended Kit | `coditem_zestawpowiekszony` | You get 3–5 grenades of each type |  |
| First Aid Kit | `coditem_apteczka` | You can fully heal yourself once per round | **on** |
| Flashlight | `coditem_latarka` | You have a flashlight that reveals all invisible players |  |
| Fury | `coditem_furia` | When activated, for 5–6s you have a 1/3 chance to instantly kill with any weapon. | strong |
| General's Secret | `coditem_tajemnicagenerala` | Instant kill with HE | strong |
| Ghost's MAC10 | `coditem_mac10ducha` | You get a MAC10, with which you are almost invisible | strong |
| Good Cow | `coditem_dobrakrowka` | You get a set of grenades and the Cow (M249), dealing 6–10 extra damage with it |  |
| Grenade Pack | `coditem_pakietgranatow` | You get a full set of grenades |  |
| Hawk Eye | `coditem_sokoleoko` | You see all invisible players | **on** |
| Headhunter Bullets | `coditem_nabojelowcyglow` | You deal 50–75 percent more damage on headshots |  |
| Headless | `coditem_bezglowie` | When activated, for 25–30s you are immune to headshots |  |
| Health Meter | `coditem_licznikzycia` | After damaging an enemy you can see their remaining HP |  |
| Invisibility Cloak | `coditem_pelerynaniewidka` | When used you are invisible until you deal or take damage | strong |
| Jedi Sword | `coditem_mieczjedi` | 1/2 chance to instantly kill with knife and 1/4–5 chance to reflect a bullet with knife | strong |
| Jumper's Ring | `coditem_pierscienskoczka` | You have X extra jumps in the air |  |
| Jumping Madness | `coditem_skoczneszalenstwo` | You have BunnyHop, lower visibility with knife and a 1/3–5 chance to kill with knife |  |
| Last Breath | `coditem_ostatnietchnienie` | When you are about to die you become immortal for 2–3 seconds, then you die | strong |
| Master AWP | `coditem_mistrzowskieawp` | Instant kill with AWP | strong |
| Master Scout | `coditem_mistrzowskiscout` | Instant kill with Scout | strong |
| Medic's Backpack | `coditem_plecakmedyka` | Every round you get 1–3 medkits |  |
| Medic's Knife | `coditem_nozmedyka` | With knife you regenerate 2–3 HP per second |  |
| Mine Generator | `coditem_generatormin` | You get a mine every 10–15 seconds. |  |
| Morphine | `coditem_morfina` | You have a 1/3–5 chance to respawn after death | strong |
| Nano Vest | `coditem_nanokamizelka` | You are immune to rockets, mines, dynamite, lightning and other damaging bonuses. | strong |
| Ninja Suit | `coditem_strojninjy` | You are invisible while standing still with a knife | strong |
| Nomex Armor | `coditem_pancerznomexowy` | You have a 1/5–7 chance to reflect a bullet that hits you | strong |
| O'Zone's Intellect | `coditem_intelektozone` | You have a 1/3–5 chance to redirect your bullet to the head on hit | strong |
| Platinum Bullets | `coditem_platynowenaboje` | You deal 10–20 extra damage |  |
| Plunderer's Gloves | `coditem_rekawiczkigrabiezcy` | You get 20–35 HP and a full magazine after a kill |  |
| Rabbit's Foot | `coditem_kroliczalapka` | You have automatic BunnyHop - hold space |  |
| Radar | `coditem_radar` | You see enemies on the radar |  |
| Rapid Fire | `coditem_szybkostrzelnosc` | You have 20–40 percent faster fire rate |  |
| Recoil Eliminator | `coditem_eliminatorrozrzutu` | You have no recoil with any weapon |  |
| Recoil Limiter | `coditem_ogranicznikrozrzutu` | Your recoil is halved with all weapons | **on** |
| Regeneration | `coditem_regeneracja` | You get 4–6 HP every 3 seconds | **on** |
| Reversal | `coditem_odwrotnosc` | When activated, for 3–4 seconds damage taken heals you. |  |
| Ring of Experience | `coditem_piersciendoswiadczenia` | You get an extra +30–50 exp for every frag | **on** |
| Ring of Zeus | `coditem_pierscienzeusa` | You get 1–3 lightning bolts every round |  |
| Rocket Generator | `coditem_generatorrakiet` | You get a rocket every 10–15 seconds. |  |
| Russian Hat | `coditem_ruskaczapka` | You have a 1/7–11 chance to instantly kill with AK47. You get +25 health | strong |
| Russian Roulette | `coditem_rosyjskaruletka` | When hitting an enemy with Deagle: 5/6 chance to instantly kill and 1/6 chance of suicide. | strong |
| Self Destruct | `coditem_autodestrukcja` | Instant death for you and the enemies close to you | strong |
| Shadow | `coditem_cien` | You are completely invisible, but you only have 1 HP | strong |
| Shocking Bullets | `coditem_porazajacenaboje` | You have a 1/5–7 chance to shake the enemy's screen on hit |  |
| Slowing Bullets | `coditem_pociskispowalniajace` | You have a 1/5–7 chance to slow the enemy for 3 seconds on hit |  |
| Sniper's AWP | `coditem_awpsnajpera` | You deal 150–160 (+int) percent damage with AWP |  |
| Sniper's Secret | `coditem_tajemnicasnajpera` | You have a 50 percent chance to instantly kill with AWP and get +20–30 strength | strong |
| Space Slippers | `coditem_kosmiczneklapki` | You get +25–35 condition and 50 percent lower gravity |  |
| Speedhack | `coditem_speedhack` | You get 75–100 condition | strong |
| Spy's Handbook | `coditem_podrecznikszpiega` | You have a 1/3–6 chance to instantly kill with HE | strong |
| Stalker's Secret | `coditem_tajemnicamysliwego` | You have a 50 percent chance to instantly kill with Scout and get +20–30 condition | strong |
| Stormtrooper's Boots | `coditem_butyszturmowca` | You get +20–30 strength and your footsteps are silent |  |
| Strong AK47 | `coditem_mocneak47` | You get an AK47 that deals 8–13 extra damage |  |
| Sunbeam | `coditem_promienslonca` | You have a 1/5–7 chance to blind the enemy on hit |  |
| Support | `coditem_support` | Nearby teammates deal 30–40 percent more damage |  |
| Support Equipment | `coditem_wyposazeniewsparcia` | Every round you get 1–3 rockets |  |
| Terrorist's Armband | `coditem_opaskaterrorysty` | You deal 6–8 more damage. You have a 50 percent chance to instantly kill with HE | strong |
| Thief's Sense | `coditem_zmyslzlodzieja` | 20 percent chance to steal 1–3 honor on hit. Use to exchange honor for health. |  |
| Titanium Bullets | `coditem_tytanowepociski` | You deal 5–7 (+int) extra damage | **on** |
| Triple Power | `coditem_potrojnamoc` | When used, for 3–5 seconds you deal triple damage | strong |
| Unexpected Blow | `coditem_niespodziewanycios` | On hit you have a 1/5–7 chance to teleport behind the player |  |
| Upgraded M4A1 | `coditem_ulepszonem4a1` | You get an M4A1 that deals 8–13 extra damage |  |
| Veteran's AWP | `coditem_awpweterana` | You have a 50 percent chance to instantly kill with AWP and 30 percent visibility with it. You get +20–25 health | strong |
| Veteran's Galil | `coditem_galilweterana` | You have a 1/6–8 chance to instantly kill with Galil | strong |
| Wolf in Sheep's Clothing | `coditem_farbowanylis` | You have a 1/3–4 chance to respawn at the enemy spawn. You wear the enemy uniform. | strong |

## 16. Item slots (1 or 2 items per player)

By default every player holds **one** item. Admins can give everyone a **second item slot**:
in game, `/ca` → **Item Slots**, or the server command `cod_item_slots 2`. The choice is saved
(in the `cod_settings` nvault) and stays after map changes and restarts. `cod_item_slots` in
`cod_mod.cfg` is only the starting value for a new server.

With 2 slots:
- Every item belongs to **one** slot (`addons/amxmodx/configs/cod_item_slots.ini`):
  **slot 1 = combat** (weapons, damage, invisibility, and all items marked *strong* in step 15),
  **slot 2 = support** (healing, defence, mobility, equipment, experience). So a player can hold
  at most one strong item.
- A kill gives a random item for your empty slot. The shop's random item and the mystery box fill
  an empty slot; if both are full, the shop replaces one of your two items at random.
- `F` uses your first item (or the second, if the first has no use effect); `+item2` or `/item2`
  uses the second. The HUD, `/item` and `/drop` show both; `/items` and the admin menu show each
  item's slot.
- Repairing, upgrading, selling, trading and giving ask which item when you hold two. Trades swap
  items of the same slot only.
- Anti Item destroys one of the target's items at random. The Plunderer class steals an item that
  fits one of its free slots when it can; otherwise one at random (replacing its item in that slot).

Switching:
- **1 → 2**: a support item held in the single slot moves to slot 2. Nobody loses anything.
- **2 → 1**: the second item is removed, unless slot 1 is empty; then it moves into the single
  slot. Players are told in chat.

With 1 slot the slot list is ignored and the game works exactly as before.

### Changing the slot list

Edit `cod_item_slots.ini` (`<item plugin> <slot>` per line), then change map. Some items change
the same thing on the player and would cancel each other out if held together, so they must stay
in the **same** slot:

| Group | Items |
|---|---|
| Invisibility | Veteran's AWP, Shadow, Camouflage, Croucher, Camper's Jacket, Ghost's MAC10, Invisibility Cloak, Jumping Madness, Ninja Suit |
| Bunny hop | Rabbit's Foot, Jumping Madness |
| Gravity | Space Slippers, Archangel's Wings |
| Enemy slow | Slowing Bullets, Cold Bullets |
| Recoil eliminator | Divine P90, Recoil Eliminator |
| Unlimited ammo | Divine P90, Endless Ammo |
| Rocket stock | Rocket Generator, Support Equipment |
| Dynamite stock | Dynamite Generator, Bag of TNT |
| Enemy uniform | Desertion, Wolf in Sheep's Clothing |
| Primary weapon | every item that gives a rifle, SMG, sniper or machine gun |
| Pistol | Epic Deagle, Russian Roulette, Agent 007, Devil's P228 |

The mod checks these groups at every map start: if the file splits a group, the whole group is
moved to slot 1 and the server log says so. Items missing from the file use slot 1 (also logged).

Known side effect: when one slot's item changes, the core turns the other slot's item off and on
again so its effects stay applied. That resets its once-per-round use (for example a First Aid Kit
can be used again) and ends a timed effect that is running (for example the Invisibility Cloak).
It only happens when an item is gained, lost or replaced.

### The default slot list

**Slot 1, combat (65 items):** Agent 007, Aimbot, Alien, Bloody Bullets, Brotherhood, Camouflage, Camper's Jacket, Captain's Notes, Cold Bullets, Commando's Knife, Concrete Body, Corporal's Ghost, Croucher, Cursed Bullets, Deadly AUG, Deadly MP5, Deathly Silence, Desertion, Devil's P228, Divine P90, Dose of LSD, Electromagnet, Endless Ammo, Epic Deagle, Fury, General's Secret, Ghost's MAC10, Good Cow, Headhunter Bullets, Invisibility Cloak, Jedi Sword, Jumping Madness, Last Breath, Master AWP, Master Scout, Morphine, Nano Vest, Ninja Suit, Nomex Armor, O'Zone's Intellect, Platinum Bullets, Rabbit's Foot, Rapid Fire, Recoil Eliminator, Recoil Limiter, Russian Hat, Russian Roulette, Self Destruct, Shadow, Shocking Bullets, Slowing Bullets, Sniper's AWP, Sniper's Secret, Speedhack, Spy's Handbook, Stalker's Secret, Strong AK47, Sunbeam, Terrorist's Armband, Titanium Bullets, Triple Power, Upgraded M4A1, Veteran's AWP, Veteran's Galil, Wolf in Sheep's Clothing.

**Slot 2, support (35 items):** Adrenaline, Amulet of Agility, Anti Item, Archangel's Wings, Bag of TNT, Book of Experience, Boots of Hephaestus, Chemist's Apron, Commando's Secret, Dark Glasses, Dynamite Generator, Extended Kit, First Aid Kit, Flashlight, Grenade Pack, Hawk Eye, Headless, Health Meter, Jumper's Ring, Medic's Backpack, Medic's Knife, Mine Generator, Plunderer's Gloves, Radar, Regeneration, Reversal, Ring of Experience, Ring of Zeus, Rocket Generator, Space Slippers, Stormtrooper's Boots, Support, Support Equipment, Thief's Sense, Unexpected Blow.

Of the 10 items enabled by default, Electromagnet, Recoil Limiter and Titanium Bullets are slot 1;
Adrenaline, Boots of Hephaestus, Dark Glasses, First Aid Kit, Hawk Eye, Regeneration and Ring of
Experience are slot 2.

### For plugin developers

`cod.inc` has slot versions of the item natives: `cod_get_item_slots`, `cod_set_item_slots`,
`cod_get_item_slot`, `cod_get_item_target_slot`, `cod_get_user_slot_item`, `cod_set_user_slot_item`,
`cod_get_user_free_slot`, `cod_get_user_items_count`, `cod_user_has_item`,
`cod_get_slot_item_durability`, `cod_set_slot_item_durability`, `cod_upgrade_user_slot_item`.
The original natives (`cod_get_user_item`, `cod_get_item_durability`, ...) work on slot 1, and
`cod_set_user_item` puts an item into the slot it belongs to.

## 17. Map vote (/rtv) and the command list (/commands)

Two plugins of this fork, enabled in `plugins-cod.ini`: `cod_mapvote.amxx` and `cod_commands.amxx`.

### Changing the map on demand: /rtv

Any player can type `/rtv` (also `rtv` or `/rockthevote`) to ask for a map change. Chat shows how
many are needed, for example `(2/4)`. When enough **human** players have asked (60% by default,
bots don't count), everyone gets a vote:

```
Change the map?
1. Keep current map
2. de_aztec
3. cs_office
...
```

- **Option 1 is always "Keep current map".** The map changes only if the votes for new maps
  together are **more** than the votes to keep it; otherwise it stays. So a few players can start a
  vote, but they can't change the map against the majority. Players who don't vote don't count.
- If a map wins, the map ends like a normal map end: the scoreboard shows, the mod saves everyone's
  progress, and 5 seconds later the server changes to the winning map.
- If the map is kept, `/rtv` is locked for 5 minutes. It is also locked for the first 3 minutes of a
  map and in the last 2.5 minutes, when the normal end-of-map vote (`mapchooser.amxx`) runs anyway.
- The vote offers random maps from the map cycle (`mapcycle.txt`, or the file in the `mapcyclefile`
  cvar), never the current one. Maps that aren't on the server are skipped. To change the list, edit
  `mapcycle.txt` (with Docker: put your own in `docker/data/overlay/mapcycle.txt`) and change map.

Settings, in `cod_mod.cfg`:

| Cvar | Default | Meaning |
|---|---|---|
| `cod_rtv_ratio` | `0.6` | Share of human players who must type `/rtv`. `0.05` lets one player start the vote |
| `cod_rtv_delay` | `180` | Seconds after map start before `/rtv` works |
| `cod_rtv_maps` | `5` | Maps offered, next to "Keep current map" (max 7) |
| `cod_rtv_vote_time` | `15` | Seconds the vote lasts |
| `cod_rtv_cooldown` | `300` | Seconds `/rtv` stays locked after a vote kept the map |
| `cod_rtv_block_end` | `150` | No `/rtv` when fewer seconds than this are left |
| `cod_rtv_change_delay` | `5` | Seconds between the result and the map change |

Admins can still change the map directly with `amx_map <map>` or `amxmodmenu` → Maps.

### Time and map info

| Chat | Shows |
|---|---|
| `/timeleft` | Time left on this map (`mp_timelimit` in `server.cfg`) |
| `/thetime` | Server time and date (set the timezone with `TZ`, see Docker) |
| `/nextmap` | Next map: the vote winner, or the next one in the map cycle |
| `/currentmap` | Current map |

### All chat commands: /commands

`/commands` (or `/cmds`, or "Chat Commands" at the top of `/menu`) opens a menu of categories:
General, Class and Level, Items, Abilities, Honor/Shop/Market, Clan and Missions, Stats, Settings,
Map and Time. Each entry shows the command and what it does; picking it runs the command. The full
list is also printed to the player's console. Commands of disabled plugins aren't listed, and
`/item2` only appears when 2 item slots are on.

When you add a plugin with its own chat commands, add them to the `commands` table at the top of
`cod_commands.sma` so they appear in the list.

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
- `YAPB_CAMP_MIN` / `YAPB_CAMP_MAX` (default 5 / 15 seconds) set how long bots wait in one spot.
- `YAPB_CHAT=ms`: bots chat in casual Malay-English with some Penang loghat (`ms_chat.cfg`); empty for YaPB's English.
- `YAPB_NAMES`: bot names, comma separated, e.g. `YAPB_NAMES=Ahmad,Hafiz,Faizal,Wei Jie,Ah Seng,Kumar`.
  Bots only use these names. Empty means YaPB's own list. Give at least as many names as `YAPB_QUOTA`.
- The container runs `hlds_linux` directly. `quit` or a crash stops the container and the
  `restart: unless-stopped` policy starts it again, so the `hlds_run`/`-pidfile` issue from step 11 doesn't apply here.
- Only `27015/udp` needs to be published: GoldSrc uses UDP for both the game and rcon.
- The image runs the ReHLDS engine and loads Reunion. Set `REUNION_SALT` in `.env` to a secret
  of 16+ characters (`openssl rand -hex 16`) and keep it: it changes every non-Steam player's
  SteamID. Without it the container uses a random salt at each start and logs a warning.
- Set `TZ` in `.env` to your timezone (for example `TZ=Asia/Kuala_Lumpur`); the default is UTC.
  It sets the server clock, so log times, the "current time" and last-visit messages, and the
  night exp bonus hours (`cod_night_exp_from` / `cod_night_exp_to` in `cod_mod.cfg`) use local time.
  Saved data is not affected: the mod stores times as Unix timestamps.

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

### Going public (sv_lan 0)

The image already has ReHLDS and Reunion, so Steam and non-Steam clients can join a public server:
1. Forward the game port so the server sees each player's **real** IP (not a userspace proxy
   like the setup above). Otherwise IP bans, anti-flood and Reunion's IP-based SteamIDs treat
   everyone as one player.
2. Set `SV_LAN=0` in `.env`.
3. Set `IDClientsLimit = 1` in `resources/reunion.cfg` (rebuild), or put your own `reunion.cfg`
   in `docker/data/overlay/`.
4. `docker compose ... up -d`, then check the console: Reunion logs each player's client type.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `/rtv` says "no other maps in the map cycle" | `mapcycle.txt` lists no other map that exists in `cstrike/maps/`. Add maps to it (step 17). |
| `/rtv` does nothing, or players never reach the needed count | It's locked at map start, after a kept vote and near the map end (chat says why). Lower `cod_rtv_ratio` for small groups. |
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
