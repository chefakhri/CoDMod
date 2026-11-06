#include <amxmodx>
#include <cod>

#define PLUGIN "CoD Exchange"
#define VERSION "1.2.0"
#define AUTHOR "O'Zone"

new const commandExchange[][] = { "wymien", "say /exchange", "say_team /exchange", "say /zamien", "say_team /zamien", "say /wymien", "say_team /wymien" };
new const commandGive[][] = { "daj", "say /give", "say_team /give", "say /oddaj", "say_team /oddaj", "say /daj", "say_team /daj" };

new bool:mapEnd, blockExchange, cooldown;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	for (new i; i < sizeof commandExchange; i++) register_clcmd(commandExchange[i], "exchange_menu");
	for (new i; i < sizeof commandGive; i++) register_clcmd(commandGive[i], "give_item");
}

public cod_end_map()
	mapEnd = true;

public cod_new_round()
	for (new i = 1; i <= MAX_PLAYERS; i++) rem_bit(i, cooldown);

public exchange_menu(id)
{
	if (!is_user_connected(id) || !cod_check_account(id) || mapEnd) return PLUGIN_HANDLED;

	client_cmd(id, "spk %s", codSounds[SOUND_SELECT]);

	new menuData[64], menu = menu_create("\yExchange \rMenu", "exchange_menu_handle");

	menu_additem(menu, "Trade \yItem \r(/exchange)^n");

	formatex(menuData, charsmax(menuData), "Trade \yOffers \d[\r%s\d]", get_bit(id, blockExchange) ? "Blocked" : "Allowed");

	menu_additem(menu, menuData);

	menu_setprop(menu, MPROP_EXITNAME, "Exit");

	menu_display(id, menu);

	return PLUGIN_HANDLED;
}

public exchange_menu_handle(id, menu, item)
{
	if (!is_user_connected(id) || !cod_check_account(id) || mapEnd) return PLUGIN_HANDLED;

	if (item == MENU_EXIT) {
		menu_destroy(menu);

		client_cmd(id, "spk %s", codSounds[SOUND_EXIT]);

		return PLUGIN_HANDLED;
	}

	client_cmd(id, "spk %s", codSounds[SOUND_SELECT]);

	switch (item) {
		case 0: exchange_item(id, 1);
		case 1: {
			if (get_bit(id, blockExchange)) {
				rem_bit(id, blockExchange);

				cod_print_chat(id, "You have^x03 unblocked^x01 item trade offers sent to you!");
			} else {
				set_bit(id, blockExchange);

				cod_print_chat(id, "You have^x03 blocked^x01 item trade offers sent to you!");
			}
		}
	}

	menu_destroy(menu);

	return PLUGIN_HANDLED;
}

public exchange_item(id, sound)
{
	if (!is_user_connected(id) || !cod_check_account(id) || mapEnd) return PLUGIN_HANDLED;

	if (!sound) client_cmd(id, "spk %s", codSounds[SOUND_SELECT]);

	new menuData[128], playerName[MAX_NAME], itemName[MAX_NAME], playerId[3], players, menu = menu_create("\yTrade \rItem", "exchange_item_handle");

	for (new player = 1; player <= MAX_PLAYERS; player++) {
		if (!is_user_connected(player) || id == player || !cod_get_user_class(player) || !cod_get_user_item(player) || get_bit(player, blockExchange)) continue;

		cod_get_item_name(cod_get_user_item(player), itemName, charsmax(itemName));

		get_user_name(player, playerName, charsmax(playerName));

		formatex(menuData, charsmax(menuData), "%s \y(%s)", playerName, itemName);

		num_to_str(player, playerId, charsmax(playerId));

		menu_additem(menu, menuData, playerId);

		players++;
	}

	menu_setprop(menu, MPROP_EXITNAME, "Exit");
	menu_setprop(menu, MPROP_BACKNAME, "Back");
	menu_setprop(menu, MPROP_NEXTNAME, "Next");

	if (!players) {
		menu_destroy(menu);

		cod_print_chat(id, "There is no player on the server you could trade items with!");
	} else menu_display(id, menu);

	return PLUGIN_HANDLED;
}

