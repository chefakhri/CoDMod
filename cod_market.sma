#include <amxmodx>
#include <cstrike>
#include <cod>

#define PLUGIN "CoD Market"
#define VERSION "1.3.0"
#define AUTHOR "O'Zone"

new const commandMarket[][] = { "rynek", "say /market", "say_team /market", "say /rynek", "say_team /rynek" };
new const commandSell[][] = { "sprzedaj", "say /sell", "say_team /sell", "say /wystaw", "say_team /wystaw", "say /sprzedaj", "say_team /sprzedaj" };
new const commandBuy[][] = { "kup", "say /buy", "say_team /buy", "say /kup", "say_team /kup" };
new const commandWithdraw[][] = { "wycofaj", "say /withdraw", "say_team /withdraw", "say /wycofaj", "say_team /wycofaj" };

enum _:itemInfo { MARKET_ID, MARKET_ITEM, MARKET_VALUE, MARKET_DURABILITY, MARKET_OWNER, MARKET_PRICE, MARKET_NAME[MAX_NAME] };

new playerName[MAX_PLAYERS + 1][MAX_NAME], Array:marketItems, bool:mapEnd, items, cvarMaxItems;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	bind_pcvar_num(create_cvar("cod_market_max_items", "5"), cvarMaxItems);

	for (new i; i < sizeof commandMarket; i++) register_clcmd(commandMarket[i], "market_menu");
	for (new i; i < sizeof commandSell; i++) register_clcmd(commandSell[i], "sell_item");
	for (new i; i < sizeof commandBuy; i++) register_clcmd(commandBuy[i], "buy_item");
	for (new i; i < sizeof commandWithdraw; i++) register_clcmd(commandWithdraw[i], "withdraw_item");

	register_concmd("ITEM_PRICE", "set_item_price");

	marketItems = ArrayCreate(itemInfo);
}

public client_disconnected(id)
	remove_seller(id);

public client_putinserver(id)
	get_user_name(id, playerName[id], charsmax(playerName[]));

public cod_end_map()
	mapEnd = true;

public market_menu(id)
{
	if (!cod_check_account(id) || mapEnd) return PLUGIN_HANDLED;

	client_cmd(id, "spk %s", codSounds[SOUND_SELECT]);

	new menu = menu_create("\yMarket \rMenu", "market_menu_handle"), callback = menu_makecallback("market_menu_callback");

	menu_additem(menu, "Sell \yItem \r(/sell)", _, _, callback);
	menu_additem(menu, "Buy \yItem \r(/buy)", _, _, callback);
	menu_additem(menu, "Withdraw \yItem \r(/withdraw)", _, _, callback);

	menu_setprop(menu, MPROP_EXITNAME, "Exit");

	menu_display(id, menu);

	return PLUGIN_HANDLED;
}

public market_menu_handle(id, menu, item)
{
	if (!is_user_connected(id) || mapEnd) return PLUGIN_HANDLED;

	client_cmd(id, "spk %s", codSounds[SOUND_SELECT]);

	if (item == MENU_EXIT) {
		client_cmd(id, "spk %s", codSounds[SOUND_EXIT]);

		menu_destroy(menu);

		return PLUGIN_HANDLED;
	}

	switch (item) {
		case 0: sell_item(id, 1);
		case 1: buy_item(id, 1);
		case 2: withdraw_item(id, 1);
	}

	return PLUGIN_HANDLED;
}

public market_menu_callback(id, menu, item)
{
	switch (item) {
		case 0: if (!cod_get_user_class(id) || !cod_get_user_item(id) || (cvarMaxItems && get_items_amount(id) >= cvarMaxItems)) return ITEM_DISABLED;
		case 1: if (!ArraySize(marketItems)) return ITEM_DISABLED;
		case 2: if (!get_items_amount(id)) return ITEM_DISABLED;
	}

	return ITEM_ENABLED;
}

public sell_item(id, sound)
{
	if (!is_user_connected(id) || !cod_check_account(id) || mapEnd) return PLUGIN_HANDLED;

	if (!sound) client_cmd(id, "spk %s", codSounds[SOUND_SELECT]);

	if (!cod_get_user_item(id)) {
		cod_print_chat(id, "You don't have any item!");

		return PLUGIN_HANDLED;
	}

	if (cvarMaxItems && get_items_amount(id) >= cvarMaxItems) {
		cod_print_chat(id, "You have already listed the maximum of^x03 %i^x01 items!", cvarMaxItems);

		return PLUGIN_HANDLED;
	}

	client_cmd(id, "messagemode ITEM_PRICE");

	cod_print_chat(id, "Enter the^x03 price (honor)^x01 you want to sell the item for.");

	client_print(id, print_center, "Enter the price (honor) you want to sell the item for.");

	return PLUGIN_HANDLED;
}

