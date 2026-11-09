#include <amxmodx>
#include <cod>

#define PLUGIN "CoD Item Anty Item"
#define VERSION "1.0"
#define AUTHOR "O'Zone"

#define NAME        "Anti Item"
#define DESCRIPTION "When used, you can destroy any player's item along with your own"

new itemId;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	itemId = cod_register_item(NAME, DESCRIPTION);
}

public cod_item_skill_used(id)
{
	new menuData[128], playerName[32], playerItem[64], playerId[3], playerItems, menu = menu_create("Select the \rPlayer\w whose item you want to destroy:", "cod_item_skill_used_handle");

	for (new i = 1; i <= MAX_PLAYERS; i++) {
	    if (!is_user_connected(i) || !cod_get_user_items_count(i) || get_user_team(i) == get_user_team(id)) continue;

	    get_items_text(i, playerItem, charsmax(playerItem));
	    get_user_name(i, playerName, charsmax(playerName));
	    num_to_str(i, playerId, charsmax(playerId));

	    formatex(menuData, charsmax(menuData), "\w%s (\y%s)", playerName, playerItem);

	    menu_additem(menu, menuData, playerId);

	    playerItems++;
	}

	menu_setprop(menu, MPROP_EXITNAME, "Exit");
	menu_setprop(menu, MPROP_BACKNAME, "Back");
	menu_setprop(menu, MPROP_NEXTNAME, "Next");

	if (playerItems) {
		menu_display(id, menu);
	} else {
		menu_destroy(menu);

		cod_print_chat(id, "None of the enemies has an item!");
	}
}

public cod_item_skill_used_handle(id, menu, item)
{
	if (item == MENU_EXIT) {
		menu_destroy(menu);

		return PLUGIN_HANDLED;
	}

	new playerId[3], name[32], playerName[32], itemAccess, itemCallback;

	menu_item_getinfo(menu, item, itemAccess, playerId, charsmax(playerId), _, _, itemCallback);

	new player = str_to_num(playerId);

	menu_destroy(menu);

	// The target may have lost their items, or the user this item, while the menu was open
	if (!is_user_connected(player) || !cod_get_user_items_count(player) || !cod_user_has_item(id, itemId)) return PLUGIN_HANDLED;

	// With 2 items, one of them is destroyed at random
	new slot = cod_get_user_items_count(player) == 2 ? random_num(1, 2) : (cod_get_user_slot_item(player, 1) ? 1 : 2),
		itemName[64];

	cod_get_item_name(cod_get_user_slot_item(player, slot), itemName, charsmax(itemName));

	get_user_name(player, playerName, charsmax(playerName));
	get_user_name(id, name, charsmax(name));

	cod_print_chat(player, "^x03%s^x01 destroyed your item^x03 %s^x01!", name, itemName);
	cod_print_chat(id, "You destroyed the item^x03 %s^x01 of^x03 %s^x01.", itemName, playerName);

	cod_set_user_slot_item(player, slot);
	cod_set_user_slot_item(id, cod_user_has_item(id, itemId));

	return PLUGIN_HANDLED;
}

get_items_text(id, dataReturn[], dataLength)
{
	new itemName[64];

	dataReturn[0] = EOS;

	for (new slot = 1; slot <= 2; slot++) {
		if (!cod_get_user_slot_item(id, slot)) continue;

		cod_get_item_name(cod_get_user_slot_item(id, slot), itemName, charsmax(itemName));

		if (dataReturn[0]) format(dataReturn, dataLength, "%s + %s", dataReturn, itemName);
		else copy(dataReturn, dataLength, itemName);
	}
}