public exchange_item_handle(id, menu, item)
{
	if (!is_user_connected(id) || !cod_check_account(id) || mapEnd) return PLUGIN_HANDLED;

	if (item == MENU_EXIT) {
		menu_destroy(menu);

		client_cmd(id, "spk %s", codSounds[SOUND_EXIT]);

		return PLUGIN_HANDLED;
	}

	client_cmd(id, "spk %s", codSounds[SOUND_SELECT]);

	new playerId[3], itemAccess, itemCallback;

	menu_item_getinfo(menu, item, itemAccess, playerId, charsmax(playerId), _, _, itemCallback);

	new player = str_to_num(playerId);

	menu_destroy(menu);

	if (!is_user_connected(player)) {
		cod_print_chat(id, "The selected player is no longer on the server.");

		return PLUGIN_HANDLED;
	}

	if (get_bit(player, cooldown)) {
		cod_print_chat(id, "The selected player must wait^x03 one round^x01 to trade an item.");

		return PLUGIN_HANDLED;
	}

	if (get_bit(id, cooldown)) {
		cod_print_chat(id, "You must wait^x03 one round^x01 to trade this item.");

		return PLUGIN_HANDLED;
	}

	if (!cod_get_user_item(player)) {
		cod_print_chat(id, "The selected player doesn't have any item.");

		return PLUGIN_HANDLED;
	}

	if (!cod_get_user_item(id)) {
		cod_print_chat(id, "You don't have any item.");

		return PLUGIN_HANDLED;
	}

	if (!cod_check_item(id, cod_get_user_item(player))) {
		cod_print_chat(id, "You don't have access to the item you want to trade for.");

		return PLUGIN_HANDLED;
	}

	if (!cod_check_item(player, cod_get_user_item(id))) {
		cod_print_chat(id, "The player you want to trade with doesn't have access to your item.");

		return PLUGIN_HANDLED;
	}

	new menuData[128], playerName[MAX_NAME], itemName[MAX_NAME];

	cod_get_item_name(cod_get_user_item(id), itemName, charsmax(itemName));
	get_user_name(id, playerName, charsmax(playerName));

	formatex(menuData, charsmax(menuData), "\wTrade items with \y%s \w(\r%s\w):", playerName, itemName);

	new menu = menu_create(menuData, "exchange_item_question");

	num_to_str(id, playerId, charsmax(playerId));

	menu_additem(menu, "Yes", playerId);
	menu_additem(menu, "No", playerId);

	menu_setprop(menu, MPROP_EXITNAME, "Exit");

	menu_display(player, menu);

	return PLUGIN_HANDLED;
}

public exchange_item_question(id, menu, item)
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
		cod_print_chat(id, "The player offering the trade is no longer on the server.");

		return PLUGIN_HANDLED;
	}

	if (get_bit(player, cooldown)) {
		cod_print_chat(id, "The player offering the trade must wait^x03 one round^x01 to trade an item.");

		return PLUGIN_HANDLED;
	}

	if (!cod_get_user_item(player)) {
		cod_print_chat(id, "The player offering the trade no longer has an item.");

		return PLUGIN_HANDLED;
	}

	if (!cod_get_user_item(id)) {
		cod_print_chat(id, "You don't have any item.");

		return PLUGIN_HANDLED;
	}

	if (!cod_check_item(id, cod_get_user_item(player))) {
		cod_print_chat(id, "You don't have access to the item owned by the player offering the trade.");

		return PLUGIN_HANDLED;
	}

	if (!cod_check_item(player, cod_get_user_item(id))) {
		cod_print_chat(id, "The player offering the trade doesn't have access to your item.");

		return PLUGIN_HANDLED;
	}

	switch (item) {
		case 0: {
			new name[MAX_NAME], playerName[MAX_NAME], itemName[MAX_NAME], playerItemName[MAX_NAME],
				itemValue, itemId = cod_get_user_item(id, itemValue), itemDurability = cod_get_item_durability(id),
				playerItemValue, playerItemId = cod_get_user_item(player, playerItemValue), playerItemDurability = cod_get_item_durability(player);

			get_user_name(player, playerName, charsmax(playerName));
			get_user_name(id, name, charsmax(name));

			cod_get_item_name(cod_get_user_item(player), playerItemName, charsmax(playerItemName));
			cod_get_item_name(cod_get_user_item(id), itemName, charsmax(itemName));

			cod_set_user_item(player, itemId, itemValue);
			cod_set_user_item(id, playerItemId, playerItemValue);

			cod_set_item_durability(player, itemDurability);
			cod_set_item_durability(id, playerItemDurability);

			set_bit(player, cooldown);
			set_bit(id, cooldown);

			cod_print_chat(player, "You traded items with^x03 %s^x01. You received^x03 %s^x01.", name, itemName);
			cod_print_chat(id, "You traded items with^x03 %s^x01. You received^x03 %s^x01.", playerName, playerItemName);
		} case 1: cod_print_chat(player, "The selected player declined the item trade.");
	}

	return PLUGIN_HANDLED;
}