public set_item_price(id)
{
	if (!cod_check_account(id) || mapEnd) return PLUGIN_HANDLED;

	client_cmd(id, "spk %s", codSounds[SOUND_EXIT]);

	if (!cod_get_user_item(id)) {
		cod_print_chat(id, "You don't have any item!");

		return PLUGIN_HANDLED;
	}

	if (cvarMaxItems && get_items_amount(id) >= cvarMaxItems) {
		cod_print_chat(id, "You have already listed the maximum of^x03 %i^x01 items!", cvarMaxItems);

		return PLUGIN_HANDLED;
	}

	new priceData[16], price;

	read_args(priceData, charsmax(priceData));
	remove_quotes(priceData);

	price = str_to_num(priceData);

	if (price  < 1 || price > 99999) {
		cod_print_chat(id, "The price must be in the range^x03 1 - 99999^x01 Honor!");

		return PLUGIN_HANDLED;
	}

	new marketItem[itemInfo];

	marketItem[MARKET_ID] = items++;
	marketItem[MARKET_ITEM] = cod_get_user_item(id, marketItem[MARKET_VALUE]);
	marketItem[MARKET_DURABILITY] = cod_get_item_durability(id);
	marketItem[MARKET_OWNER] = id;
	marketItem[MARKET_PRICE] = price;

	cod_get_item_name(cod_get_user_item(id), marketItem[MARKET_NAME], charsmax(marketItem[MARKET_NAME]));

	ArrayPushArray(marketItems, marketItem);

	cod_set_user_item(id);

	cod_print_chat(0, "^x03%s^x01 listed^x03 %s^x01 on the market for^x03 %i^x01 Honor.", playerName[id], marketItem[MARKET_NAME], marketItem[MARKET_PRICE]);

	return PLUGIN_HANDLED;
}

public buy_item(id, sound)
{
	if (!is_user_connected(id) || !cod_check_account(id) || mapEnd) return PLUGIN_HANDLED;

	if (!sound) client_cmd(id, "spk %s", codSounds[SOUND_SELECT]);

	new marketItem[itemInfo], itemData[128], itemId[5], itemsCounts = 0, menu = menu_create("\yBuy \rItem", "buy_item_handle");

	for (new i = 0; i < ArraySize(marketItems); i++) {
		ArrayGetArray(marketItems, i, marketItem);

		if (marketItem[MARKET_OWNER] == id) continue;

		num_to_str(marketItem[MARKET_ID], itemId, charsmax(itemId));

		formatex(itemData, charsmax(itemData), "\w%s \y(%i/%i Durability) \r(%i Honor)", marketItem[MARKET_NAME], marketItem[MARKET_DURABILITY], cod_max_item_durability(), marketItem[MARKET_PRICE]);

		menu_additem(menu, itemData, itemId);

		itemsCounts++;
	}

	menu_setprop(menu, MPROP_EXITNAME, "Exit");
	menu_setprop(menu, MPROP_BACKNAME, "Back");
	menu_setprop(menu, MPROP_NEXTNAME, "Next");

	if (!itemsCounts)
	{
		menu_destroy(menu);

		cod_print_chat(id, "There are no items on the market that you could buy!");
	} else menu_display(id, menu);

	return PLUGIN_HANDLED;
}

public buy_item_handle(id, menu, item)
{
	if (!is_user_connected(id) || mapEnd) return PLUGIN_HANDLED;

	if (item == MENU_EXIT) {
		client_cmd(id, "spk %s", codSounds[SOUND_EXIT]);

		menu_destroy(menu);

		return PLUGIN_HANDLED;
	}

	client_cmd(id, "spk %s", codSounds[SOUND_SELECT]);

	new itemId[5], itemAccess, itemCallback;

	menu_item_getinfo(menu, item, itemAccess, itemId, charsmax(itemId), _, _, itemCallback);

	new item = check_item_id(str_to_num(itemId));

	if (item < 0) {
		buy_item(id, 1);

		cod_print_chat(id, "The item has already been bought or withdrawn from the market!");

		return PLUGIN_HANDLED;
	}

	new marketItem[itemInfo];

	ArrayGetArray(marketItems, item, marketItem);

	if (!cod_check_item(id, marketItem[MARKET_ITEM])) {
		cod_print_chat(id, "You don't have access to the item you want to buy.");

		return PLUGIN_HANDLED;
	}

	new menuData[512], itemDescription[MAX_DESC], length = 0, maxLength = charsmax(menuData);

	cod_get_item_desc(marketItem[MARKET_ITEM], itemDescription, charsmax(itemDescription));

	length += formatex(menuData[length], maxLength - length, "Confirm purchase from: \y%s^n", playerName[marketItem[MARKET_OWNER]]);
	length += formatex(menuData[length], maxLength - length, "\wItem: \y%s^n", marketItem[MARKET_NAME]);
	length += formatex(menuData[length], maxLength - length, "\wOpis: \y%s^n", itemDescription);
	length += formatex(menuData[length], maxLength - length, "\wCost: \y%i Honor^n", marketItem[MARKET_PRICE]);
	length += formatex(menuData[length], maxLength - length, "\wWytrzymalosc: \y%d/%i^n", marketItem[MARKET_DURABILITY], cod_max_item_durability());
	length += formatex(menuData[length], maxLength - length, "\wDo you want to \rbuy\w this item?^n^n");

	new menu = menu_create(menuData, "buy_question_handle");

	menu_additem(menu, "Yes", itemId);
	menu_additem(menu, "No");

	menu_setprop(menu, MPROP_EXIT, MEXIT_NEVER);

	menu_display(id, menu);

	return PLUGIN_CONTINUE;
}

