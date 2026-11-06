#include <amxmodx>
#include <cod>

#define PLUGIN "CoD Casino"
#define VERSION "1.1.1"
#define AUTHOR "O'Zone"

new const commandCasino[][] = { "kasyno", "say /kasyno", "say_team /kasyno", "say /casino", "say_team /casino" };
new const commandDice[][] = { "kostka", "say /kostka", "say_team /kostka", "say /dice", "say_team /dice" };
new const commandRoulette[][] = { "ruletka", "say /ruletka", "say_team /ruletka", "say /roulette", "say_team /roulette" };
new const commandCoinFlip[][] = { "moneta", "say /moneta", "say_team /moneta", "say /coin", "say_team /coin" };

enum _:gameInfo { GAME_BID, GAME_TYPE, GAME_CHOICE };
enum _:gameTypeInfo { GAME, DICE, ROULETTE, COINFLIP }
enum _:diceInfo { DICE_NORMAL, DICE_LOWHIGH, DICE_LOW, DICE_HIGH };
enum _:rouletteInfo { ROULETTE_BLACK, ROULETTE_RED, ROULETTE_GREEN };
enum _:coinflipInfo { COINFLIP_TAILS, COINFLIP_HEADS };

new playerData[MAX_PLAYERS + 1][gameTypeInfo][gameInfo], bool:mapEnd;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	for (new i; i < sizeof commandCasino; i++) register_clcmd(commandCasino[i], "casino_menu");
	for (new i; i < sizeof commandDice; i++) register_clcmd(commandDice[i], "dice_menu");
	for (new i; i < sizeof commandRoulette; i++) register_clcmd(commandRoulette[i], "roulette_menu");
	for (new i; i < sizeof commandCoinFlip; i++) register_clcmd(commandCoinFlip[i], "coinflip_menu");

	register_clcmd("CHANGE_BET", "change_bid");
}

public client_putinserver(id)
{
	for (new i; i <= COINFLIP; i++) {
		for (new j; j <= GAME_CHOICE; j++) playerData[id][i][j] = (i >= DICE && j == GAME_BID) ? 1 : 0;
	}

	playerData[id][DICE][GAME_CHOICE] = 1;
}

public cod_end_map()
	mapEnd = true;

public casino_menu(id, sound)
{
	if (!is_user_connected(id) || !cod_check_account(id) || mapEnd) return PLUGIN_HANDLED;

	if (!sound) client_cmd(id, "spk %s", codSounds[SOUND_SELECT]);

	new menu = menu_create("\yCasino \rGames\w:", "casino_menu_handle");

	menu_additem(menu, "\wDice \y(/dice)");
	menu_additem(menu, "\wRoulette \y(/roulette)");
	menu_additem(menu, "\wCoin Flip \y(/coin)");

	menu_setprop(menu, MPROP_EXITNAME, "Exit");
	menu_setprop(menu, MPROP_BACKNAME, "Back");
	menu_setprop(menu, MPROP_NEXTNAME, "Next");

	menu_display(id, menu);

	return PLUGIN_HANDLED;
}

public casino_menu_handle(id, menu, item)
{
	if (!is_user_connected(id) || !cod_check_account(id) || mapEnd) return PLUGIN_HANDLED;

	if (item == MENU_EXIT) {
		client_cmd(id, "spk %s", codSounds[SOUND_EXIT]);

		menu_destroy(menu);

		return PLUGIN_HANDLED;
	}

	client_cmd(id, "spk %s", codSounds[SOUND_SELECT]);

	switch (item + 1) {
		case DICE: dice_menu(id, 0);
		case ROULETTE: roulette_menu(id, 0);
		case COINFLIP: coinflip_menu(id, 0);
	}

	menu_destroy(menu);

	return PLUGIN_CONTINUE;
}

