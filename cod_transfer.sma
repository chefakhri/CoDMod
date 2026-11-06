#include <amxmodx>
#include <cstrike>
#include <cod>

#define PLUGIN "CoD Transfer"
#define VERSION "1.1.1"
#define AUTHOR "O'Zone"

new const commandTransfer[][] = { "przelej", "say /przelew", "say_team /przelew", "say /przelej", "say_team /przelej", "say /transfer", "say_team /transfer" };

new transferPlayer[MAX_PLAYERS + 1], bool:mapEnd;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	for (new i; i < sizeof commandTransfer; i++) register_clcmd(commandTransfer[i], "transfer_menu");

	register_clcmd("HONOR_AMOUNT", "transfer_honor_handle");
}

public cod_end_map()
	mapEnd = true;

public transfer_menu(id)
{
	if (!is_user_connected(id) || !cod_check_account(id) || mapEnd) return PLUGIN_HANDLED;

	client_cmd(id, "spk %s", codSounds[SOUND_SELECT]);

	new menuData[256], playerName[MAX_NAME], playerId[3], players, menu = menu_create("\ySelect the \rPlayer\y you want to transfer \rHonor\y to\w:", "transfer_menu_handle");

	for (new player = 1; player <= MAX_PLAYERS; player++) {
		if (!is_user_connected(player) || !cod_get_user_class(player) || player == id) continue;

		get_user_name(player, playerName, charsmax(playerName));

		formatex(menuData, charsmax(menuData), "%s \y[%d Honor]", playerName, cod_get_user_honor(player));

		num_to_str(player, playerId, charsmax(playerId));

		menu_additem(menu, menuData, playerId);

		players++;
	}

	menu_setprop(menu, MPROP_EXITNAME, "Exit");
	menu_setprop(menu, MPROP_BACKNAME, "Back");
	menu_setprop(menu, MPROP_NEXTNAME, "Next");

	if (!players) {
		menu_destroy(menu);

		cod_print_chat(id, "There is no player on the server you could transfer^x03 honor^x01 to!");
	} else menu_display(id, menu);

	return PLUGIN_HANDLED;
}

public transfer_menu_handle(id, menu, item)
{
	if (!is_user_connected(id) || !cod_check_account(id) || mapEnd) return PLUGIN_HANDLED;

	if (item == MENU_EXIT) {
		client_cmd(id, "spk %s", codSounds[SOUND_EXIT]);

		menu_destroy(menu);

		return PLUGIN_HANDLED;
	}

	client_cmd(id, "spk %s", codSounds[SOUND_SELECT]);

	new playerId[3], itemAccess, itemCallback;

	menu_item_getinfo(menu, item, itemAccess, playerId, charsmax(playerId), _, _, itemCallback);

	new player = str_to_num(playerId);

	menu_destroy(menu);

	if (!is_user_connected(player)) {
		cod_print_chat(id, "This player is no longer on the server!");

		return PLUGIN_HANDLED;
	}

	transferPlayer[id] = player;

	client_cmd(id, "messagemode HONOR_AMOUNT");

	cod_print_chat(id, "Enter the amount of^x03 honor^x01 you want to transfer!");

	client_print(id, print_center, "Enter the amount of honor you want to transfer!");

	return PLUGIN_HANDLED;
}

public transfer_honor_handle(id)
{
	if (!is_user_connected(id) || !cod_check_account(id) || mapEnd) return PLUGIN_HANDLED;

	client_cmd(id, "spk %s", codSounds[SOUND_EXIT]);

	if (!is_user_connected(transferPlayer[id])) {
		cod_print_chat(id, "The player you want to transfer^x03 honor^x01 to is no longer on the server!");

		return PLUGIN_HANDLED;
	}

	new honorData[16], honorAmount;

	read_args(honorData, charsmax(honorData));
	remove_quotes(honorData);

	honorAmount = str_to_num(honorData);

	if (honorAmount <= 0) {
		cod_print_chat(id, "You can't transfer less than^x03 1 honor^x01!");

		return PLUGIN_HANDLED;
	}

	if (cod_get_user_honor(id) < honorAmount) {
		cod_print_chat(id, "You don't have that much^x03 honor^x01!");

		return PLUGIN_HANDLED;
	}

	new playerName[MAX_NAME], playerIdName[MAX_NAME];

	get_user_name(id, playerName, charsmax(playerName));
	get_user_name(transferPlayer[id], playerIdName, charsmax(playerIdName));

	cod_set_user_honor(transferPlayer[id], cod_get_user_honor(transferPlayer[id]) + honorAmount);
	cod_set_user_honor(id, cod_get_user_honor(id) - honorAmount);

	cod_print_chat(0, "^x03%s^x01 transferred^x04 %i honor^x01 to^x03 %s^x01.", playerName, honorAmount, playerIdName);

	return PLUGIN_HANDLED;
}