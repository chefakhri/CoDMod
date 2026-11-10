#include <amxmodx>
#include <cod>

#define PLUGIN  "CoD Commands"
#define VERSION "1.0.0"
#define AUTHOR  "chefakhri"

// /commands: lists the chat commands of every plugin that is running, by category.
// Picking a command in the menu runs it. The full list is also printed to the console.

new const commandList[][] = { "cod_commands", "say /commands", "say_team /commands", "say /cmds", "say_team /cmds", "say /cmd", "say_team /cmd" };

new const categoryNames[][] = {
	"General",
	"Class and Level",
	"Items",
	"Abilities",
	"Honor, Shop and Market",
	"Clan and Missions",
	"Stats and Rankings",
	"Settings",
	"Map and Time"
};

enum _:commandInfo { CMD_CATEGORY, CMD_TEXT[24], CMD_DESC[64], CMD_PLUGIN[32] };

// Category, command, description, plugin that provides it ("" = always shown)
new const commands[][commandInfo] = {
	{ 0, "/menu",        "Main menu (also /help, V key)",    "cod_menu.amxx" },
	{ 0, "/commands",    "This list",                        "" },
	{ 0, "/binds",       "Keys and ability binds",           "cod_mod.amxx" },
	{ 0, "/account",     "Account and password",             "cod_accounts.amxx" },

	{ 1, "/class",       "Choose your class",                "cod_mod.amxx" },
	{ 1, "/classes",     "Class descriptions",               "cod_mod.amxx" },
	{ 1, "/points",      "Spend skill points",               "cod_mod.amxx" },
	{ 1, "/reset",       "Reset skill points",               "cod_mod.amxx" },

	{ 2, "/item",        "Describe your item(s)",            "cod_mod.amxx" },
	{ 2, "/item2",       "Use your second item",             "cod_mod.amxx" },
	{ 2, "/items",       "All item descriptions",            "cod_mod.amxx" },
	{ 2, "/drop",        "Drop an item",                     "cod_mod.amxx" },
	{ 2, "/exchange",    "Trade items with a player",        "cod_exchange.amxx" },
	{ 2, "/give",        "Give your item to a player",       "cod_exchange.amxx" },

	{ 3, "/rocket",      "Fire a rocket",                    "cod_mod.amxx" },
	{ 3, "/mine",        "Place a mine",                     "cod_mod.amxx" },
	{ 3, "/dynamite",    "Throw dynamite",                   "cod_mod.amxx" },
	{ 3, "/medkit",      "Place a medkit",                   "cod_mod.amxx" },
	{ 3, "/poison",      "Throw poison",                     "cod_mod.amxx" },
	{ 3, "/thunder",     "Strike with lightning",            "cod_mod.amxx" },
	{ 3, "/teleport",    "Teleport",                         "cod_mod.amxx" },

	{ 4, "/shop",        "Buy with honor",                   "cod_shop.amxx" },
	{ 4, "/market",      "Player market",                    "cod_market.amxx" },
	{ 4, "/sell",        "Sell an item on the market",       "cod_market.amxx" },
	{ 4, "/buy",         "Buy an item from the market",      "cod_market.amxx" },
	{ 4, "/withdraw",    "Take back your market item",       "cod_market.amxx" },
	{ 4, "/casino",      "Casino: dice, coin, roulette",     "cod_casino.amxx" },
	{ 4, "/transfer",    "Send honor to a player",           "cod_transfer.amxx" },

	{ 5, "/clan",        "Clan menu",                        "cod_clans.amxx" },
	{ 5, "/missions",    "Choose a mission",                 "cod_missions.amxx" },
	{ 5, "/progress",    "Your mission progress",            "cod_missions.amxx" },
	{ 5, "/abandon",     "Abandon your mission",             "cod_missions.amxx" },

	{ 6, "/statsmenu",   "Stats menu",                       "cod_stats.amxx" },
	{ 6, "/toplevel",    "Top players by level",             "cod_mod.amxx" },
	{ 6, "/time",        "Your play time",                   "cod_stats.amxx" },
	{ 6, "/toptime",     "Top play time",                    "cod_stats.amxx" },
	{ 6, "/medals",      "Your medals",                      "cod_stats.amxx" },
	{ 6, "/topmedals",   "Top medals",                       "cod_stats.amxx" },
	{ 6, "/beststats",   "Your best stats ranking",          "cod_stats.amxx" },
	{ 6, "/rank",        "Your rank",                        "statsx.amxx" },
	{ 6, "/top15",       "Top 15 players",                   "statsx.amxx" },
	{ 6, "/statsme",     "Your stats this map",              "statsx.amxx" },

	{ 7, "/hud",         "HUD position and color",           "cod_mod.amxx" },
	{ 7, "/icons",       "Icon settings",                    "cod_icons.amxx" },
	{ 7, "/sounds",      "Sound settings",                   "cod_stats.amxx" },
	{ 7, "/knife",       "Choose a knife model",             "cod_knife.amxx" },
	{ 7, "/vip",         "VIP information",                  "cod_vip.amxx" },
	{ 7, "/vips",        "VIPs online",                      "cod_vip.amxx" },

	{ 8, "/rtv",         "Vote to change the map",           "cod_mapvote.amxx" },
	{ 8, "/timeleft",    "Time left on this map",            "cod_mapvote.amxx" },
	{ 8, "/thetime",     "Current server time",              "cod_mapvote.amxx" },
	{ 8, "/nextmap",     "Next map",                         "cod_mapvote.amxx" },
	{ 8, "/currentmap",  "Current map",                      "cod_mapvote.amxx" }
};