public buy_question_handle(id, menu, item)
{
	if (!is_user_connected(id) || mapEnd) return PLUGIN_HANDLED;

	if (item == MENU_EXIT || item) {
		client_cmd(id, "spk %s", codSounds[SOUND_EXIT]);

		menu_destroy(menu);

		return PLUGIN_HANDLED;
	}

	client_cmd(id, "spk %s", codSounds[SOUND_SELECT]);

	new itemId[5], itemAccess, itemCallback;

	menu_item_getinfo(menu, item, itemAccess, itemId, charsmax(itemId), _, _, itemCallback);

	new item = check_item_id(str_to_num(itemId));

	if (item < 0) {
		buy_item(id, 1);

		cod_print_chat(id, "The item has already been bought or withdrawn from the market!");

		return PLUGIN_HANDLED;
	}

	new marketItem[itemInfo];

	ArrayGetArray(marketItems, item, marketItem);

	if (cod_get_user_honor(id) < marketItem[MARKET_PRICE]) {
		cod_print_chat(id, "You don't have enough Honor!");

		return PLUGIN_HANDLED;
	} else {
		cod_set_user_honor(marketItem[MARKET_OWNER], cod_get_user_honor(marketItem[MARKET_OWNER]) + marketItem[MARKET_PRICE]);
		cod_set_user_honor(id, cod_get_user_honor(id) - marketItem[MARKET_PRICE]);
	}

	ArrayDeleteItem(marketItems, item);

	cod_set_user_item(id, marketItem[MARKET_ITEM], marketItem[MARKET_VALUE]);
	cod_set_item_durability(id, marketItem[MARKET_DURABILITY]);

	cod_print_chat(id, "The item^x03 %s^x01 has been successfully purchased.", marketItem[MARKET_NAME]);
	cod_print_chat(marketItem[MARKET_OWNER], "Your item^x03 %s^x01 was bought by^x03 %s^x01.", marketItem[MARKET_NAME], playerName[id]);
	cod_print_chat(marketItem[MARKET_OWNER], "You receive^x03 %i^x01 Honor for the sale.", marketItem[MARKET_PRICE])

	return PLUGIN_CONTINUE;
}

public withdraw_item(id, sound)
{
	if (!is_user_connected(id) || !cod_check_account(id) || mapEnd) return PLUGIN_HANDLED;

	if (!sound) client_cmd(id, "spk %s", codSounds[SOUND_SELECT]);

	new marketItem[itemInfo], itemData[128], itemId[5], itemsCounts = 0, menu = menu_create("\yWithdraw \rItem", "withdraw_item_handle");

	for (new i = 0; i < ArraySize(marketItems); i++) {
		ArrayGetArray(marketItems, i, marketItem);

		if (marketItem[MARKET_OWNER] != id) continue;

		num_to_str(marketItem[MARKET_ID], itemId, charsmax(itemId));

		formatex(itemData, charsmax(itemData), "\w%s \y(%i/%i Durability) \r(%i Honor)", marketItem[MARKET_NAME], marketItem[MARKET_DURABILITY], cod_max_item_durability(), marketItem[MARKET_PRICE]);

		menu_additem(menu, itemData, itemId);

		itemsCounts++;
	}

	menu_setprop(menu, MPROP_EXITNAME, "Exit");
	menu_setprop(menu, MPROP_BACKNAME, "Back");
	menu_setprop(menu, MPROP_NEXTNAME, "Next");

	if (!itemsCounts) {
		menu_destroy(menu);

		cod_print_chat(id, "You have no items on the market!");
	} else menu_display(id, menu);

	return PLUGIN_CONTINUE;
}