public dice_menu(id, number)
{
	if (!is_user_connected(id) || !cod_check_account(id) || mapEnd) return PLUGIN_HANDLED;

	playerData[id][GAME][0] = DICE;

	new menuData[128], menu;

	if (number > 0) {
		new bool:win, amount = playerData[id][DICE][GAME_BID];

		if (playerData[id][DICE][GAME_TYPE] == DICE_NORMAL && playerData[id][DICE][GAME_CHOICE] == number) {
			amount *= 5;

			win = true;
		} else if (playerData[id][DICE][GAME_TYPE] == DICE_LOWHIGH && ((playerData[id][DICE][GAME_CHOICE] == DICE_LOW && number <= 3) || (playerData[id][DICE][GAME_CHOICE] == DICE_HIGH && number > 3))) {
			amount = floatround(amount * 1.8);

			win = true;
		}

		if (win) {
			cod_add_user_honor(id, amount);

			client_cmd(id, "spk %s", codSounds[SOUND_APPLAUSE])
		} else client_cmd(id, "spk %s", codSounds[SOUND_LAUGH]);

		formatex(menuData, charsmax(menuData), "\yDice \rGame\w:^n\wRolled \y%i \w- \r%s %i Honor!\w", number, win ? "You won" : "You lost", amount);

		menu = menu_create(menuData, "dice_menu_handle");
	} else menu = menu_create("\yDice \rGame\w:", "dice_menu_handle");

	menu_additem(menu, "\wPlay^n");

	formatex(menuData, charsmax(menuData), "\wGame \yType \r[%s]", playerData[id][DICE][GAME_TYPE] == DICE_NORMAL ? "NUMBER" : "LOW/HIGH");
	menu_additem(menu, menuData);

	new diceNumber[2];

	num_to_str(playerData[id][DICE][GAME_CHOICE], diceNumber, charsmax(diceNumber));

	formatex(menuData, charsmax(menuData), "\wYour \yPick \r[%s]", playerData[id][DICE][GAME_TYPE] == DICE_NORMAL ? diceNumber : (playerData[id][DICE][GAME_CHOICE] == DICE_LOW ? "LOW" : "HIGH"));
	menu_additem(menu, menuData);

	formatex(menuData, charsmax(menuData), "\wYour \yBet \r[%i]", playerData[id][DICE][GAME_BID]);
	menu_additem(menu, menuData);

	menu_setprop(menu, MPROP_EXITNAME, "Exit");
	menu_setprop(menu, MPROP_BACKNAME, "Back");
	menu_setprop(menu, MPROP_NEXTNAME, "Next");

	menu_display(id, menu);

	return PLUGIN_HANDLED;
}

public dice_menu_handle(id, menu, item)
{
	if (!is_user_connected(id) || !cod_check_account(id) || mapEnd) return PLUGIN_HANDLED;

	if (item == MENU_EXIT) {
		client_cmd(id, "spk %s", codSounds[SOUND_EXIT]);

		menu_destroy(menu);

		return PLUGIN_HANDLED;
	}

	if (item) client_cmd(id, "spk %s", codSounds[SOUND_SELECT]);

	menu_destroy(menu);

	switch (item) {
		case 0: {
			if (cod_get_user_honor(id) < playerData[id][DICE][GAME_BID]) {
				cod_print_chat(id, "You don't have enough^x03 honor^x01 to play with this bet!");

				return PLUGIN_HANDLED;
			}

			cod_add_user_honor(id, -playerData[id][DICE][GAME_BID]);

			dice_menu(id, random_num(1, 6));
		} case 1: {
			playerData[id][DICE][GAME_TYPE] = playerData[id][DICE][GAME_TYPE] == DICE_NORMAL ? DICE_LOWHIGH : DICE_NORMAL;

			if (playerData[id][DICE][GAME_TYPE] == DICE_NORMAL) playerData[id][DICE][GAME_CHOICE] = 1;
			else playerData[id][DICE][GAME_CHOICE] = DICE_LOW;

			dice_menu(id, 0);
		} case 2: {
			if (playerData[id][DICE][GAME_TYPE] == DICE_NORMAL && ++playerData[id][DICE][GAME_CHOICE] > 6) playerData[id][DICE][GAME_CHOICE] = 1;
			else if (playerData[id][DICE][GAME_TYPE] == DICE_LOWHIGH) playerData[id][DICE][GAME_CHOICE] = playerData[id][DICE][GAME_CHOICE] == DICE_LOW ? DICE_HIGH : DICE_LOW;

			dice_menu(id, 0);
		} case 3: {
			cod_print_chat(id, "Enter a new^x04 bet^x01.");

			cod_show_hud(id, TYPE_HUD, 255, 128, 0, 0.24, 0.07, 0, 0.0, 3.5, 0.0, 0.0, "Enter a new bet.");

			client_cmd(id, "messagemode CHANGE_BET");
		}
	}

	return PLUGIN_HANDLED;
}