new selectedCategory[MAX_PLAYERS + 1];

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	for (new i; i < sizeof commandList; i++) register_clcmd(commandList[i], "show_categories");
}

stock bool:command_available(i)
{
	if (equal(commands[i][CMD_TEXT], "/item2") && cod_get_item_slots() < 2) return false;

	return !commands[i][CMD_PLUGIN][0] || is_plugin_loaded(commands[i][CMD_PLUGIN], true) != -1;
}

public show_categories(id)
{
	if (!is_user_connected(id)) return PLUGIN_HANDLED;

	print_console_list(id);

	new menu = menu_create("\yChat \rCommands\w^n\dFull list printed to your console\w", "categories_handle"), categoryId[4], bool:hasCommands;

	for (new c = 0; c < sizeof categoryNames; c++) {
		hasCommands = false;

		for (new i = 0; i < sizeof commands; i++) {
			if (commands[i][CMD_CATEGORY] == c && command_available(i)) {
				hasCommands = true;

				break;
			}
		}

		if (!hasCommands) continue;

		num_to_str(c, categoryId, charsmax(categoryId));

		menu_additem(menu, categoryNames[c], categoryId);
	}

	menu_setprop(menu, MPROP_EXITNAME, "Exit");
	menu_setprop(menu, MPROP_BACKNAME, "Back");
	menu_setprop(menu, MPROP_NEXTNAME, "Next");

	menu_display(id, menu);

	return PLUGIN_HANDLED;
}

public categories_handle(id, menu, item)
{
	if (!is_user_connected(id) || item == MENU_EXIT) {
		menu_destroy(menu);

		return PLUGIN_HANDLED;
	}

	new categoryId[4], itemAccess, itemCallback;

	menu_item_getinfo(menu, item, itemAccess, categoryId, charsmax(categoryId), _, _, itemCallback);

	menu_destroy(menu);

	selectedCategory[id] = str_to_num(categoryId);

	show_category(id);

	return PLUGIN_HANDLED;
}

stock show_category(id)
{
	new title[96], menuData[128], commandId[4], category = selectedCategory[id];

	formatex(title, charsmax(title), "\y%s\w^n\dPick a command to run it\w", categoryNames[category]);

	new menu = menu_create(title, "category_handle");

	for (new i = 0; i < sizeof commands; i++) {
		if (commands[i][CMD_CATEGORY] != category || !command_available(i)) continue;

		formatex(menuData, charsmax(menuData), "\r%s \w- %s", commands[i][CMD_TEXT], commands[i][CMD_DESC]);

		num_to_str(i, commandId, charsmax(commandId));

		menu_additem(menu, menuData, commandId);
	}

	menu_setprop(menu, MPROP_EXITNAME, "Back to categories");
	menu_setprop(menu, MPROP_BACKNAME, "Back");
	menu_setprop(menu, MPROP_NEXTNAME, "Next");

	menu_display(id, menu);
}

public category_handle(id, menu, item)
{
	if (!is_user_connected(id)) {
		menu_destroy(menu);

		return PLUGIN_HANDLED;
	}

	if (item == MENU_EXIT) {
		menu_destroy(menu);

		show_categories(id);

		return PLUGIN_HANDLED;
	}

	new commandId[4], itemAccess, itemCallback;

	menu_item_getinfo(menu, item, itemAccess, commandId, charsmax(commandId), _, _, itemCallback);

	menu_destroy(menu);

	new i = str_to_num(commandId);

	if (i < 0 || i >= sizeof commands) return PLUGIN_HANDLED;

	// Runs the command as if the player typed it in chat
	amxclient_cmd(id, "say", commands[i][CMD_TEXT]);

	return PLUGIN_HANDLED;
}

stock print_console_list(id)
{
	client_print(id, print_console, "^n===== CoD Mod chat commands =====");

	for (new c = 0; c < sizeof categoryNames; c++) {
		new bool:header;

		for (new i = 0; i < sizeof commands; i++) {
			if (commands[i][CMD_CATEGORY] != c || !command_available(i)) continue;

			if (!header) {
				client_print(id, print_console, "^n-- %s --", categoryNames[c]);

				header = true;
			}

			client_print(id, print_console, "  %-12s %s", commands[i][CMD_TEXT], commands[i][CMD_DESC]);
		}
	}

	client_print(id, print_console, "^nKeys: E = class skill (crouch + E: rockets, mines, ...), F = item. Type /binds for details.^n");
}
