#include <amxmodx>
#include <cod>

#define PLUGIN  "CoD Map Vote"
#define VERSION "1.0.0"
#define AUTHOR  "chefakhri"

// Rock the vote: players vote to change the map early. When enough human players type /rtv,
// a map vote starts. Option 1 is always "Keep current map": the map only changes if the votes
// for new maps together outnumber the votes to keep it. If a map wins, the map is ended the same
// way as a normal map end (scoreboard, and the mod saves everyone's data) and the server changes to it.
// Also adds /timeleft, /thetime, /nextmap and /currentmap.

#define TASK_VOTE_END   7301
#define TASK_CHANGE     7302

#define MAX_VOTE_MAPS   7
#define MAX_MAP_NAME    32

new const commandRtv[][] = { "rtv", "say /rtv", "say_team /rtv", "say rtv", "say_team rtv", "say /rockthevote", "say_team /rockthevote", "say rockthevote", "say_team rockthevote" };
new const commandTimeleft[][] = { "say /timeleft", "say_team /timeleft" };
new const commandTheTime[][] = { "say /thetime", "say_team /thetime" };
new const commandNextmap[][] = { "say /nextmap", "say_team /nextmap" };
new const commandCurrentmap[][] = { "say /currentmap", "say_team /currentmap" };

new Float:cvarRatio, cvarDelay, cvarMaps, cvarVoteTime, cvarCooldown, cvarBlockEnd, cvarChangeDelay;

new Array:mapList, rtvVoted, rtvCount, bool:voteRunning, bool:changingMap, Float:lastVoteEnd, nextMap[MAX_MAP_NAME],
	voteMaps[MAX_VOTE_MAPS][MAX_MAP_NAME], voteCounts[MAX_VOTE_MAPS + 1], voteOptions, playerMenu[MAX_PLAYERS + 1];

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	bind_pcvar_float(create_cvar("cod_rtv_ratio", "0.6", _, "Share of human players needed to start a map vote", true, 0.05, true, 1.0), cvarRatio);
	bind_pcvar_num(create_cvar("cod_rtv_delay", "180", _, "Seconds after map start before /rtv is allowed", true, 0.0), cvarDelay);
	bind_pcvar_num(create_cvar("cod_rtv_maps", "5", _, "Maps offered in the vote", true, 1.0, true, float(MAX_VOTE_MAPS)), cvarMaps);
	bind_pcvar_num(create_cvar("cod_rtv_vote_time", "15", _, "Seconds the vote lasts", true, 5.0, true, 60.0), cvarVoteTime);
	bind_pcvar_num(create_cvar("cod_rtv_cooldown", "300", _, "Seconds before /rtv is allowed again after the map was kept", true, 0.0), cvarCooldown);
	bind_pcvar_num(create_cvar("cod_rtv_block_end", "150", _, "No /rtv when fewer seconds than this are left (the end-of-map vote runs then)", true, 0.0), cvarBlockEnd);
	bind_pcvar_num(create_cvar("cod_rtv_change_delay", "5", _, "Seconds between the vote result and the map change", true, 1.0, true, 30.0), cvarChangeDelay);

	for (new i; i < sizeof commandRtv; i++) register_clcmd(commandRtv[i], "rock_the_vote");
	for (new i; i < sizeof commandTimeleft; i++) register_clcmd(commandTimeleft[i], "show_timeleft");
	for (new i; i < sizeof commandTheTime; i++) register_clcmd(commandTheTime[i], "show_thetime");
	for (new i; i < sizeof commandNextmap; i++) register_clcmd(commandNextmap[i], "show_nextmap");
	for (new i; i < sizeof commandCurrentmap; i++) register_clcmd(commandCurrentmap[i], "show_currentmap");

	mapList = ArrayCreate(MAX_MAP_NAME);
}

public plugin_cfg()
	load_map_list();

public plugin_end()
	ArrayDestroy(mapList);

public client_disconnected(id)
{
	if (get_bit(id, rtvVoted)) {
		rem_bit(id, rtvVoted);

		rtvCount--;
	}

	playerMenu[id] = 0;

	// Fewer players may mean the remaining votes are now enough
	if (rtvCount > 0 && !voteRunning && !changingMap && rtvCount >= votes_needed(id)) start_vote();
}

