#include <amxmodx>
#include <sqlx>
#include <fakemeta>
#include <cod>

#define PLUGIN "CoD Accounts"
#define VERSION "1.3.1"
#define AUTHOR "O'Zone"

#define TASK_PASSWORD   1945
#define TASK_LOAD       2491

#define MAX_PASSWORD    32

enum _:playerInfo { STATUS, FAILS, PASSWORD[MAX_PASSWORD], TEMP_PASSWORD[MAX_PASSWORD], NAME[MAX_NAME], SAFE_NAME[MAX_SAFE_NAME] };
enum _:status { NOT_REGISTERED, NOT_LOGGED, LOGGED, GUEST };
enum _:queries { UPDATE, INSERT, DELETE };

new const accountStatus[status][] = { "Not registered", "Not logged in", "Logged in", "Guest" };

new const commandAccount[][] = { "konto", "say /haslo", "say_team /haslo", "say /password", "say_team /password",
	"say /konto", "say_team /konto", "say /account", "say_team /account" };

new playerData[MAX_PLAYERS + 1][playerInfo], Handle:sql, bool:sqlConnected, dataLoaded, autoLogin,
	cvarAccountsEnabled, cvarLoginMaxTime, cvarPasswordMaxFails, cvarPasswordMinLength, cvarAutoLoginConfig, cvarSetinfo[32];

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	for (new i; i < sizeof commandAccount; i++) register_clcmd(commandAccount[i], "account_menu");

	bind_pcvar_num(create_cvar("cod_accounts_enabled", "1"), cvarAccountsEnabled);
	bind_pcvar_num(create_cvar("cod_accounts_login_max_time", "60"), cvarLoginMaxTime);
	bind_pcvar_num(create_cvar("cod_accounts_password_max_fails", "3"), cvarPasswordMaxFails);
	bind_pcvar_num(create_cvar("cod_accounts_password_min_length", "5"), cvarPasswordMinLength);
	bind_pcvar_num(create_cvar("cod_accounts_autologin_config", "1"), cvarAutoLoginConfig);
	bind_pcvar_string(create_cvar("cod_accounts_autologin_setinfo", "codpass"), cvarSetinfo, charsmax(cvarSetinfo));

	register_clcmd("ENTER_YOUR_PASSWORD", "login_account");
	register_clcmd("ENTER_NEW_ACCOUNT_PASSWORD", "register_step_one");
	register_clcmd("REPEAT_NEW_ACCOUNT_PASSWORD", "register_step_two");
	register_clcmd("ENTER_CURRENT_PASSWORD", "change_step_one");
	register_clcmd("ENTER_NEW_PASSWORD", "change_step_two");
	register_clcmd("REPEAT_NEW_PASSWORD", "change_step_three");
	register_clcmd("CONFIRM_YOUR_CURRENT_PASSWORD", "delete_account");

	register_concmd("joinclass", "check_account");
	register_concmd("jointeam", "check_account");
	register_concmd("chooseteam", "check_account");

	register_message(get_user_msgid("ShowMenu"), "message_show_menu");
	register_message(get_user_msgid("VGUIMenu"), "message_vgui_menu");
}

public plugin_natives()
	register_native("cod_check_account", "_cod_check_account");

public plugin_cfg()
	sql_init();

public plugin_end()
	if (sql != Empty_Handle) SQL_FreeHandle(sql);

public cod_reset_all_data()
{
	for (new i = 1; i <= MAX_PLAYERS; i++) {
		rem_bit(i, dataLoaded);

		playerData[i][STATUS] = NOT_REGISTERED;
	}

	sqlConnected = false;

	new tempData[32];

	formatex(tempData, charsmax(tempData), "DROP TABLE `cod_accounts`;");

	SQL_ThreadQuery(sql, "ignore_handle", tempData);
}