public withdraw_item_handle(id, menu, item)
{
	if (!is_user_connected(id) || mapEnd) return PLUGIN_HANDLED;

	if (item == MENU_EXIT || item) {
		client_cmd(id, "spk %s", codSounds[SOUND_EXIT]);

		menu_destroy(menu);

		return PLUGIN_HANDLED;
	}

	client_cmd(id, "spk %s", codSounds[SOUND_SELECT]);

	new itemId[5], itemAccess, itemCallback;

	menu_item_getinfo(menu, item, itemAccess, itemId, charsmax(itemId), _, _, itemCallback);

	new item = check_item_id(str_to_num(itemId));

	if (item < 0) {
		buy_item(id, 1);

		cod_print_chat(id, "The item has already been bought!");

		return PLUGIN_HANDLED;
	}

	new marketItem[itemInfo], menuData[512], itemDescription[MAX_DESC], length = 0, maxLength = sizeof(menuData) - 1;

	ArrayGetArray(marketItems, item, marketItem);

	cod_get_item_desc(marketItem[MARKET_ITEM], itemDescription, charsmax(itemDescription));

	length += formatex(menuData[length], maxLength - length, "Confirm item withdrawal^n");
	length += formatex(menuData[length], maxLength - length, "\wItem: \y%s^n", marketItem[MARKET_NAME]);
	length += formatex(menuData[length], maxLength - length, "\wOpis: \y%s^n", itemDescription);
	length += formatex(menuData[length], maxLength - length, "\wCost: \y%i Honor^n", marketItem[MARKET_PRICE]);
	length += formatex(menuData[length], maxLength - length, "\wWytrzymalosc: \y%d/%i^n^n", marketItem[MARKET_DURABILITY], cod_max_item_durability());
	length += formatex(menuData[length], maxLength - length, "\wDo you want to \rwithdraw\w this item?");

	new menu = menu_create(menuData, "withdraw_question_handle");

	menu_additem(menu, "Yes", itemId);
	menu_additem(menu, "No");

	menu_setprop(menu, MPROP_EXIT, MEXIT_NEVER);

	menu_display(id, menu);

	return PLUGIN_CONTINUE;
}

public withdraw_question_handle(id, menu, item)
{
	if (!is_user_connected(id) || mapEnd) return PLUGIN_HANDLED;

	if (item == MENU_EXIT || item) {
		client_cmd(id, "spk %s", codSounds[SOUND_EXIT]);

		menu_destroy(menu);

		return PLUGIN_HANDLED;
	}

	client_cmd(id, "spk %s", codSounds[SOUND_SELECT]);

	new itemId[5], itemAccess, itemCallback;

	menu_item_getinfo(menu, item, itemAccess, itemId, charsmax(itemId), _, _, itemCallback);

	new item = check_item_id(str_to_num(itemId));

	if (item < 0) {
		withdraw_item(id, 1);

		cod_print_chat(id, "The item has already been bought!");

		return PLUGIN_HANDLED;
	}

	new marketItem[itemInfo];

	ArrayGetArray(marketItems, item, marketItem);

	cod_set_user_item(id, marketItem[MARKET_ITEM], marketItem[MARKET_VALUE]);
	cod_set_item_durability(id, marketItem[MARKET_DURABILITY]);

	ArrayDeleteItem(marketItems, item);

	cod_print_chat(id, "The item^x03 %s^x01 has been successfully withdrawn from the market.", marketItem[MARKET_NAME]);

	return PLUGIN_HANDLED;
}

stock get_items_amount(id)
{
	if (!is_user_connected(id)) return 0;

	new amount = 0, marketItem[itemInfo];

	for (new i = 0; i < ArraySize(marketItems); i++) {
		ArrayGetArray(marketItems, i, marketItem);

		if (marketItem[MARKET_OWNER] == id) amount++;
	}

	return amount;
}

stock check_item_id(item)
{
	new marketItem[itemInfo];

	for (new i = 0; i < ArraySize(marketItems); i++) {
		ArrayGetArray(marketItems, i, marketItem);

		if (marketItem[MARKET_ID] == item) return i;
	}

	return NONE;
}

stock remove_seller(id)
{
	new marketItem[itemInfo];

	for (new i = 0; i < ArraySize(marketItems); i++) {
		ArrayGetArray(marketItems, i, marketItem);

		if (marketItem[MARKET_OWNER] == id) {
			ArrayDeleteItem(marketItems, i);

			i -= 1;
		}
	}
}