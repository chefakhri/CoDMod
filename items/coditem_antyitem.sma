#include <amxmodx>
#include <cod>

#define PLUGIN "CoD Item Anty Item"
#define VERSION "1.0"
#define AUTHOR "O'Zone"

#define NAME        "Anti Item"
#define DESCRIPTION "When used, you can destroy any player's item along with your own"

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	cod_register_item(NAME, DESCRIPTION);
}

public cod_item_skill_used(id)
{
	new menuData[128], playerName[32], playerItem[64], playerId[3], playerItems, menu = menu_create("Select the \rPlayer\w whose item you want to destroy:", "cod_item_skill_used_handle");

	for (new i = 1; i <= MAX_PLAYERS; i++) {
	    if (!is_user_connected(i) || !cod_get_user_item(i) || get_user_team(i) == get_user_team(id)) continue;

	    cod_get_item_name(cod_get_user_item(id), playerItem, charsmax(playerItem));
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

	get_user_name(player, playerName, charsmax(playerName));
	get_user_name(id, name, charsmax(name));

	cod_print_chat(player, "^x03%s^x01 destroyed your item!", name);
	cod_print_chat(id, "You destroyed the item of^x03 %s^x01.", playerName);

	cod_set_user_item(player);
	cod_set_user_item(id);

	menu_destroy(menu);

	return PLUGIN_HANDLED;
}