public roulette_menu(id, number)
{
	if (!is_user_connected(id) || !cod_check_account(id) || mapEnd) return PLUGIN_HANDLED;

	playerData[id][GAME][0] = ROULETTE;

	new menuData[128], menu;

	if (--number >= 0) {
		new bool:win, amount = playerData[id][ROULETTE][GAME_BID];

		if (playerData[id][ROULETTE][GAME_CHOICE] == ROULETTE_GREEN && number == 0) {
			amount *= 14;

			win = true;
		} else if ((playerData[id][ROULETTE][GAME_CHOICE] == ROULETTE_BLACK && number <= 7 && number > 0) || (playerData[id][ROULETTE][GAME_CHOICE] == ROULETTE_RED && number > 7)) {
			amount *= 2;

			win = true;
		}

		if (win) {
			cod_add_user_honor(id, amount);

			client_cmd(id, "spk %s", codSounds[SOUND_APPLAUSE])
		} else client_cmd(id, "spk %s", codSounds[SOUND_LAUGH]);

		formatex(menuData, charsmax(menuData), "\yRoulette \rGame\w:^n\wRolled \y%i (%s) \w- \r%s %i Honor!\w", number, number == 0 ? "Green" : (number > 7 ? "Red" : "Black"), win ? "You won" : "You lost", amount);

		menu = menu_create(menuData, "roulette_menu_handle");
	} else menu = menu_create("\yRoulette \rGame\w:", "roulette_menu_handle");

	menu_additem(menu, "\wPlay^n");

	formatex(menuData, charsmax(menuData), "\wYour \yPick \r[%s]", playerData[id][ROULETTE][GAME_CHOICE] == ROULETTE_GREEN ? "GREEN" : (playerData[id][ROULETTE][GAME_CHOICE] == ROULETTE_BLACK ? "BLACK" : "RED"));
	menu_additem(menu, menuData);

	formatex(menuData, charsmax(menuData), "\wYour \yBet \r[%i]", playerData[id][ROULETTE][GAME_BID]);
	menu_additem(menu, menuData);

	menu_setprop(menu, MPROP_EXITNAME, "Exit");
	menu_setprop(menu, MPROP_BACKNAME, "Back");
	menu_setprop(menu, MPROP_NEXTNAME, "Next");

	menu_display(id, menu);

	return PLUGIN_HANDLED;
}

public roulette_menu_handle(id, menu, item)
{
	if (!is_user_connected(id) || !cod_check_account(id) || mapEnd) return PLUGIN_HANDLED;

	if (item == MENU_EXIT) {
		client_cmd(id, "spk %s", codSounds[SOUND_EXIT]);

		menu_destroy(menu);

		return PLUGIN_HANDLED;
	}

	if (item) client_cmd(id, "spk %s", codSounds[SOUND_SELECT]);

	menu_destroy(menu);

	switch (item) {
		case 0:  {
			if (cod_get_user_honor(id) < playerData[id][ROULETTE][GAME_BID]) {
				cod_print_chat(id, "You don't have enough^x03 honor^x01 to play with this bet!");

				return PLUGIN_HANDLED;
			}

			cod_add_user_honor(id, -playerData[id][ROULETTE][GAME_BID]);

			roulette_menu(id, random_num(0, 14) + 1);
		} case 1: {
			if (++playerData[id][ROULETTE][GAME_CHOICE] > ROULETTE_GREEN) playerData[id][ROULETTE][GAME_CHOICE] = ROULETTE_BLACK;

			roulette_menu(id, 0);
		} case 2: {
			cod_print_chat(id, "Enter a new^x04 bet^x01.");

			cod_show_hud(id, TYPE_HUD, 255, 128, 0, 0.24, 0.07, 0, 0.0, 3.5, 0.0, 0.0, "Enter a new bet.");

			client_cmd(id, "messagemode CHANGE_BET");
		}
	}

	return PLUGIN_HANDLED;
}