public rock_the_vote(id)
{
	if (!is_user_connected(id) || is_user_bot(id)) return PLUGIN_HANDLED;

	if (changingMap) {
		cod_print_chat(id, "The map is already changing.");

		return PLUGIN_HANDLED;
	}

	if (voteRunning) {
		cod_print_chat(id, "A map vote is already running.");

		return PLUGIN_HANDLED;
	}

	new Float:wait = float(cvarDelay) - get_gametime();

	if (wait > 0.0) {
		cod_print_chat(id, "You can rock the vote in^x03 %i^x01 seconds (the map just started).", floatround(wait, floatround_ceil));

		return PLUGIN_HANDLED;
	}

	if (lastVoteEnd > 0.0) {
		wait = lastVoteEnd + float(cvarCooldown) - get_gametime();

		if (wait > 0.0) {
			cod_print_chat(id, "The map was just kept. You can rock the vote again in^x03 %i^x01 seconds.", floatround(wait, floatround_ceil));

			return PLUGIN_HANDLED;
		}
	}

	if (get_cvar_float("mp_timelimit") > 0.0 && get_timeleft() < cvarBlockEnd) {
		cod_print_chat(id, "The map is almost over: the end-of-map vote will start soon.");

		return PLUGIN_HANDLED;
	}

	new needed = votes_needed();

	if (get_bit(id, rtvVoted)) {
		cod_print_chat(id, "You already rocked the vote^x03 (%i/%i)^x01.", rtvCount, needed);

		return PLUGIN_HANDLED;
	}

	set_bit(id, rtvVoted);

	rtvCount++;

	if (rtvCount >= needed) {
		start_vote();

		return PLUGIN_HANDLED;
	}

	new playerName[MAX_NAME];

	get_user_name(id, playerName, charsmax(playerName));

	cod_print_chat(0, "^x03%s^x01 wants to change the map^x03 (%i/%i)^x01. Type^x04 /rtv^x01 to vote for a change.", playerName, rtvCount, needed);

	return PLUGIN_HANDLED;
}

stock votes_needed(skip = 0)
{
	new humans;

	for (new i = 1; i <= MAX_PLAYERS; i++) {
		if (i == skip || !is_user_connected(i) || is_user_bot(i) || is_user_hltv(i)) continue;

		humans++;
	}

	return max(1, floatround(float(humans) * cvarRatio, floatround_ceil));
}

stock start_vote()
{
	if (voteRunning || changingMap) return;

	new currentMap[MAX_MAP_NAME], mapName[MAX_MAP_NAME], candidates[256], count;

	get_mapname(currentMap, charsmax(currentMap));

	for (new i = 0; i < ArraySize(mapList) && count < sizeof candidates; i++) {
		ArrayGetString(mapList, i, mapName, charsmax(mapName));

		if (!equali(mapName, currentMap)) candidates[count++] = i;
	}

	if (!count) {
		cod_print_chat(0, "Map vote cancelled: no other maps in the map cycle.");

		reset_rtv();

		return;
	}

	// Pick random maps without repeats
	voteOptions = 0;

	while (voteOptions < cvarMaps && count) {
		new pick = random(count);

		ArrayGetString(mapList, candidates[pick], voteMaps[voteOptions], charsmax(voteMaps[]));

		candidates[pick] = candidates[--count];

		voteOptions++;
	}

	arrayset(voteCounts, 0, sizeof voteCounts);

	voteRunning = true;

	for (new id = 1; id <= MAX_PLAYERS; id++) {
		if (!is_user_connected(id) || is_user_bot(id) || is_user_hltv(id)) continue;

		show_vote_menu(id);
	}

	cod_print_chat(0, "Enough players want a new map:^x03 vote now^x01 (%i seconds).", cvarVoteTime);

	set_task(float(cvarVoteTime), "end_vote", TASK_VOTE_END);
}

stock show_vote_menu(id)
{
	new menu = menu_create("\yChange the map?\w^n\dThe map changes only if new maps get more votes than keeping it\w", "vote_menu_handle");

	menu_additem(menu, "\yKeep current map^n");

	for (new i = 0; i < voteOptions; i++) menu_additem(menu, voteMaps[i]);

	menu_setprop(menu, MPROP_PERPAGE, 0);
	menu_setprop(menu, MPROP_EXIT, MEXIT_NEVER);

	playerMenu[id] = menu;

	menu_display(id, menu, 0, cvarVoteTime);
}

public vote_menu_handle(id, menu, item)
{
	if (playerMenu[id] == menu) playerMenu[id] = 0;

	menu_destroy(menu);

	if (!voteRunning || !is_user_connected(id) || item < 0 || item > voteOptions) return PLUGIN_HANDLED;

	voteCounts[item]++;

	new playerName[MAX_NAME];

	get_user_name(id, playerName, charsmax(playerName));

	if (!item) cod_print_chat(0, "^x03%s^x01 voted to^x04 keep the current map^x01.", playerName);
	else cod_print_chat(0, "^x03%s^x01 voted for^x04 %s^x01.", playerName, voteMaps[item - 1]);

	return PLUGIN_HANDLED;
}