public give_item(id)
{
	if (!is_user_connected(id) || !cod_check_account(id) || mapEnd) return PLUGIN_HANDLED;

	client_cmd(id, "spk %s", codSounds[SOUND_SELECT]);

	new playerName[MAX_NAME], playerId[3], players, menu = menu_create("\yGive \rItem", "give_item_handle");

	for (new player = 1; player <= MAX_PLAYERS; player++) {
		if (!is_user_connected(player) || player == id || !cod_get_user_class(player) || cod_get_user_item(player)) continue;

		get_user_name(player, playerName, charsmax(playerName));

		num_to_str(player, playerId, charsmax(playerId));

		menu_additem(menu, playerName, playerId);

		players++;
	}

	menu_setprop(menu, MPROP_EXITNAME, "Exit");
	menu_setprop(menu, MPROP_BACKNAME, "Back");
	menu_setprop(menu, MPROP_NEXTNAME, "Next");

	if (!players) {
		menu_destroy(menu);

		cod_print_chat(id, "There is no player on the server you could give an item to!");
	} else menu_display(id, menu);

	return PLUGIN_HANDLED;
}

public give_item_handle(id, menu, item)
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
		cod_print_chat(id, "The selected player is no longer on the server.");

		return PLUGIN_HANDLED;
	}

	if (get_bit(id, cooldown)) {
		cod_print_chat(id, "You must wait^x03 one round^x01 to give away this item.");

		return PLUGIN_HANDLED;
	}

	if (cod_get_user_item(player))
	{
		cod_print_chat(id, "The selected player already has an item.");

		return PLUGIN_HANDLED;
	}

	if (!cod_get_user_item(id)) {
		cod_print_chat(id, "You don't have any item.");

		return PLUGIN_HANDLED;
	}

	if (!cod_check_item(player, cod_get_user_item(id))) {
		cod_print_chat(id, "The player you want to give the item to doesn't have access to it.");

		return PLUGIN_HANDLED;
	}

	new name[MAX_NAME], playerName[MAX_NAME], itemName[MAX_NAME],
		itemValue, itemId = cod_get_user_item(id, itemValue), itemDurability = cod_get_item_durability(id);

	get_user_name(id, name, charsmax(name));
	get_user_name(player, playerName, charsmax(playerName));

	cod_get_item_name(cod_get_user_item(id), itemName, charsmax(itemName));

	set_bit(player, cooldown);
	rem_bit(id, cooldown);

	cod_set_user_item(player, itemId, itemValue);
	cod_set_item_durability(player, itemDurability);
	cod_set_user_item(id);

	cod_print_chat(id, "You gave the item^x03 %s^x01 to player^x03 %s^x01.", itemName, name);
	cod_print_chat(player, "You received the item^x03 %s^x01 from player^x03 %s^x01.", itemName, playerName);

	return PLUGIN_HANDLED;
}