public coinflip_menu(id, coinFlip)
{
	if (!is_user_connected(id) || !cod_check_account(id) || mapEnd) return PLUGIN_HANDLED;

	playerData[id][GAME][0] = COINFLIP;

	new menuData[128], menu;

	if (--coinFlip >= 0) {
		new bool:win, amount = playerData[id][COINFLIP][GAME_BID];

		if (playerData[id][COINFLIP][GAME_CHOICE] == coinFlip) {
			amount = floatround(amount * 1.8);

			win = true;
		}

		if (win) {
			cod_add_user_honor(id, amount);

			client_cmd(id, "spk %s", codSounds[SOUND_APPLAUSE])
		} else client_cmd(id, "spk %s", codSounds[SOUND_LAUGH]);

		formatex(menuData, charsmax(menuData), "\yCoin \rFlip\w:^n\wResult \y%s \w- \r%s %i Honor!\w", coinFlip ? "Heads" : "Tails", win ? "You won" : "You lost", amount);

		menu = menu_create(menuData, "coinflip_menu_handle");
	} else menu = menu_create("\yCoin \rFlip\w:", "coinflip_menu_handle");

	menu_additem(menu, "\wPlay^n");

	formatex(menuData, charsmax(menuData), "\wYour \yPick \r[%s]", playerData[id][COINFLIP][GAME_CHOICE] ? "Heads" : "Tails");
	menu_additem(menu, menuData);

	formatex(menuData, charsmax(menuData), "\wYour \yBet \r[%i]", playerData[id][COINFLIP][GAME_BID]);
	menu_additem(menu, menuData);

	menu_setprop(menu, MPROP_EXITNAME, "Exit");
	menu_setprop(menu, MPROP_BACKNAME, "Back");
	menu_setprop(menu, MPROP_NEXTNAME, "Next");

	menu_display(id, menu);

	return PLUGIN_HANDLED;
}

public coinflip_menu_handle(id, menu, item)
{
	if (!is_user_connected(id)) return PLUGIN_HANDLED;

	if (item == MENU_EXIT) {
		client_cmd(id, "spk %s", codSounds[SOUND_EXIT]);

		menu_destroy(menu);

		return PLUGIN_HANDLED;
	}

	if (item) client_cmd(id, "spk %s", codSounds[SOUND_SELECT]);

	menu_destroy(menu);

	switch (item) {
		case 0: {
			if (cod_get_user_honor(id) < playerData[id][COINFLIP][GAME_BID]) {
				cod_print_chat(id, "You don't have enough^x03 honor^x01 to play with this bet!");

				return PLUGIN_HANDLED;
			}

			cod_add_user_honor(id, -playerData[id][COINFLIP][GAME_BID]);

			coinflip_menu(id, random_num(0, 1) + 1);
		}
		case 1: {
			playerData[id][COINFLIP][GAME_CHOICE] = !playerData[id][COINFLIP][GAME_CHOICE];

			coinflip_menu(id, 0);
		} case 2: {
			cod_print_chat(id, "Enter a new^x04 bet^x01.");

			cod_show_hud(id, TYPE_HUD, 255, 128, 0, 0.24, 0.07, 0, 0.0, 3.5, 0.0, 0.0, "Enter a new bet.");

			client_cmd(id, "messagemode CHANGE_BET");
		}
	}

	return PLUGIN_HANDLED;
}

public change_bid(id)
{
	if (!is_user_connected(id) || !cod_check_account(id) || mapEnd) return PLUGIN_HANDLED;

	client_cmd(id, "spk %s", codSounds[SOUND_SELECT]);

	new bidData[16], bid;

	read_args(bidData, charsmax(bidData));
	remove_quotes(bidData);

	bid = str_to_num(bidData);

	if (bid <= 0) {
		cod_print_chat(id, "You can't set a bet lower than^x03 1 honor^x01!");

		return PLUGIN_HANDLED;
	}

	if (cod_get_user_honor(id) < bid) {
		cod_print_chat(id, "You can't set a bet higher than your amount of^x03 honor^x01!");

		return PLUGIN_HANDLED;
	}

	playerData[id][playerData[id][GAME][0]][GAME_BID] = bid;

	switch (playerData[id][GAME][0]) {
		case DICE: dice_menu(id, 0);
		case ROULETTE: roulette_menu(id, 0);
		case COINFLIP: coinflip_menu(id, 0);
	}

	return PLUGIN_HANDLED;
}