public end_vote()
{
	if (!voteRunning) return;

	voteRunning = false;

	// Close menus of players who didn't vote
	for (new id = 1; id <= MAX_PLAYERS; id++) {
		if (playerMenu[id] && is_user_connected(id)) show_menu(id, 0, "^n", 1);

		playerMenu[id] = 0;
	}

	// voteCounts[0] = keep the current map, voteCounts[1..voteOptions] = maps
	new keepVotes = voteCounts[0], changeVotes, best = -1, bestVotes, ties[MAX_VOTE_MAPS], tieCount;

	for (new i = 1; i <= voteOptions; i++) {
		changeVotes += voteCounts[i];

		if (voteCounts[i] > bestVotes) {
			bestVotes = voteCounts[i];
			tieCount = 0;
			ties[tieCount++] = i - 1;
		} else if (voteCounts[i] == bestVotes && bestVotes > 0) {
			ties[tieCount++] = i - 1;
		}
	}

	// The map changes only if more players voted for a change than for keeping the map
	if (changeVotes <= keepVotes || !tieCount) {
		if (!keepVotes && !changeVotes) cod_print_chat(0, "Nobody voted:^x03 the current map stays^x01.");
		else cod_print_chat(0, "The vote is over:^x03 the current map stays^x01 (keep %i, change %i).", keepVotes, changeVotes);

		reset_rtv();

		lastVoteEnd = get_gametime();

		return;
	}

	best = ties[random(tieCount)];

	copy(nextMap, charsmax(nextMap), voteMaps[best]);

	changingMap = true;

	set_cvar_string("amx_nextmap", nextMap);

	cod_print_chat(0, "The vote is over (keep %i, change %i): changing the map to^x04 %s^x01 in^x03 %i^x01 seconds.", keepVotes, changeVotes, nextMap, cvarChangeDelay);

	log_amx("Rock the vote: changing map to %s (keep %i, change %i, %s got %i).", nextMap, keepVotes, changeVotes, nextMap, bestVotes);

	// Show the end-of-map scoreboard to everyone
	message_begin(MSG_ALL, SVC_INTERMISSION);
	message_end();

	// AMXX doesn't pass a message sent by a plugin to other plugins' register_message hooks, so the
	// mod wouldn't notice this map end. Run its map-end handler directly: it marks the map as ending,
	// tells the other CoD plugins (stats, clans, honor, ...) to save, and saves every player, just
	// like at a normal map end.
	if (callfunc_begin("message_intermission", "cod_mod.amxx") == 1) callfunc_end();
	else log_amx("Rock the vote: cod_mod.amxx not found, player data is saved on disconnect only.");

	set_task(float(cvarChangeDelay), "change_map", TASK_CHANGE);
}

public change_map()
	server_cmd("changelevel ^"%s^"", nextMap);

stock reset_rtv()
{
	rtvVoted = 0;
	rtvCount = 0;
}

public show_timeleft(id)
{
	if (get_cvar_float("mp_timelimit") <= 0.0) {
		cod_print_chat(id, "This map has^x03 no time limit^x01.");

		return PLUGIN_CONTINUE;
	}

	new timeLeft = get_timeleft();

	cod_print_chat(id, "Time left on this map:^x03 %d:%02d^x01.", timeLeft / 60, timeLeft % 60);

	return PLUGIN_CONTINUE;
}

public show_thetime(id)
{
	new timeData[32];

	get_time("%H:%M:%S (%d.%m.%Y)", timeData, charsmax(timeData));

	cod_print_chat(id, "The current time is^x03 %s^x01.", timeData);

	return PLUGIN_CONTINUE;
}

public show_nextmap(id)
{
	new mapName[MAX_MAP_NAME];

	if (changingMap) copy(mapName, charsmax(mapName), nextMap);
	else get_cvar_string("amx_nextmap", mapName, charsmax(mapName));

	if (mapName[0]) cod_print_chat(id, "Next map:^x03 %s^x01.", mapName);
	else cod_print_chat(id, "The next map has not been chosen yet.");

	return PLUGIN_CONTINUE;
}

public show_currentmap(id)
{
	new mapName[MAX_MAP_NAME];

	get_mapname(mapName, charsmax(mapName));

	cod_print_chat(id, "Current map:^x03 %s^x01.", mapName);

	return PLUGIN_CONTINUE;
}

stock load_map_list()
{
	new fileName[64], lineData[64], mapName[MAX_MAP_NAME];

	get_cvar_string("mapcyclefile", fileName, charsmax(fileName));

	if (!fileName[0]) copy(fileName, charsmax(fileName), "mapcycle.txt");

	new file = fopen(fileName, "rt");

	if (!file) {
		log_amx("Can't open %s: rock the vote has no maps.", fileName);

		return;
	}

	while (!feof(file)) {
		fgets(file, lineData, charsmax(lineData));

		trim(lineData);

		if (!lineData[0] || lineData[0] == ';' || (lineData[0] == '/' && lineData[1] == '/')) continue;

		parse(lineData, mapName, charsmax(mapName));

		if (!is_map_valid(mapName) || ArrayFindString(mapList, mapName) != -1) continue;

		ArrayPushString(mapList, mapName);
	}

	fclose(file);
}