public client_connect(id)
{
	playerData[id][PASSWORD] = "";
	playerData[id][STATUS] = NOT_REGISTERED;
	playerData[id][FAILS] = 0;

	rem_bit(id, dataLoaded);
	rem_bit(id, autoLogin);

	if (is_user_bot(id) || is_user_hltv(id) || !cvarAccountsEnabled) return;

	get_user_name(id, playerData[id][NAME], charsmax(playerData[][NAME]));

	cod_sql_string(playerData[id][NAME], playerData[id][SAFE_NAME], charsmax(playerData[][SAFE_NAME]));

	set_task(0.1, "load_account", id + TASK_LOAD);
}

public client_disconnected(id)
{
	remove_task(id + TASK_PASSWORD);
	remove_task(id + TASK_LOAD);
	remove_task(id);
}

public message_show_menu(msgId, dest, id)
{
	if (!cvarAccountsEnabled) return PLUGIN_CONTINUE;

	new const Team_Select[] = "#Team_Select";
	static menuData[sizeof(Team_Select)];

	get_msg_arg_string(4, menuData, charsmax(menuData));

	if (equal(menuData, Team_Select) && get_bit(id, dataLoaded) && playerData[id][STATUS] < LOGGED && sql != Empty_Handle) {
		set_pdata_int(id, 205, 0, 5);

		set_task(0.1, "account_menu", id);

		return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
}

public message_vgui_menu(msgId, dest, id)
{
	if (get_msg_arg_int(1) == 2 && cvarAccountsEnabled && get_bit(id, dataLoaded) && playerData[id][STATUS] < LOGGED && sql != Empty_Handle) {
		set_task(0.1, "account_menu", id);

		return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
}

public check_account(id)
{
	if (cvarAccountsEnabled && playerData[id][STATUS] < LOGGED) {
		account_menu(id, true);

		return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
}

public kick_player(id)
{
	id -= TASK_PASSWORD;

	if (is_user_connected(id)) server_cmd("kick #%d ^"You did not log in within %is!^"", get_user_userid(id), cvarLoginMaxTime);
}

public account_menu(id, sound)
{
	if (!cvarAccountsEnabled || !is_user_connected(id) || !is_user_valid(id)) return PLUGIN_HANDLED;

	if (!get_bit(id, dataLoaded)) {
		remove_task(id);

		set_task(1.0, "account_menu", id);

		return PLUGIN_HANDLED;
	}

	if (!get_user_team(id) && playerData[id][STATUS] == LOGGED) {
		client_cmd(id, "chooseteam");
		engclient_cmd(id, "chooseteam");

		return PLUGIN_HANDLED;
	} else if (playerData[id][STATUS] < LOGGED) {
		cod_display_fade(id, 0, 0, 0x0001|0x0004, 0, 0, 0, 255);
	}

	if (sound) client_cmd(id, "spk %s", codSounds[SOUND_SELECT]);

	if (playerData[id][STATUS] <= NOT_LOGGED && !task_exists(id + TASK_PASSWORD) && cvarLoginMaxTime) set_task(float(cvarLoginMaxTime), "kick_player", id + TASK_PASSWORD);

	static menuData[256];

	formatex(menuData, charsmax(menuData), "\rREGISTRATION SYSTEM^n^n\rNick: \w[\y%s\w]^n\rStatus: \w[\y%s\w]", playerData[id][NAME], accountStatus[playerData[id][STATUS]]);

	if ((playerData[id][STATUS] == NOT_LOGGED || playerData[id][STATUS] == LOGGED) && !get_bit(id, autoLogin)) {
		if (cvarAutoLoginConfig) format(menuData, charsmax(menuData),"%s^n\wType in console \ysetinfo ^"_%s^" ^"yourpassword^"^n\wThis will make your password load \rautomatically\w.", menuData, cvarSetinfo);
		else format(menuData, charsmax(menuData),"%s^n\wAdd \ysetinfo ^"_%s^" ^"yourpassword^" to your config^n\wThis will make your password load \rautomatically\w.", menuData, cvarSetinfo);
	}

	new menu = menu_create(menuData, "account_menu_handle"), callback = menu_makecallback("account_menu_callback");

	menu_additem(menu, "\yLog In", _, _, callback);
	menu_additem(menu, "\yRegister^n", _, _, callback);
	menu_additem(menu, "\yChange \wPassword", _, _, callback);
	menu_additem(menu, "\yDelete \wAccount^n", _, _, callback);
	menu_additem(menu, "\yLog in as \wGuest \r(NOT RECOMMENDED)^n", _, _, callback);

	if (playerData[id][STATUS] == LOGGED) menu_additem(menu, "\wExit", _, _, callback);

	menu_setprop(menu, MPROP_EXIT, MEXIT_NEVER);

	menu_display(id, menu);

	return PLUGIN_HANDLED;
}

public account_menu_callback(id, menu, item)
{
	switch (item) {
		case 0: return playerData[id][STATUS] == NOT_LOGGED ? ITEM_ENABLED : ITEM_DISABLED;
		case 1: return (playerData[id][STATUS] == NOT_REGISTERED || playerData[id][STATUS] == GUEST) ? ITEM_ENABLED : ITEM_DISABLED;
		case 2, 3: return playerData[id][STATUS] == LOGGED ? ITEM_ENABLED : ITEM_DISABLED;
		case 4: return playerData[id][STATUS] == NOT_REGISTERED ? ITEM_ENABLED : ITEM_DISABLED;
	}

	return ITEM_ENABLED;
}

public account_menu_handle(id, menu, item)
{
	if (!cvarAccountsEnabled || !is_user_connected(id)) return PLUGIN_HANDLED;

	if (item == MENU_EXIT || item == 5) {
		menu_destroy(menu);

		return PLUGIN_HANDLED;
	}

	switch(item) {
		case 0: {
			cod_print_chat(id, "Enter your^x04 password^x01 to^x04 log in.");

			set_hudmessage(255, 128, 0, 0.24, 0.07, 0, 0.0, 3.5, 0.0, 0.0);
			show_hudmessage(id, "Enter your password.");

			client_cmd(id, "messagemode ENTER_YOUR_PASSWORD");
		} case 1: {
			cod_print_chat(id, "You have started the^x04 registration^x01 process. Enter your chosen^x04 password^x01.");

			set_hudmessage(255, 128, 0, 0.24, 0.07, 0, 0.0, 3.5, 0.0, 0.0);
			show_hudmessage(id, "Enter your password.");

			client_cmd(id, "messagemode ENTER_NEW_ACCOUNT_PASSWORD");

			remove_task(id + TASK_PASSWORD);
		} case 2: {
			cod_print_chat(id, "Enter your^x04 current password^x01 to confirm your identity.");

			set_hudmessage(255, 128, 0, 0.22, 0.07, 0, 0.0, 3.5, 0.0, 0.0);
			show_hudmessage(id, "Enter your current password.");

			client_cmd(id, "messagemode ENTER_CURRENT_PASSWORD");
		} case 3: {
			cod_print_chat(id, "Enter your^x04 current password^x01 to confirm your identity.");

			set_hudmessage(255, 128, 0, 0.22, 0.07, 0, 0.0, 3.5, 0.0, 0.0);
			show_hudmessage(id, "Enter your current password.");

			client_cmd(id, "messagemode CONFIRM_YOUR_CURRENT_PASSWORD");
		} case 4: {
			cod_print_chat(id, "You logged in as a^x04 Guest^x01. To protect your nick,^x04 register^x01.");

			set_hudmessage(0, 255, 0, -1.0, 0.9, 0, 0.0, 3.5, 0.0, 0.0);
			show_hudmessage(id, "You have successfully logged in as a Guest.");

			remove_task(id + TASK_PASSWORD);

			playerData[id][STATUS] = GUEST;

			client_cmd(id, "chooseteam");

			engclient_cmd(id, "chooseteam");
		}
	}

	menu_destroy(menu);

	return PLUGIN_HANDLED;
}

public login_account(id)
{
	if (!cvarAccountsEnabled || playerData[id][STATUS] != NOT_LOGGED || !get_bit(id, dataLoaded)) return PLUGIN_HANDLED;

	new password[MAX_PASSWORD];

	read_args(password, charsmax(password));

	remove_quotes(password);

	if (!equal(playerData[id][PASSWORD], password)) {
		if (cvarPasswordMaxFails) {
			if (++playerData[id][FAILS] >= cvarPasswordMaxFails) server_cmd("kick #%d ^"Incorrect password!^"", get_user_userid(id));

			cod_print_chat(id, "The password you entered is^x04 incorrect^x01. (Failed attempts:^x04 %i/%i^x01)", playerData[id][FAILS], cvarPasswordMaxFails);
		} else cod_print_chat(id, "The password you entered is^x04 incorrect^x01.");

		set_hudmessage(255, 0, 0, 0.24, 0.07, 0, 0.0, 3.5, 0.0, 0.0);

		show_hudmessage(id, "The password you entered is incorrect.");

		account_menu(id, true);

		return PLUGIN_HANDLED;
	}

	playerData[id][STATUS] = LOGGED;
	playerData[id][FAILS] = 0;

	remove_task(id + TASK_PASSWORD);

	cod_display_fade(id, 0, 0, 0x0000, 0, 0, 0, 255);

	cod_print_chat(id, "You have successfully^x04 logged in^x01. Have fun!");

	set_hudmessage(0, 255, 0, 0.24, 0.07, 0, 0.0, 3.5, 0.0, 0.0);
	show_hudmessage(id, "You have successfully logged in.");

	client_cmd(id, "chooseteam");
	engclient_cmd(id, "chooseteam");

	return PLUGIN_HANDLED;
}

public register_step_one(id)
{
	if (!cvarAccountsEnabled || (playerData[id][STATUS] != NOT_REGISTERED && playerData[id][STATUS] != GUEST) || !get_bit(id, dataLoaded)) return PLUGIN_HANDLED;

	new password[MAX_PASSWORD];

	read_args(password, charsmax(password));
	remove_quotes(password);

	if (strlen(password) < cvarPasswordMinLength) {
		cod_print_chat(id, "The password must be at least^x04 %i characters^x01 long.", cvarPasswordMinLength);

		set_hudmessage(255, 0, 0, 0.24, 0.07, 0, 0.0, 3.5, 0.0, 0.0);
		show_hudmessage(id, "The password must be at least %i characters long.", cvarPasswordMinLength);

		account_menu(id, true);

		return PLUGIN_HANDLED;
	}

	copy(playerData[id][TEMP_PASSWORD], charsmax(playerData[][TEMP_PASSWORD]), password);

	cod_print_chat(id, "Now repeat your chosen^x04 password^x01.");

	set_hudmessage(255, 128, 0, 0.24, 0.07, 0, 0.0, 3.5, 0.0, 0.0);
	show_hudmessage(id, "Repeat your chosen password.");

	client_cmd(id, "messagemode REPEAT_NEW_ACCOUNT_PASSWORD");

	return PLUGIN_HANDLED;
}

public register_step_two(id)
{
	if (!cvarAccountsEnabled || (playerData[id][STATUS] != NOT_REGISTERED && playerData[id][STATUS] != GUEST) || !get_bit(id, dataLoaded)) return PLUGIN_HANDLED;

	new password[MAX_PASSWORD];

	read_args(password, charsmax(password));
	remove_quotes(password);

	if (!equal(password, playerData[id][TEMP_PASSWORD])) {
		cod_print_chat(id, "The passwords you entered^x04 do not match^x01.");

		set_hudmessage(255, 0, 0, 0.24, 0.07, 0, 0.0, 3.5, 0.0, 0.0);
		show_hudmessage(id, "The passwords you entered do not match.");

		account_menu(id, true);

		return PLUGIN_HANDLED;
	}

	new menuData[192];

	formatex(menuData, charsmax(menuData), "\rREGISTRATION CONFIRMATION^n^n\wYour Nick: \y[\r%s\y]^n\wYour Password: \y[\r%s\y]", playerData[id][NAME], playerData[id][TEMP_PASSWORD]);

	new menu = menu_create(menuData, "register_confirmation_handle");

	menu_additem(menu, "\rConfirm \wRegistration");
	menu_additem(menu, "\yChange \wPassword^n");
	menu_additem(menu, "\wCancel \wRegistration");

	menu_setprop(menu, MPROP_EXIT, MEXIT_NEVER);

	menu_display(id, menu);

	return PLUGIN_HANDLED;
}

public register_confirmation_handle(id, menu, item)
{
	if (!cvarAccountsEnabled || !is_user_connected(id)) return PLUGIN_HANDLED;

	if (item == MENU_EXIT) {
		menu_destroy(menu);

		return PLUGIN_HANDLED;
	}

	menu_destroy(menu);

	switch (item) {
		case 0: {
			playerData[id][STATUS] = LOGGED;

			copy(playerData[id][PASSWORD], charsmax(playerData[][PASSWORD]), playerData[id][TEMP_PASSWORD]);

			account_query(id, INSERT);

			cod_display_fade(id, 0, 0, 0x0000, 0, 0, 0, 255);

			set_hudmessage(0, 255, 0, -1.0, 0.9, 0, 0.0, 3.5, 0.0, 0.0);
			show_hudmessage(id, "You have been successfully registered and logged in.");

			cod_print_chat(id, "Your nick has been successfully^x04 registered^x01.");

			if (cvarAutoLoginConfig) {
				cod_print_chat(id, "Type the command^x04 setinfo ^"_%s^" ^"%s^"^x01 in console to have your password loaded automatically.", cvarSetinfo, playerData[id][PASSWORD]);

				cod_cmd_execute(id, "setinfo _%s %s", cvarSetinfo, playerData[id][PASSWORD]);
				cod_cmd_execute(id, "writecfg %s", cvarSetinfo);
			} else {
				cod_print_chat(id, "Add the command^x04 setinfo ^"_%s^" ^"%s^"^x01 to your config to have your password loaded automatically.", cvarSetinfo, playerData[id][PASSWORD]);
			}

			client_cmd(id, "chooseteam");
			engclient_cmd(id, "chooseteam");
		} case 1: {
			cod_print_chat(id, "You have started the^x04 registration^x01 process. Enter your chosen^x04 password^x01.");

			set_hudmessage(255, 128, 0, 0.24, 0.07, 0, 0.0, 3.5, 0.0, 0.0);
			show_hudmessage(id, "Enter your chosen password.");

			client_cmd(id, "messagemode ENTER_NEW_ACCOUNT_PASSWORD");
		} case 2: account_menu(id, false);
	}

	return PLUGIN_HANDLED;
}

public change_step_one(id)
{
	if (!cvarAccountsEnabled || playerData[id][STATUS] != LOGGED || !get_bit(id, dataLoaded)) return PLUGIN_HANDLED;

	new password[MAX_PASSWORD];

	read_args(password, charsmax(password));
	remove_quotes(password);

	if (!equal(playerData[id][PASSWORD], password)) {
		if (cvarPasswordMaxFails) {
			if (++playerData[id][FAILS] >= cvarPasswordMaxFails) server_cmd("kick #%d ^"Incorrect password!^"", get_user_userid(id));

			cod_print_chat(id, "The password you entered is^x04 incorrect^x01. (Failed attempts:^x04 %i/%i^x01)", playerData[id][FAILS], cvarPasswordMaxFails);
		} else cod_print_chat(id, "The password you entered is^x04 incorrect^x01.");

		set_hudmessage(255, 0, 0, 0.24, 0.07, 0, 0.0, 3.5, 0.0, 0.0);
		show_hudmessage(id, "The password you entered is incorrect.");

		account_menu(id, true);

		return PLUGIN_HANDLED;
	}

	cod_print_chat(id, "Enter your^x04 new password^x01.");

	set_hudmessage(255, 128, 0, 0.24, 0.07, 0, 0.0, 3.5, 0.0, 0.0);
	show_hudmessage(id, "Enter your new password.");

	client_cmd(id, "messagemode ENTER_NEW_PASSWORD");

	return PLUGIN_HANDLED;
}

public change_step_two(id)
{
	if (!cvarAccountsEnabled || playerData[id][STATUS] != LOGGED || !get_bit(id, dataLoaded)) return PLUGIN_HANDLED;

	new password[MAX_PASSWORD];

	read_args(password, charsmax(password));
	remove_quotes(password);

	if (equal(playerData[id][PASSWORD], password)) {
		cod_print_chat(id, "The new password is^x04 the same^x01 as the current one.");

		set_hudmessage(255, 0, 0, 0.24, 0.07, 0, 0.0, 3.5, 0.0, 0.0);
		show_hudmessage(id, "The new password is the same as the current one.");

		account_menu(id, true);

		return PLUGIN_HANDLED;
	}

	if (strlen(password) < cvarPasswordMinLength) {
		cod_print_chat(id, "The new password must be at least^x04 %i characters^x01 long.", cvarPasswordMinLength);

		set_hudmessage(255, 0, 0, 0.24, 0.07, 0, 0.0, 3.5, 0.0, 0.0);
		show_hudmessage(id, "The new password must be at least %i characters long.", cvarPasswordMinLength);

		account_menu(id, true);

		return PLUGIN_HANDLED;
	}

	copy(playerData[id][TEMP_PASSWORD], charsmax(playerData[][TEMP_PASSWORD]), password);

	cod_print_chat(id, "Repeat your new^x04 password^x01.");

	set_hudmessage(255, 128, 0, 0.24, 0.07, 0, 0.0, 3.5, 0.0, 0.0);
	show_hudmessage(id, "Repeat your new password.");

	client_cmd(id, "messagemode REPEAT_NEW_PASSWORD");

	return PLUGIN_HANDLED;
}

public change_step_three(id)
{
	if (!cvarAccountsEnabled || playerData[id][STATUS] != LOGGED || !get_bit(id, dataLoaded)) return PLUGIN_HANDLED;

	new password[MAX_PASSWORD];

	read_args(password, charsmax(password));
	remove_quotes(password);

	if (!equal(password, playerData[id][TEMP_PASSWORD])) {
		cod_print_chat(id, "The passwords you entered^x04 do not match^x01.");

		set_hudmessage(255, 0, 0, 0.24, 0.07, 0, 0.0, 3.5, 0.0, 0.0);
		show_hudmessage(id, "The passwords you entered do not match.");

		account_menu(id, true);

		return PLUGIN_HANDLED;
	}

	copy(playerData[id][PASSWORD], charsmax(playerData[][PASSWORD]), password);

	account_query(id, UPDATE);

	set_hudmessage(0, 255, 0, 0.24, 0.07, 0, 0.0, 3.5, 0.0, 0.0);
	show_hudmessage(id, "Your password has been successfully changed.");

	cod_print_chat(id, "Your password has been successfully^x04 changed^x01.");

	if (cvarAutoLoginConfig) {
		cod_print_chat(id, "Type the command^x04 setinfo ^"_%s^" ^"%s^"^x01 in console to have your password loaded automatically.", cvarSetinfo, playerData[id][PASSWORD]);

		cod_cmd_execute(id, "setinfo _%s %s", cvarSetinfo, playerData[id][PASSWORD]);
		cod_cmd_execute(id, "writecfg %s", cvarSetinfo);
	} else {
		cod_print_chat(id, "Add the command^x04 setinfo ^"_%s^" ^"%s^"^x01 to your config to have your password loaded automatically.", cvarSetinfo, playerData[id][PASSWORD]);
	}

	return PLUGIN_HANDLED;
}

public delete_account(id)
{
	if (!cvarAccountsEnabled || playerData[id][STATUS] != LOGGED || !get_bit(id, dataLoaded)) return PLUGIN_HANDLED;

	new password[MAX_PASSWORD];

	read_args(password, charsmax(password));
	remove_quotes(password);

	if (!equal(playerData[id][PASSWORD], password)) {
		if (cvarPasswordMaxFails) {
			if (++playerData[id][FAILS] >= cvarPasswordMaxFails) server_cmd("kick #%d ^"Incorrect password!^"", get_user_userid(id));

			cod_print_chat(id, "The password you entered is^x04 incorrect^x01. (Failed attempts:^x04 %i/%i^x01)", playerData[id][FAILS], cvarPasswordMaxFails);
		} else cod_print_chat(id, "The password you entered is^x04 incorrect^x01.");

		set_hudmessage(255, 0, 0, 0.24, 0.07, 0, 0.0, 3.5, 0.0, 0.0);
		show_hudmessage(id, "The password you entered is incorrect.");

		account_menu(id, true);

		return PLUGIN_HANDLED;
	}

	new menuData[128];

	formatex(menuData, charsmax(menuData), "\wAre you sure you want to \rdelete \wyour account?");

	new menu = menu_create(menuData, "delete_account_handle");

	menu_additem(menu, "\rYes");
	menu_additem(menu, "\wNo^n");
	menu_additem(menu, "\wExit");

	menu_setprop(menu, MPROP_EXIT, MEXIT_NEVER);

	menu_display(id, menu);

	return PLUGIN_HANDLED;
}

public delete_account_handle(id, menu, item)
{
	if (item == 0) {
		account_query(id, DELETE);

		console_print(id, "==================================");
		console_print(id, "==========REGISTRATION SYSTEM==========");
		console_print(id, "              You deleted the account with nick: %s", playerData[id][NAME]);
		console_print(id, "==================================");

		server_cmd("kick #%d ^"Account has been deleted!^"", get_user_userid(id));
	}

	menu_destroy(menu);

	return PLUGIN_CONTINUE;
}

public sql_init()
{
	new host[64], user[64], pass[64], db[64], queryData[128], error[128], errorNum;

	get_cvar_string("cod_sql_host", host, charsmax(host));
	get_cvar_string("cod_sql_user", user, charsmax(user));
	get_cvar_string("cod_sql_pass", pass, charsmax(pass));
	get_cvar_string("cod_sql_db", db, charsmax(db));

	sql = SQL_MakeDbTuple(host, user, pass, db);

	new Handle:connection = SQL_Connect(sql, errorNum, error, charsmax(error));

	if (errorNum) {
		cod_log_error(PLUGIN, "SQL Query Error. [%d] %s", errorNum, error);

		sql = Empty_Handle;

		set_task(5.0, "sql_init");

		return;
	}

	formatex(queryData, charsmax(queryData), "CREATE TABLE IF NOT EXISTS `cod_accounts` (`name` VARCHAR(%i), `pass` VARCHAR(%i), PRIMARY KEY(`name`));", MAX_SAFE_NAME, MAX_PASSWORD * 2);

	new Handle:query = SQL_PrepareQuery(connection, queryData);

	SQL_Execute(query);

	SQL_FreeHandle(query);
	SQL_FreeHandle(connection);

	sqlConnected = true;
}

public load_account(id)
{
	id -= TASK_LOAD;

	if (!sqlConnected) {
		set_task(1.0, "load_account", id + TASK_LOAD);

		return;
	}

	new queryData[128], tempId[1];

	tempId[0] = id;

	formatex(queryData, charsmax(queryData), "SELECT * FROM `cod_accounts` WHERE name = ^"%s^"", playerData[id][SAFE_NAME]);
	SQL_ThreadQuery(sql, "load_account_handle", queryData, tempId, sizeof(tempId));
}

public load_account_handle(failState, Handle:query, error[], errorNum, tempId[], dataSize)
{
	new id = tempId[0];

	if (failState)  {
		if (failState == TQUERY_CONNECT_FAILED) cod_log_error(PLUGIN, "Could not connect to SQL database. Error: %s (%d)", error, errorNum);
		else if (failState == TQUERY_QUERY_FAILED) cod_log_error(PLUGIN, "Threaded query failed. Error: %s (%d)", error, errorNum);

		return;
	}

	if (SQL_MoreResults(query)) {
		SQL_ReadResult(query, SQL_FieldNameToNum(query, "pass"), playerData[id][PASSWORD], charsmax(playerData[][PASSWORD]));

		if (playerData[id][PASSWORD][0]) {
			new password[MAX_PASSWORD], info[32];

			formatex(info, charsmax(info), "_%s", cvarSetinfo);

			if (cvarAutoLoginConfig) cod_cmd_execute(id, "exec %s.cfg", cvarSetinfo);

			get_user_info(id, info, password, charsmax(password));

			if (equal(playerData[id][PASSWORD], password)) {
				playerData[id][STATUS] = LOGGED;

				cod_display_fade(id, 0, 0, 0x0000, 0, 0, 0, 255);

				set_bit(id, autoLogin);
			} else {
				playerData[id][STATUS] = NOT_LOGGED;

				cod_print_chat(id, "You must^x03 log in^x01 to access the main features!");

				account_menu(id, true);
			}

			if (cvarAutoLoginConfig) cod_cmd_execute(id, "exec config.cfg");
		}
	}

	set_bit(id, dataLoaded);
}

public account_query(id, type)
{
	if (!is_user_connected(id)) return;

	new queryData[256], password[MAX_PASSWORD * 2];

	cod_sql_string(playerData[id][PASSWORD], password, charsmax(password));

	switch(type) {
		case INSERT: formatex(queryData, charsmax(queryData), "INSERT INTO `cod_accounts` VALUES (^"%s^", '%s')", playerData[id][SAFE_NAME], password);
		case UPDATE: formatex(queryData, charsmax(queryData), "UPDATE `cod_accounts` SET pass = '%s' WHERE name = ^"%s^"", password, playerData[id][SAFE_NAME]);
		case DELETE: formatex(queryData, charsmax(queryData), "DELETE FROM `cod_accounts` WHERE name = ^"%s^"", playerData[id][SAFE_NAME]);
	}

	SQL_ThreadQuery(sql, "ignore_handle", queryData);
}

public ignore_handle(failState, Handle:query, error[], errorNum, data[], dataSize)
{
	if (failState)  {
		if (failState == TQUERY_CONNECT_FAILED) cod_log_error(PLUGIN, "Could not connect to SQL database. Error: %s (%d)", error, errorNum);
		else if (failState == TQUERY_QUERY_FAILED) cod_log_error(PLUGIN, "Threaded query failed. Error: %s (%d)", error, errorNum);
	}

	return PLUGIN_CONTINUE;
}

public _cod_check_account(plugin_id, num_params)
{
	if (!cvarAccountsEnabled) return 1;

	new id = get_param(1);

	if (!is_user_valid(id)) {
		cod_log_error(PLUGIN, "Invalid Player (ID: %d)", id);

		return 0;
	}

	// Bots never register an account; treat them as logged in so the mod can give them a class.
	if (is_user_bot(id)) return 1;

	if (playerData[id][STATUS] < LOGGED) {
		cod_print_chat(id, "You must^x03 log in^x01 to access the main features!");

		account_menu(id, true);

		return 0;
	}

	return 1;
}