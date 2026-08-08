#include <amxmodx>
#include <sqlx>
#include <fakemeta>
#include <cod>

#define PLUGIN "CoD Clans"
#define VERSION "1.3.2"
#define AUTHOR "O'Zone"

#define TASK_INFO 9843

new const commandClan[][] = { "klan", "say /clan", "say_team /clan", "say /clans", "say_team /clans", "say /klany", "say_team /klany", "say /klan", "say_team /klan" };

enum _:clanInfo { CLAN_ID, CLAN_LEVEL, CLAN_HONOR, CLAN_HEALTH, CLAN_GRAVITY, CLAN_DAMAGE, CLAN_EXP, CLAN_KILLS, CLAN_WINS, CLAN_MEMBERS, Trie:CLAN_STATUS, CLAN_NAME[MAX_NAME] };
enum _:warInfo { WAR_ID, WAR_CLAN, WAR_CLAN2, WAR_PROGRESS, WAR_PROGRESS2, WAR_DURATION, WAR_REWARD };
enum _:statusInfo { STATUS_NONE, STATUS_MEMBER, STATUS_DEPUTY, STATUS_LEADER };
enum _:glow { GLOW_NEVER, GLOW_EXCEPT, GLOW_ALWAYS };

new cvarCreateLevel, cvarCreateFee, cvarJoinFee, cvarNameChangeFee, cvarMembersStart, cvarLevelMax, cvarSkillMax, cvarChatPrefix, cvarLevelCost, cvarNextLevelCost,
	cvarSkillCost, cvarNextSkillCost, cvarMembersPerLevel, cvarHealthPerLevel, cvarGravityPerLevel, cvarDamagePerLevel, cvarExpPerLevel, cvarEnemyGlow;

new playerName[MAX_PLAYERS + 1][MAX_NAME], chosenName[MAX_PLAYERS + 1][MAX_NAME], clan[MAX_PLAYERS + 1], chosenId[MAX_PLAYERS + 1], warFrags[MAX_PLAYERS + 1],
	warReward[MAX_PLAYERS + 1], Handle:sql, Handle:connection, bool:sqlConnected, Array:codClans, Array:codWars, bool:mapEnd, info, loaded;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	codClans = ArrayCreate(clanInfo);
	codWars = ArrayCreate(warInfo);

	for (new i; i < sizeof commandClan; i++) register_clcmd(commandClan[i], "show_clan_menu");

	register_clcmd("ENTER_CLAN_NAME", "create_clan_handle");
	register_clcmd("ENTER_NEW_CLAN_NAME", "change_name_handle");
	register_clcmd("ENTER_HONOR_AMOUNT", "deposit_honor_handle");
	register_clcmd("ENTER_FRAG_COUNT", "set_war_frags_handle");
	register_clcmd("ENTER_REWARD_AMOUNT", "set_war_reward_handle");

	bind_pcvar_num(create_cvar("cod_clans_create_level", "25"), cvarCreateLevel);
	bind_pcvar_num(create_cvar("cod_clans_create_fee", "250"), cvarCreateFee);
	bind_pcvar_num(create_cvar("cod_clans_join_fee", "100"), cvarJoinFee);
	bind_pcvar_num(create_cvar("cod_clans_name_change_fee", "100"), cvarNameChangeFee);
	bind_pcvar_num(create_cvar("cod_clans_members_start", "3"), cvarMembersStart);
	bind_pcvar_num(create_cvar("cod_clans_level_max", "10"), cvarLevelMax);
	bind_pcvar_num(create_cvar("cod_clans_skill_max", "10"), cvarSkillMax);
	bind_pcvar_num(create_cvar("cod_clans_chat_prefix", "1"), cvarChatPrefix);
	bind_pcvar_num(create_cvar("cod_clans_level_cost", "1000"), cvarLevelCost);
	bind_pcvar_num(create_cvar("cod_clans_next_level_cost", "1000"), cvarNextLevelCost);
	bind_pcvar_num(create_cvar("cod_clans_skill_cost", "500"), cvarSkillCost);
	bind_pcvar_num(create_cvar("cod_clans_next_skill_cost", "500"), cvarNextSkillCost);
	bind_pcvar_num(create_cvar("cod_clans_members_per_level", "1"), cvarMembersPerLevel);
	bind_pcvar_num(create_cvar("cod_clans_health_per_level", "1"), cvarHealthPerLevel);
	bind_pcvar_num(create_cvar("cod_clans_gravity_per_level", "5"), cvarGravityPerLevel);
	bind_pcvar_num(create_cvar("cod_clans_damage_per_level", "1"), cvarDamagePerLevel);
	bind_pcvar_num(create_cvar("cod_clans_exp_per_level", "3"), cvarExpPerLevel);
	bind_pcvar_num(create_cvar("cod_clans_enemy_glow", "1"), cvarEnemyGlow);

	register_message(get_user_msgid("SayText"), "say_text");

	register_forward(FM_AddToFullPack, "add_to_full_pack", 1);
}

public plugin_natives()
{
	register_native("cod_get_user_clan", "_cod_get_user_clan", 1);
	register_native("cod_get_user_clan_bonus", "_cod_get_user_clan_bonus", 1);
	register_native("cod_get_clan_name", "_cod_get_clan_name", 1);
}

public plugin_cfg()
{
	new codClan[clanInfo];

	codClan[CLAN_NAME] = "None";

	ArrayPushArray(codClans, codClan);

	sql_init();
}

public plugin_end()
{
	if (sql != Empty_Handle) SQL_FreeHandle(sql);
	if (connection != Empty_Handle) SQL_FreeHandle(connection);

	ArrayDestroy(codClans);
}

public cod_reset_data()
	clear_database();

public cod_reset_all_data()
	clear_database();

public clear_database()
{
	for (new i = 1; i <= MAX_PLAYERS; i++) clan[i] = 0;

	sqlConnected = false;

	new tempData[256];

	formatex(tempData, charsmax(tempData), "DROP TABLE `cod_clans`; DROP TABLE `cod_clans_applications`; DROP TABLE `cod_clans_members`; DROP TABLE `cod_clans_wars`;");

	SQL_ThreadQuery(sql, "ignore_handle", tempData);
}

public client_putinserver(id)
{
	if (is_user_bot(id) || is_user_hltv(id)) return;

	clan[id] = 0;
	warFrags[id] = 50;
	warReward[id] = 1000;

	get_user_name(id, playerName[id], charsmax(playerName));

	cod_sql_string(playerName[id], playerName[id], charsmax(playerName));

	set_task(0.1, "load_data", id);
}

public client_disconnected(id)
{
	remove_task(id);
	remove_task(id + TASK_INFO);

	rem_bit(id, loaded);
	rem_bit(id, info);

	clan[id] = 0;
}

public cod_end_map()
	mapEnd = true;

public cod_spawned(id, respawn)
{
	if (!clan[id]) return PLUGIN_CONTINUE;

	if (!get_bit(id, info) && is_user_alive(id)) set_task(5.0, "show_clan_info", id + TASK_INFO);

	if (!respawn) cod_add_user_gravity(id, -(cvarGravityPerLevel * get_clan_info(clan[id], CLAN_GRAVITY) / 100.0), ROUND);

	return PLUGIN_CONTINUE;
}

public cod_damage_post(attacker, victim, weapon, Float:damage, damageBits, hitPlace)
{
	if (!clan[attacker] || damageBits & DMG_CODSKILL) return PLUGIN_CONTINUE;

	cod_inflict_damage(attacker, victim, damage * cvarDamagePerLevel * get_clan_info(clan[attacker], CLAN_DAMAGE) / 100.0, 0.0, damageBits);

	return PLUGIN_CONTINUE;
}

public cod_killed(killer, victim, weaponId, hitPlace)
{
	if (!clan[killer]) return PLUGIN_CONTINUE;

	set_clan_info(clan[killer], CLAN_KILLS, 1);

	if (clan[victim]) check_war(killer, victim);

	return PLUGIN_CONTINUE;
}

public show_clan_menu(id, sound)
{
	if (!is_user_connected(id) || mapEnd || !cod_check_account(id)) return PLUGIN_HANDLED;

	if (!sound) client_cmd(id, "spk %s", codSounds[SOUND_SELECT]);

	new codClan[clanInfo], menuData[128], menu, callback = menu_makecallback("show_clan_menu_callback");

	if (clan[id]) {
		ArrayGetArray(codClans, get_clan_id(clan[id]), codClan);

		formatex(menuData, charsmax(menuData), "\yClan \rMenu^n\wCurrent Clan:\y %s^n\wMembers: \y%i/%i %s \w| \y%i Honor\w", codClan[CLAN_NAME], codClan[CLAN_MEMBERS], codClan[CLAN_LEVEL] * cvarMembersPerLevel + cvarMembersStart, codClan[CLAN_MEMBERS] > 1 ? "Members" : "Member", codClan[CLAN_HONOR]);

		menu = menu_create(menuData, "show_clan_menu_handle");

		menu_additem(menu, "\wManage \yClan", "1", _, callback);
		menu_additem(menu, "\wLeave \yClan", "2", _, callback);
		menu_additem(menu, "\wMembers \yOnline", "3", _, callback);
		menu_additem(menu, "\wDeposit \yHonor", "4", _, callback);
		menu_additem(menu, "\wDepositors \yList", "5", _, callback);
	} else {
		menu = menu_create("\yClan \rMenu^n\wCurrent Clan:\y None", "show_clan_menu_handle");

		if (cvarCreateLevel && cvarCreateFee) formatex(menuData, charsmax(menuData), "\wCreate \yClan \r(Requires Level %i and %i Honor)", cvarCreateLevel, cvarCreateFee);
		else if (cvarCreateLevel) formatex(menuData, charsmax(menuData), "\wCreate \yClan \r(Requires Level %i)", cvarCreateLevel);
		else if (cvarCreateFee) formatex(menuData, charsmax(menuData), "\wCreate \yClan \r(Requires %i Honor)", cvarCreateFee);
		else formatex(menuData, charsmax(menuData), "\wCreate \yClan");

		menu_additem(menu, menuData, "0", _, callback);

		menu_additem(menu, "\wSubmit \yApplication", "7", _, callback);
	}

	menu_additem(menu, "\wTop15 \yClans", "6", _, callback);

	menu_setprop(menu, MPROP_BACKNAME, "Back");
	menu_setprop(menu, MPROP_NEXTNAME, "Next");
	menu_setprop(menu, MPROP_EXITNAME, "Exit");

	menu_display(id, menu);

	return PLUGIN_HANDLED;
}

public show_clan_menu_callback(id, menu, item)
{
	new itemData[2], itemAccess, menuCallback;

	menu_item_getinfo(menu, item, itemAccess, itemData, charsmax(itemData), _, _, menuCallback);

	switch (str_to_num(itemData)) {
		case 0: return cod_get_user_highest_level(id) >= cvarCreateLevel ? ITEM_ENABLED : ITEM_DISABLED;
		case 1: return get_user_status(id) > STATUS_MEMBER ? ITEM_ENABLED : ITEM_DISABLED;
		case 2, 3, 4, 5: return clan[id] ? ITEM_ENABLED : ITEM_DISABLED;
	}

	return ITEM_ENABLED;
}

public show_clan_menu_handle(id, menu, item)
{
	if (!is_user_connected(id) || mapEnd || !cod_check_account(id)) return PLUGIN_HANDLED;

	if (item == MENU_EXIT) {
		client_cmd(id, "spk %s", codSounds[SOUND_EXIT]);

		menu_destroy(menu);

		return PLUGIN_HANDLED;
	}

	client_cmd(id, "spk %s", codSounds[SOUND_SELECT]);

	new itemData[2], itemAccess, menuCallback;

	menu_item_getinfo(menu, item, itemAccess, itemData, charsmax(itemData), _, _, menuCallback);

	switch (str_to_num(itemData)) {
		case 0: {
			if (clan[id]) {
				cod_print_chat(id, "You can't create a clan if you are already in one!");

				return PLUGIN_HANDLED;
			}

			if (cvarCreateLevel && cod_get_user_highest_level(id) < cvarCreateLevel) {
				cod_print_chat(id, "Your level is too low to create a clan (Requires^x03 level %i^x01)!", cvarCreateLevel);

				return PLUGIN_HANDLED;
			}

			if (cvarCreateFee && cod_get_user_honor(id) < cvarCreateFee) {
				cod_print_chat(id, "You don't have enough honor to create a clan (Requires^x03 %i honor^x01)!", cvarCreateFee);

				return PLUGIN_HANDLED;
			}

			client_cmd(id, "messagemode ENTER_CLAN_NAME");
		} case 1: {
			if (get_user_status(id) > STATUS_MEMBER) {
				leader_menu(id);

				return PLUGIN_HANDLED;
			}
		} case 2: leave_confim_menu(id);
		case 3: members_online_menu(id);
		case 4: {
			client_cmd(id, "messagemode ENTER_HONOR_AMOUNT");

			client_print(id, print_center, "Enter the amount of Honor you want to deposit");

			cod_print_chat(id, "Enter the amount of Honor you want to deposit.");
		} case 5: depositors_list(id);
		case 6: clans_top15(id);
		case 7: application_menu(id);
	}

	menu_destroy(menu);

	return PLUGIN_HANDLED;
}

public create_clan_handle(id)
{
	if (!is_user_connected(id) || !cod_check_account(id) || mapEnd || clan[id]) return PLUGIN_HANDLED;

	client_cmd(id, "spk %s", codSounds[SOUND_EXIT]);

	if (cvarCreateFee && cod_get_user_highest_level(id) < cvarCreateLevel) {
		cod_print_chat(id, "Your level is too low to create a clan (Requires^x03 level %i^x01)!", cvarCreateLevel);

		return PLUGIN_HANDLED;
	}

	if (cvarCreateFee && cod_get_user_honor(id) < cvarCreateFee) {
		cod_print_chat(id, "You don't have enough honor to create a clan (Requires^x03 %i honor^x01)!", cvarCreateFee);

		return PLUGIN_HANDLED;
	}

	new clanName[MAX_NAME];

	read_args(clanName, charsmax(clanName));
	remove_quotes(clanName);
	trim(clanName);

	if (equal(clanName, "")) {
		cod_print_chat(id, "You didn't enter a clan name.");

		show_clan_menu(id, 1);

		return PLUGIN_HANDLED;
	}

	if (strlen(clanName) < 3) {
		cod_print_chat(id, "The clan name must be at least 3 characters long.");

		show_clan_menu(id, 1);

		return PLUGIN_HANDLED;
	}

	if (check_clan_name(clanName)) {
		cod_print_chat(id, "A clan with that name already exists.");

		show_clan_menu(id, 1);

		return PLUGIN_HANDLED;
	}

	if (create_clan(id, clanName)) cod_print_chat(id, "You successfully created the clan^x03 %s^01.", clanName);
	else cod_print_chat(id, "An unexpected error occurred while creating the clan.");

	return PLUGIN_HANDLED;
}

public leave_confim_menu(id)
{
	if (!is_user_connected(id) || mapEnd || !clan[id] || !cod_check_account(id)) return PLUGIN_HANDLED;

	new menu = menu_create("\wAre you \ysure\w you want to \rleave \wthe clan?", "leave_confim_menu_handle");

	menu_additem(menu, "Yes");
	menu_additem(menu, "No^n");

	menu_setprop(menu, MPROP_EXITNAME, "Exit");

	menu_display(id, menu);

	return PLUGIN_HANDLED;
}

public leave_confim_menu_handle(id, menu, item)
{
	if (!is_user_connected(id) || mapEnd || !clan[id] || !cod_check_account(id)) return PLUGIN_HANDLED;

	if (item == MENU_EXIT) {
		client_cmd(id, "spk %s", codSounds[SOUND_EXIT]);

		menu_destroy(menu);

		return PLUGIN_HANDLED;
	}

	client_cmd(id, "spk %s", codSounds[SOUND_SELECT]);

	switch (item) {
		case 0: {
			if (get_user_status(id) == STATUS_LEADER) {
				cod_print_chat(id, "Hand over clan leadership to one of the members before you leave.");

				show_clan_menu(id, 1);

				return PLUGIN_HANDLED;
			}

			set_user_clan(id);

			cod_print_chat(id, "You left your clan.");

			show_clan_menu(id, 1);
		} case 1: show_clan_menu(id, 1);
	}

	return PLUGIN_HANDLED;
}

public members_online_menu(id)
{
	if (!is_user_connected(id) || mapEnd || !clan[id] || !cod_check_account(id)) return PLUGIN_HANDLED;

	new clanName[MAX_NAME], playersAvailable = 0;

	new menu = menu_create("\yMembers \rOnline:", "members_online_menu_handle");

	for (new player = 1; player <= MAX_PLAYERS; player++) {
		if (!is_user_connected(id) || clan[id] != clan[player]) continue;

		playersAvailable++;

		get_user_name(player, clanName, charsmax(clanName));

		switch (get_user_status(player)) {
			case STATUS_MEMBER: add(clanName, charsmax(clanName), " \y[Member]");
			case STATUS_DEPUTY: add(clanName, charsmax(clanName), " \y[Deputy]");
			case STATUS_LEADER: add(clanName, charsmax(clanName), " \y[Leader]");
		}

		menu_additem(menu, clanName);
	}

	menu_setprop(menu, MPROP_EXITNAME, "Exit");
	menu_setprop(menu, MPROP_BACKNAME, "Back");
	menu_setprop(menu, MPROP_NEXTNAME, "Next");

	if (!playersAvailable) cod_print_chat(id, "There are no members of your clan on the server!");
	else menu_display(id, menu);

	return PLUGIN_HANDLED;
}

public members_online_menu_handle(id, menu, item)
{
	if (!is_user_connected(id) || mapEnd || !clan[id] || !cod_check_account(id)) return PLUGIN_HANDLED;

	if (item == MENU_EXIT) {
		client_cmd(id, "spk %s", codSounds[SOUND_EXIT]);

		show_clan_menu(id, 1);

		menu_destroy(menu);

		return PLUGIN_HANDLED;
	}

	client_cmd(id, "spk %s", codSounds[SOUND_SELECT]);

	menu_destroy(menu);

	members_online_menu(id);

	return PLUGIN_HANDLED;
}

public leader_menu(id)
{
	if (!is_user_connected(id) || mapEnd || !clan[id] || !cod_check_account(id)) return PLUGIN_HANDLED;

	new menu = menu_create("\yManage \rClan", "leader_menu_handle"), callback = menu_makecallback("leader_menu_callback");

	menu_additem(menu, "\wDisband \yClan", _, _, callback);
	menu_additem(menu, "\wUpgrade \ySkills", _, _, callback);
	menu_additem(menu, "\wInvite \yPlayer", _, _, callback);
	menu_additem(menu, "\wManage \yMembers", _, _, callback);
	menu_additem(menu, "\wReview \yApplications", _, _, callback);
	menu_additem(menu, "\wClan \yWars", _, _, callback);
	menu_additem(menu, "\wChange \yClan Name^n", _, _, callback);
	menu_additem(menu, "\wBack", _, _, callback);

	menu_setprop(menu, MPROP_EXITNAME, "Exit");

	menu_display(id, menu);

	return PLUGIN_HANDLED;
}

public leader_menu_callback(id, menu, item)
{
	switch (item) {
		case 1: get_user_status(id) == STATUS_LEADER ? ITEM_ENABLED : ITEM_DISABLED;
		case 2: if (((get_clan_info(clan[id], CLAN_LEVEL) * cvarMembersPerLevel) + cvarMembersStart) <= get_clan_info(clan[id], CLAN_MEMBERS)) return ITEM_DISABLED;
		case 4: if (((get_clan_info(clan[id], CLAN_LEVEL) * cvarMembersPerLevel) + cvarMembersStart) <= get_clan_info(clan[id], CLAN_MEMBERS) || !get_applications_count(clan[id])) return ITEM_DISABLED;
	}

	return ITEM_ENABLED;
}

public leader_menu_handle(id, menu, item)
{
	if (!is_user_connected(id) || mapEnd || !clan[id] || !cod_check_account(id)) return PLUGIN_HANDLED;

	if (item == MENU_EXIT) {
		client_cmd(id, "spk %s", codSounds[SOUND_EXIT]);

		show_clan_menu(id, 1);

		menu_destroy(menu);

		return PLUGIN_HANDLED;
	}

	client_cmd(id, "spk %s", codSounds[SOUND_SELECT]);

	switch (item) {
		case 0: disband_menu(id);
		case 1: skills_menu(id);
		case 2: invite_menu(id);
		case 3: members_menu(id);
		case 4: applications_menu(id);
		case 5: wars_menu(id);
		case 6: change_name_menu(id);
		case 7: show_clan_menu(id, 1);
	}

	return PLUGIN_HANDLED;
}

public change_name_menu(id)
{
	if (!is_user_connected(id) || mapEnd || get_user_status(id) < STATUS_DEPUTY || !cod_check_account(id)) return PLUGIN_HANDLED;

	if (!cvarNameChangeFee) {
		client_cmd(id, "messagemode ENTER_NEW_CLAN_NAME");
	} else {
		new menuData[128], menu;

		formatex(menuData, charsmax(menuData), "\wThe change costs \y%i\w honor. Are you \ysure\w you want to \rchange the name\w of the clan?", cvarNameChangeFee);

		menu = menu_create(menuData, "change_name_menu_handle");

		menu_additem(menu, "Yes", "0");
		menu_additem(menu, "No^n", "1");

		menu_setprop(menu, MPROP_EXITNAME, "Exit");

		menu_display(id, menu);
	}

	return PLUGIN_HANDLED;
}

public change_name_menu_handle(id, menu, item)
{
	if (!is_user_connected(id) || mapEnd || get_user_status(id) < STATUS_DEPUTY || !cod_check_account(id)) return PLUGIN_HANDLED;

	if (item == MENU_EXIT) {
		client_cmd(id, "spk %s", codSounds[SOUND_EXIT]);

		show_clan_menu(id, 1);

		menu_destroy(menu);

		return PLUGIN_HANDLED;
	}

	client_cmd(id, "spk %s", codSounds[SOUND_SELECT]);

	switch (item) {
		case 0: client_cmd(id, "messagemode ENTER_NEW_CLAN_NAME");
		case 1: show_clan_menu(id, 1);
	}

	return PLUGIN_HANDLED;
}

public disband_menu(id)
{
	if (!is_user_connected(id) || mapEnd || get_user_status(id) != STATUS_LEADER || !cod_check_account(id)) return PLUGIN_HANDLED;

	new menu = menu_create("\wAre you \ysure\w you want to \rdisband\w the clan?", "disband_menu_handle");

	menu_additem(menu, "Yes", "0");
	menu_additem(menu, "No^n", "1");

	menu_setprop(menu, MPROP_EXITNAME, "Exit");

	menu_display(id, menu);

	return PLUGIN_HANDLED;
}

public disband_menu_handle(id, menu, item)
{
	if (!is_user_connected(id) || mapEnd || get_user_status(id) != STATUS_LEADER || !cod_check_account(id)) return PLUGIN_HANDLED;

	if (item == MENU_EXIT) {
		client_cmd(id, "spk %s", codSounds[SOUND_EXIT]);

		menu_destroy(menu);

		return PLUGIN_HANDLED;
	}

	client_cmd(id, "spk %s", codSounds[SOUND_SELECT]);

	switch (item) {
		case 0: {
			cod_print_chat(id, "You disbanded your clan.");

			remove_clan(id);

			show_clan_menu(id, 1);
		}
		case 1: show_clan_menu(id, 1);
	}

	menu_destroy(menu);

	return PLUGIN_HANDLED;
}

public skills_menu(id)
{
	if (!is_user_connected(id) || mapEnd || get_user_status(id) < STATUS_DEPUTY || !cod_check_account(id)) return PLUGIN_HANDLED;

	new codClan[clanInfo], menuData[128];

	ArrayGetArray(codClans, get_clan_id(clan[id]), codClan);

	formatex(menuData, charsmax(menuData), "\ySkills \rMenu^n\wClan Honor: \y%i", codClan[CLAN_HONOR]);

	new menu = menu_create(menuData, "skills_menu_handle");

	formatex(menuData, charsmax(menuData), "Clan Level \w[\rLevel: \y%i/%i\w] [\rCost: \y%i Honor\w]", codClan[CLAN_LEVEL], cvarLevelMax, cvarLevelCost + cvarNextLevelCost * codClan[CLAN_LEVEL]);
	menu_additem(menu, menuData);

	formatex(menuData, charsmax(menuData), "Health \w[\rLevel: \y%i/%i\w] [\rCost: \y%i Honor\w]", codClan[CLAN_HEALTH], cvarSkillMax, cvarSkillCost + cvarNextSkillCost * codClan[CLAN_HEALTH]);
	menu_additem(menu, menuData);

	formatex(menuData, charsmax(menuData), "Gravity \w[\rLevel: \y%i/%i\w] [\rCost: \y%i Honor\w]", codClan[CLAN_GRAVITY], cvarSkillMax, cvarSkillCost + cvarNextSkillCost * codClan[CLAN_GRAVITY]);
	menu_additem(menu, menuData);

	formatex(menuData, charsmax(menuData), "Damage \w[\rLevel: \y%i/%i\w] [\rCost: \y%i Honor\w]", codClan[CLAN_DAMAGE], cvarSkillMax, cvarSkillCost + cvarNextSkillCost * codClan[CLAN_DAMAGE]);
	menu_additem(menu, menuData);

	formatex(menuData, charsmax(menuData), "Experience \w[\rLevel: \y%i/%i\w] [\rCost: \y%i Honor\w]", codClan[CLAN_EXP], cvarSkillMax, cvarSkillCost + cvarNextSkillCost * codClan[CLAN_EXP]);
	menu_additem(menu, menuData);

	menu_setprop(menu, MPROP_BACKNAME, "Back");
	menu_setprop(menu, MPROP_NEXTNAME, "Next");
	menu_setprop(menu, MPROP_EXITNAME, "Exit");

	menu_display(id, menu);

	return PLUGIN_HANDLED;
}

public skills_menu_handle(id, menu, item)
{
	if (!is_user_connected(id) || mapEnd || get_user_status(id) < STATUS_DEPUTY || !cod_check_account(id)) return PLUGIN_HANDLED;

	if (item == MENU_EXIT) {
		client_cmd(id, "spk %s", codSounds[SOUND_EXIT]);

		menu_destroy(menu);

		show_clan_menu(id, 1);

		return PLUGIN_HANDLED;
	}

	client_cmd(id, "spk %s", codSounds[SOUND_SELECT]);

	new codClan[clanInfo], upgradedSkill;

	ArrayGetArray(codClans, get_clan_id(clan[id]), codClan);

	menu_destroy(menu);

	switch (item) {
		case 0: {
			if (codClan[CLAN_LEVEL] == cvarLevelMax) {
				cod_print_chat(id, "Your clan is already at the maximum Level.");

				skills_menu(id);

				return PLUGIN_HANDLED;
			}

			new remainingHonor = codClan[CLAN_HONOR] - (cvarLevelCost + cvarNextLevelCost * codClan[CLAN_LEVEL]);

			if (remainingHonor < 0) {
				cod_print_chat(id, "Your clan doesn't have enough Honor.");

				skills_menu(id);

				return PLUGIN_HANDLED;
			}

			upgradedSkill = CLAN_LEVEL;

			codClan[CLAN_LEVEL]++;
			codClan[CLAN_HONOR] = remainingHonor;

			cod_print_chat(id, "You upgraded the clan to^x03 Level %i^x01!", codClan[CLAN_LEVEL]);
		} case 1: {
			if (codClan[CLAN_HEALTH] == cvarSkillMax) {
				cod_print_chat(id, "Your clan already has the maximum level of this skill.");

				skills_menu(id);

				return PLUGIN_HANDLED;
			}

			new remainingHonor = codClan[CLAN_HONOR] - (cvarSkillCost + cvarNextSkillCost * codClan[CLAN_HEALTH]);

			if (remainingHonor < 0) {
				cod_print_chat(id, "Your clan doesn't have enough Honor.");

				skills_menu(id);

				return PLUGIN_HANDLED;
			}

			upgradedSkill = CLAN_HEALTH;

			codClan[CLAN_HEALTH]++;
			codClan[CLAN_HONOR] = remainingHonor;

			cod_add_user_bonus_health(id, cvarHealthPerLevel);

			cod_print_chat(id, "You upgraded the^x03 Health^x01 skill to level^x03 %i^x01!", codClan[CLAN_HEALTH]);
		} case 2: {
			if (codClan[CLAN_GRAVITY] == cvarSkillMax) {
				cod_print_chat(id, "Your clan already has the maximum level of this skill.");

				skills_menu(id);

				return PLUGIN_HANDLED;
			}

			new remainingHonor = codClan[CLAN_HONOR] - (cvarSkillCost + cvarNextSkillCost * codClan[CLAN_GRAVITY]);

			if (remainingHonor < 0) {
				cod_print_chat(id, "Your clan doesn't have enough Honor.");

				skills_menu(id);

				return PLUGIN_HANDLED;
			}

			upgradedSkill = CLAN_GRAVITY;

			codClan[CLAN_GRAVITY]++;
			codClan[CLAN_HONOR] = remainingHonor;

			cod_print_chat(id, "You upgraded the^x03 Gravity^x01 skill to level^x03 %i^x01!", codClan[CLAN_GRAVITY]);
		} case 3: {
			if (codClan[CLAN_DAMAGE] == cvarSkillMax) {
				cod_print_chat(id, "Your clan already has the maximum level of this skill.");

				skills_menu(id);

				return PLUGIN_HANDLED;
			}

			new remainingHonor = codClan[CLAN_HONOR] - (cvarSkillCost + cvarNextSkillCost * codClan[CLAN_DAMAGE]);

			if (remainingHonor < 0) {
				cod_print_chat(id, "Your clan doesn't have enough Honor.");

				skills_menu(id);

				return PLUGIN_HANDLED;
			}

			upgradedSkill = CLAN_DAMAGE;

			codClan[CLAN_DAMAGE]++;
			codClan[CLAN_HONOR] = remainingHonor;

			cod_print_chat(id, "You upgraded the^x03 Damage^x01 skill to level^x03 %i^x01!", codClan[CLAN_DAMAGE]);
		} case 4: {
			if (codClan[CLAN_EXP] == cvarSkillMax) {
				cod_print_chat(id, "Your clan already has the maximum level of this skill.");

				skills_menu(id);

				return PLUGIN_HANDLED;
			}

			new remainingHonor = codClan[CLAN_HONOR] - (cvarSkillCost + cvarNextSkillCost * codClan[CLAN_EXP]);

			if (remainingHonor < 0) {
				cod_print_chat(id, "Your clan doesn't have enough Honor.");

				skills_menu(id);

				return PLUGIN_HANDLED;
			}

			upgradedSkill = CLAN_EXP;

			codClan[CLAN_EXP]++;
			codClan[CLAN_HONOR] = remainingHonor;

			cod_print_chat(id, "You upgraded the^x03 Experience^x01 skill to level^x03 %i^x01!", codClan[CLAN_EXP]);
		}
	}

	ArraySetArray(codClans, get_clan_id(clan[id]), codClan);

	save_clan(get_clan_id(clan[id]));

	new name[MAX_NAME];

	get_user_name(id, name, charsmax(name));

	for (new player = 1; player <= MAX_PLAYERS; player++) {
		if (!is_user_connected(id) || player == id || clan[player] != clan[id]) continue;

		cod_add_user_bonus_health(player, cvarHealthPerLevel);

		cod_print_chat(player, "^x03 %s^x01 upgraded the clan to^x03 Level %i^x01!", name, codClan[upgradedSkill]);
	}

	skills_menu(id);

	return PLUGIN_HANDLED;
}

public invite_menu(id)
{
	if (!is_user_connected(id) || mapEnd || get_user_status(id) < STATUS_DEPUTY || !cod_check_account(id)) return PLUGIN_HANDLED;

	new userName[MAX_NAME], userId[6], playersAvailable = 0;

	new menu = menu_create("\ySelect a \rPlayer \yto invite:", "invite_menu_handle");

	for (new player = 1; player <= MAX_PLAYERS; player++) {
		if (!is_user_connected(player) || is_user_hltv(player) || is_user_bot(id) || player == id || clan[player]) continue;

		playersAvailable++;

		get_user_name(player, userName, charsmax(userName));

		num_to_str(player, userId, charsmax(userId));

		menu_additem(menu, userName, userId);
	}

	if (!playersAvailable) cod_print_chat(id, "There is no player on the server you could invite!");
	else menu_display(id, menu);

	return PLUGIN_HANDLED;
}

public invite_menu_handle(id, menu, item)
{
	if (!is_user_connected(id) || mapEnd || get_user_status(id) < STATUS_DEPUTY || !cod_check_account(id)) return PLUGIN_HANDLED;

	if (item == MENU_EXIT) {
		client_cmd(id, "spk %s", codSounds[SOUND_EXIT]);

		show_clan_menu(id, 1);

		menu_destroy(menu);

		return PLUGIN_HANDLED;
	}

	client_cmd(id, "spk %s", codSounds[SOUND_SELECT]);

	new userName[MAX_NAME], itemData[6], itemAccess, itemCallback;

	menu_item_getinfo(menu, item, itemAccess, itemData, charsmax(itemData), userName, charsmax(userName), itemCallback);

	new player = str_to_num(itemData);

	if (!is_user_connected(player)) {
		cod_print_chat(id, "The selected player is no longer on the server.");

		return PLUGIN_HANDLED;
	}

	invite_confirm_menu(id, player);

	cod_print_chat(id, "You invited^x03 %s^x01 to your clan.", userName);

	show_clan_menu(id, 1);

	return PLUGIN_HANDLED;
}

public invite_confirm_menu(id, player)
{
	if (!is_user_connected(id) || !is_user_connected(player) || mapEnd || get_user_status(id) < STATUS_DEPUTY || !cod_check_account(id)) return PLUGIN_HANDLED;

	client_cmd(player, "spk %s", codSounds[SOUND_SELECT]);

	new menuData[128], clanName[MAX_NAME], userName[MAX_NAME], userId[6];

	get_user_name(id, userName, charsmax(userName));

	get_clan_info(clan[id], CLAN_NAME, clanName, charsmax(clanName));

	formatex(menuData, charsmax(menuData), "\r%s\w invited you to the clan \y%s\w.", userName, clanName);

	new menu = menu_create(menuData, "invite_confirm_menu_handle");

	num_to_str(id, userId, charsmax(userId));

	menu_additem(menu, "Join", userId);
	menu_additem(menu, "Decline");

	menu_display(player, menu);

	return PLUGIN_HANDLED;
}

public invite_confirm_menu_handle(id, menu, item)
{
	if (!is_user_connected(id) || mapEnd || !cod_check_account(id)) return PLUGIN_HANDLED;

	if (item == MENU_EXIT || item) {
		client_cmd(id, "spk %s", codSounds[SOUND_EXIT]);

		menu_destroy(menu);

		return PLUGIN_HANDLED;
	}

	new itemData[6], itemAccess, itemCallback;

	menu_item_getinfo(menu, item, itemAccess, itemData, charsmax(itemData), _, _, itemCallback);

	new player = str_to_num(itemData);

	if (!is_user_connected(id)) {
		cod_print_chat(id, "The player who invited you is no longer on the server.");

		return PLUGIN_HANDLED;
	}

	client_cmd(player, "spk %s", codSounds[SOUND_SELECT]);

	if (clan[id]) {
		cod_print_chat(id, "You can't join a clan if you already belong to another one.");

		return PLUGIN_HANDLED;
	}

	if (((get_clan_info(clan[player], CLAN_LEVEL) * cvarMembersPerLevel) + cvarMembersStart) <= get_clan_info(clan[player], CLAN_MEMBERS)) {
		cod_print_chat(id, "Unfortunately, there are no free slots left in this clan.");

		return PLUGIN_HANDLED;
	}

	new clanName[MAX_NAME];

	get_clan_info(clan[player], CLAN_NAME, clanName, charsmax(clanName));

	set_user_clan(id, clan[player]);

	cod_print_chat(id, "You joined the clan^x03 %s^01.", clanName);

	return PLUGIN_HANDLED;
}

public change_name_handle(id)
{
	if (!is_user_connected(id) || mapEnd || get_user_status(id) != STATUS_LEADER || !cod_check_account(id)) return PLUGIN_HANDLED;

	client_cmd(id, "spk %s", codSounds[SOUND_EXIT]);

	new clanName[MAX_NAME];

	read_args(clanName, charsmax(clanName));
	remove_quotes(clanName);
	trim(clanName);

	if (equal(clanName, "")) {
		cod_print_chat(id, "No new clan name was entered.");

		show_clan_menu(id, 1);

		return PLUGIN_HANDLED;
	}

	if (strlen(clanName) < 3) {
		cod_print_chat(id, "The clan name must be at least 3 characters long.");

		show_clan_menu(id, 1);

		return PLUGIN_HANDLED;
	}

	if (check_clan_name(clanName)) {
		cod_print_chat(id, "A clan with that name already exists.");

		show_clan_menu(id, 1);

		return PLUGIN_HANDLED;
	}

	if (cvarNameChangeFee && get_clan_honor(clan[id]) < cvarNameChangeFee) {
		cod_print_chat(id, "The clan bank doesn't have enough honor to pay for the name change (^x04Requires %i Honor^x01).", cvarNameChangeFee);

		show_clan_menu(id, 1);

		return PLUGIN_HANDLED;
	}

	set_clan_info(clan[id], CLAN_HONOR, -cvarNameChangeFee);

	update_clan_name(clan[id], clanName, charsmax(clanName));

	cod_print_chat(id, "You changed the clan name to^x03 %s^x01.", clanName);

	return PLUGIN_CONTINUE;
}

public members_menu(id)
{
	if (!is_user_connected(id) || !clan[id]) return PLUGIN_HANDLED;

	new queryData[128], tempId[1];

	tempId[0] = id;

	formatex(queryData, charsmax(queryData), "SELECT * FROM `cod_clans_members` WHERE clan = '%i' ORDER BY flag DESC", clan[id]);

	SQL_ThreadQuery(sql, "members_menu_handle", queryData, tempId, sizeof(tempId));

	return PLUGIN_HANDLED;
}

public members_menu_handle(failState, Handle:query, error[], errorNum, tempId[], dataSize)
{
	if (failState) {
		if (failState == TQUERY_CONNECT_FAILED) cod_log_error(PLUGIN, "Could not connect to SQL database. Error: %s (%d)", error, errorNum);
		else if (failState == TQUERY_QUERY_FAILED) cod_log_error(PLUGIN, "Threaded query failed. Error: %s (%d)", error, errorNum);

		return PLUGIN_HANDLED;
	}

	new id = tempId[0];

	if (!is_user_connected(id) || mapEnd || get_user_status(id) < STATUS_DEPUTY || !cod_check_account(id)) return PLUGIN_HANDLED;

	new itemData[96], userName[MAX_NAME], status, menu = menu_create("\yManage \rMembers:^n\wSelect a \ymember\w to show available options.", "member_menu_handle");

	while (SQL_MoreResults(query)) {
		SQL_ReadResult(query, SQL_FieldNameToNum(query, "name"), userName, charsmax(userName));

		status = SQL_ReadResult(query, SQL_FieldNameToNum(query, "flag"));

		formatex(itemData, charsmax(itemData), "%s#%i", userName, status);

		switch (status) {
			case STATUS_MEMBER: add(userName, charsmax(userName), " \y[Member]");
			case STATUS_DEPUTY: add(userName, charsmax(userName), " \y[Deputy]");
			case STATUS_LEADER: add(userName, charsmax(userName), " \y[Leader]");
		}

		menu_additem(menu, userName, itemData);

		SQL_NextRow(query);
	}

	menu_setprop(menu, MPROP_BACKNAME, "Back");
	menu_setprop(menu, MPROP_NEXTNAME, "Next");
	menu_setprop(menu, MPROP_EXITNAME, "Exit");

	menu_display(id, menu);

	return PLUGIN_HANDLED;
}

public member_menu_handle(id, menu, item)
{
	if (!is_user_connected(id) || mapEnd || get_user_status(id) < STATUS_DEPUTY || !cod_check_account(id)) return PLUGIN_HANDLED;

	if (item == MENU_EXIT) {
		client_cmd(id, "spk %s", codSounds[SOUND_EXIT]);

		menu_destroy(menu);

		return PLUGIN_HANDLED;
	}

	client_cmd(id, "spk %s", codSounds[SOUND_SELECT]);

	new itemData[MAX_NAME], userName[MAX_NAME], tempFlag[6], itemAccess, itemCallback;

	menu_item_getinfo(menu, item, itemAccess, itemData, charsmax(itemData), _, _, itemCallback);

	menu_destroy(menu);

	strtok(itemData, userName, charsmax(userName), tempFlag, charsmax(tempFlag), '#');

	new flag = str_to_num(tempFlag), userId = get_user_index(userName);

	if (userId == id) {
		cod_print_chat(id, "You can't manage yourself!");

		members_menu(id);

		return PLUGIN_HANDLED;
	}

	if (clan[userId]) chosenId[id] = get_user_userid(userId);

	if (flag == STATUS_LEADER) {
		cod_print_chat(id, "You can't manage the clan leader!");

		members_menu(id);

		return PLUGIN_HANDLED;
	}

	formatex(chosenName[id], charsmax(chosenName), userName);

	new menu = menu_create("\ySelect \rOption:", "member_options_menu_handle");

	if (get_user_status(id) == STATUS_LEADER) {
		menu_additem(menu, "Transfer \yLeadership", "1");

		if (flag == STATUS_MEMBER) menu_additem(menu, "Appoint \yDeputy", "2");

		if (flag == STATUS_DEPUTY) menu_additem(menu, "Demote \yDeputy", "3");
	}

	menu_additem(menu, "Kick \yPlayer", "4");

	menu_setprop(menu, MPROP_EXITNAME, "Exit");

	menu_display(id, menu);

	return PLUGIN_CONTINUE;
}

public member_options_menu_handle(id, menu, item)
{
	if (!is_user_connected(id) || mapEnd || get_user_status(id) < STATUS_DEPUTY || !cod_check_account(id)) return PLUGIN_HANDLED;

	if (item == MENU_EXIT) {
		client_cmd(id, "spk %s", codSounds[SOUND_EXIT]);

		show_clan_menu(id, 1);

		menu_destroy(menu);

		return PLUGIN_HANDLED;
	}

	client_cmd(id, "spk %s", codSounds[SOUND_SELECT]);

	new itemData[6], itemAccess, itemCallback;

	menu_item_getinfo(menu, item, itemAccess, itemData, charsmax(itemData), _, _, itemCallback);

	switch (str_to_num(itemData)) {
		case 1: update_member(id, STATUS_LEADER);
		case 2:	update_member(id, STATUS_DEPUTY);
		case 3:	update_member(id, STATUS_MEMBER);
		case 4: update_member(id, STATUS_NONE);
	}

	menu_destroy(menu);

	return PLUGIN_CONTINUE;
}

public update_member(id, status)
{
	if (!is_user_connected(id) || mapEnd || !clan[id] || !cod_check_account(id)) return PLUGIN_HANDLED;

	new bool:playerOnline;

	for (new player = 1; player <= MAX_PLAYERS; player++) {
		if (!is_user_connected(player) || clan[player] != clan[id]) continue;

		if (get_user_userid(player) == chosenId[id]) {
			switch (status) {
				case STATUS_LEADER: {
					set_user_status(id, STATUS_DEPUTY);
					set_user_status(player, STATUS_LEADER);

					cod_print_chat(player, "You have been appointed clan leader!");
				} case STATUS_DEPUTY: {
					set_user_status(player, STATUS_DEPUTY);

					cod_print_chat(player, "You have become the clan's deputy leader!");
				} case STATUS_MEMBER: {
					set_user_status(player, STATUS_MEMBER);

					cod_print_chat(player,  "You have been demoted to clan member.");
				} case STATUS_NONE: {
					set_user_clan(player);

					cod_print_chat(player, "You have been kicked from the clan.");
				}
			}

			playerOnline = true;

			continue;
		}

		switch (status) {
			case STATUS_LEADER: cod_print_chat(player, "^x03 %s^01 is the new clan leader.", chosenName[id]);
			case STATUS_DEPUTY: cod_print_chat(player, "^x03 %s^x01 has become the clan's deputy leader.", chosenName[id]);
			case STATUS_MEMBER: cod_print_chat(player, "^x03 %s^x01 has been demoted to clan member.", chosenName[id]);
			case STATUS_NONE: cod_print_chat(player, "^x03 %s^01 has been kicked from the clan.", chosenName[id]);
		}
	}

	if (!playerOnline) {
		save_member(id, status, _, chosenName[id]);

		if (status == STATUS_NONE) set_clan_info(clan[id], CLAN_MEMBERS, -1);
		if (status == STATUS_LEADER) set_user_status(id, STATUS_DEPUTY);
	}

	show_clan_menu(id, 1);

	return PLUGIN_HANDLED;
}

public applications_menu(id)
{
	if (!is_user_connected(id) || mapEnd || !clan[id] || !cod_check_account(id)) return PLUGIN_HANDLED;

	new queryData[256], tempId[1];

	tempId[0] = id;

	formatex(queryData, charsmax(queryData), "SELECT a.name, (SELECT level FROM `cod_mod` WHERE name = a.name ORDER BY level DESC LIMIT 1) as level, (SELECT honor FROM `cod_honor` WHERE name = a.name) as honor FROM `cod_clans_applications` a WHERE clan = '%i'", clan[id]);

	SQL_ThreadQuery(sql, "applications_menu_handle", queryData, tempId, sizeof(tempId));

	return PLUGIN_HANDLED;
}

public applications_menu_handle(failState, Handle:query, error[], errorNum, tempId[], dataSize)
{
	if (failState) {
		if (failState == TQUERY_CONNECT_FAILED) cod_log_error(PLUGIN, "Could not connect to SQL database. Error: %s (%d)", error, errorNum);
		else if (failState == TQUERY_QUERY_FAILED) cod_log_error(PLUGIN, "Threaded query failed. Error: %s (%d)", error, errorNum);

		return PLUGIN_HANDLED;
	}

	new id = tempId[0];

	if (!is_user_connected(id) || mapEnd || get_user_status(id) < STATUS_DEPUTY || !cod_check_account(id)) return PLUGIN_HANDLED;

	new itemName[128], userName[MAX_NAME], level, honor, usersCount = 0, menu = menu_create("\yReview \rApplications:^n\wSelect an \rapplication\w to \yaccept\w or \yreject\w it.", "applications_confirm_menu");

	while (SQL_MoreResults(query)) {
		SQL_ReadResult(query, SQL_FieldNameToNum(query, "name"), userName, charsmax(userName));

		level = SQL_ReadResult(query, SQL_FieldNameToNum(query, "level"));
		honor = SQL_ReadResult(query, SQL_FieldNameToNum(query, "honor"));

		formatex(itemName, charsmax(itemName), "\w%s \y(Highest level: \r%i\y | Honor: \r%i\y)", userName, level, honor);

		menu_additem(menu, itemName, userName);

		SQL_NextRow(query);

		usersCount++;
	}

	menu_setprop(menu, MPROP_BACKNAME, "Back");
	menu_setprop(menu, MPROP_NEXTNAME, "Next");
	menu_setprop(menu, MPROP_EXITNAME, "Exit");

	if (!usersCount) {
		menu_destroy(menu);

		cod_print_chat(id, "There are no pending applications to the clan!");
	} else menu_display(id, menu);

	return PLUGIN_HANDLED;
}

public applications_confirm_menu(id, menu, item)
{
	if (!is_user_connected(id) || mapEnd || get_user_status(id) < STATUS_DEPUTY || !cod_check_account(id)) return PLUGIN_HANDLED;

	if (item == MENU_EXIT) {
		client_cmd(id, "spk %s", codSounds[SOUND_EXIT]);

		menu_destroy(menu);

		return PLUGIN_HANDLED;
	}

	client_cmd(id, "spk %s", codSounds[SOUND_SELECT]);

	new menuData[128], userName[MAX_NAME], itemAccess, itemCallback;

	menu_item_getinfo(menu, item, itemAccess, userName, charsmax(userName), _, _, itemCallback);

	menu_destroy(menu);

	formatex(menuData, charsmax(menuData), "\wWhat do you want to do with the application of \y%s\w?", userName);

	new menu = menu_create(menuData, "applications_confirm_handle");

	if (cvarJoinFee) {
		formatex(menuData, charsmax(menuData), "Accept - \rEntry fee of %i honor from the clan bank", cvarJoinFee);

		menu_additem(menu, menuData, userName);

		formatex(menuData, charsmax(menuData), "Accept - \rEntry fee of %i honor from the player's account", cvarJoinFee);

		menu_additem(menu, menuData, userName);
	} else {
		menu_additem(menu, "Accept", userName);
	}

	menu_additem(menu, "Reject", userName);

	menu_setprop(menu, MPROP_EXITNAME, "Exit");

	menu_display(id, menu);

	return PLUGIN_CONTINUE;
}

public applications_confirm_handle(id, menu, item)
{
	if (!is_user_connected(id) || mapEnd) return PLUGIN_HANDLED;

	if (item == MENU_EXIT) {
		client_cmd(id, "spk %s", codSounds[SOUND_EXIT]);

		menu_destroy(menu);

		return PLUGIN_HANDLED;
	}

	new userName[MAX_NAME], itemAccess, itemCallback;

	menu_item_getinfo(menu, item, itemAccess, userName, charsmax(userName), _, _, itemCallback);

	menu_destroy(menu);

	client_cmd(id, "spk %s", codSounds[SOUND_SELECT]);

	if (item == 2) {
		remove_application(id, userName);

		cod_print_chat(id, "You rejected^x03 %s^01's application to join the clan.", userName);

		return PLUGIN_HANDLED;
	}

	if (check_user_clan(userName)) {
		cod_print_chat(id, "The player has already joined another clan!");

		show_clan_menu(id, 1);

		return PLUGIN_HANDLED;
	}

	if (((get_clan_info(clan[id], CLAN_LEVEL) * cvarMembersPerLevel) + cvarMembersStart) <= get_clan_info(clan[id], CLAN_MEMBERS)) {
		cod_print_chat(id, "The clan has reached its current maximum number of members!");

		return PLUGIN_HANDLED;
	}

	if (cvarJoinFee) {
		if (!item) {
			if (get_clan_honor(clan[id]) < cvarJoinFee) {
				cod_print_chat(id, "The clan bank doesn't have enough honor for the entry fee (^x04Requires %i Honor^x01).", cvarJoinFee);

				return PLUGIN_HANDLED;
			}

			set_clan_info(clan[id], CLAN_HONOR, -cvarJoinFee);
		} else {
			new userId = get_user_index(userName);

			if (is_user_connected(userId)) {
				if (cod_get_user_honor(id) < cvarJoinFee) {
					cod_print_chat(id, "The player doesn't have enough honor for the entry fee (^x04Requires %i Honor^x01).", cvarJoinFee);

					return PLUGIN_HANDLED;
				}

				cod_add_user_honor(id, -cvarJoinFee);
			} else {
				new queryData[128], error[128], safeName[64], Handle:query, honor, errorNum;

				cod_sql_string(userName, safeName, charsmax(safeName));

				formatex(queryData, charsmax(queryData), "SELECT honor FROM `cod_honor` WHERE `name` = ^"%s^"", safeName);

				query = SQL_PrepareQuery(connection, queryData);

				if (SQL_Execute(query)) {
					if (SQL_MoreResults(query)) honor = SQL_ReadResult(query, SQL_FieldNameToNum(query, "honor"));
				} else {
					errorNum = SQL_QueryError(query, error, charsmax(error));

					cod_log_error(PLUGIN, "SQL Query Error. [%d] %s", errorNum, error);
				}

				SQL_FreeHandle(query);

				if (honor < cvarJoinFee) {
					cod_print_chat(id, "The player doesn't have enough honor for the entry fee (^x04Requires %i Honor^x01).", cvarJoinFee);

					return PLUGIN_HANDLED;
				}

				formatex(queryData, charsmax(queryData), "UPDATE `cod_honor` SET honor = honor - %i WHERE `name` = ^"%s^"", cvarJoinFee, safeName);

				query = SQL_PrepareQuery(connection, queryData);

				if (!SQL_Execute(query)) {
					errorNum = SQL_QueryError(query, error, charsmax(error));

					cod_log_error(PLUGIN, "SQL Query Error. [%d] %s", errorNum, error);
				}

				SQL_FreeHandle(query);
			}
		}
	}

	accept_application(id, userName);

	cod_print_chat(id, "You accepted^x03 %s^01's application to join the clan.", userName);

	return PLUGIN_HANDLED;
}

public wars_menu(id)
{
	if (!is_user_connected(id) || !clan[id] || !cod_check_account(id) || mapEnd) return PLUGIN_HANDLED;

	new menu = menu_create("\yClan \rWars\w", "wars_menu_handle"), callback = menu_makecallback("wars_menu_callback");

	menu_additem(menu, "War \yList", _, _, callback);
	menu_additem(menu, "Declare \yWar", _, _, callback);
	menu_additem(menu, "Accept / Reject \yWar", _, _, callback);
	menu_additem(menu, "Cancel \yWar", _, _, callback);

	menu_setprop(menu, MPROP_EXITNAME, "Exit");

	menu_display(id, menu);

	return PLUGIN_HANDLED;
}

public wars_menu_callback(id, menu, item)
{
	switch (item) {
		case 0: return get_wars_count(clan[id], 1) ? ITEM_ENABLED : ITEM_DISABLED;
		case 2: return get_wars_count(clan[id], 0) ? ITEM_ENABLED : ITEM_DISABLED;
		case 3: return get_wars_count(clan[id], 0, 1) ? ITEM_ENABLED : ITEM_DISABLED;
	}

	return ITEM_ENABLED;
}

public wars_menu_handle(id, menu, item)
{
	if (!is_user_connected(id) || mapEnd) return PLUGIN_HANDLED;

	if (item == MENU_EXIT) {
		client_cmd(id, "spk %s", codSounds[SOUND_EXIT]);

		menu_destroy(menu);

		return PLUGIN_HANDLED;
	}

	client_cmd(id, "spk %s", codSounds[SOUND_SELECT]);

	switch(item) {
		case 0: war_list_menu(id);
		case 1: declare_war_menu(id);
		case 2: accept_war_menu(id);
		case 3: remove_war_menu(id);
	}

	return PLUGIN_HANDLED;
}

public war_list_menu(id)
{
	if (!is_user_connected(id) || !clan[id] || !cod_check_account(id) || mapEnd) return PLUGIN_HANDLED;

	new queryData[256], tempId[1];

	tempId[0] = id;

	formatex(queryData, charsmax(queryData), "SELECT a.*, (SELECT name FROM `cod_clans` WHERE id = a.clan) as name, (SELECT name FROM `cod_clans` WHERE id = a.clan2) as name2 FROM `cod_clans_wars` a WHERE (clan = '%i' OR clan2 = '%i') AND started = '1'", clan[id], clan[id]);

	SQL_ThreadQuery(sql, "show_war_list_menu", queryData, tempId, sizeof(tempId));

	return PLUGIN_HANDLED;
}

public show_war_list_menu(failState, Handle:query, error[], errorNum, tempId[], dataSize)
{
	if (failState) {
		if (failState == TQUERY_CONNECT_FAILED) cod_log_error(PLUGIN, "Could not connect to SQL database. Error: %s (%d)", error, errorNum);
		else if (failState == TQUERY_QUERY_FAILED) cod_log_error(PLUGIN, "Threaded query failed. Error: %s (%d)", error, errorNum);

		return PLUGIN_HANDLED;
	}

	new id = tempId[0];

	if (!is_user_connected(id)) return PLUGIN_HANDLED;

	new itemName[128], clanName[2][MAX_NAME], progress[2], warsCount = 0, clanId, ownClan, enemyClan, duration, reward, menu = menu_create("\yWar \rList\w:", "show_war_list_menu_handle");

	while (SQL_MoreResults(query)) {
		clanId = SQL_ReadResult(query, SQL_FieldNameToNum(query, "clan"));

		if (clanId == clan[id]) {
			ownClan = 0;
			enemyClan = 1;
		} else {
			ownClan = 1;
			enemyClan = 0;
		}

		SQL_ReadResult(query, SQL_FieldNameToNum(query, "name"), clanName[0], charsmax(clanName[]));
		SQL_ReadResult(query, SQL_FieldNameToNum(query, "name2"), clanName[1], charsmax(clanName[]));

		progress[0] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "progress"));
		progress[1] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "progress2"));

		duration = SQL_ReadResult(query, SQL_FieldNameToNum(query, "duration"));
		reward = SQL_ReadResult(query, SQL_FieldNameToNum(query, "reward"));

		formatex(itemName, charsmax(itemName), "\w%s \y(\r%i\y) \rvs \w%s \y(\r%i\y) (Frags: \r%i\y | Reward: \r%i Honor\y)", clanName[ownClan], progress[ownClan], clanName[enemyClan], progress[enemyClan], duration, reward);

		menu_additem(menu, itemName);

		SQL_NextRow(query);

		warsCount++;
	}

	menu_setprop(menu, MPROP_PERPAGE, 6);
	menu_setprop(menu, MPROP_BACKNAME, "Back");
	menu_setprop(menu, MPROP_NEXTNAME, "Next");
	menu_setprop(menu, MPROP_EXITNAME, "Exit");

	if (!warsCount) {
		menu_destroy(menu);

		cod_print_chat(id, "Your clan is not currently in any wars!");
	} else menu_display(id, menu);

	return PLUGIN_HANDLED;
}

public show_war_list_menu_handle(id, menu, item)
{
	if (!is_user_connected(id) || mapEnd) return PLUGIN_HANDLED;

	menu_destroy(menu);

	if (item == MENU_EXIT) {
		client_cmd(id, "spk %s", codSounds[SOUND_EXIT]);

		return PLUGIN_HANDLED;
	}

	client_cmd(id, "spk %s", codSounds[SOUND_SELECT]);

	wars_menu(id);

	return PLUGIN_HANDLED;
}

public declare_war_menu(id)
{
	if (!is_user_connected(id) || !clan[id] || !cod_check_account(id) || mapEnd) return PLUGIN_HANDLED;

	new itemData[64], menu = menu_create("\ySet \rwar\y parameters\w:", "declare_war_menu_handle");

	formatex(itemData, charsmax(itemData), "Number of \rFrags\w: \y%i", warFrags[id]);
	menu_additem(menu, itemData);

	formatex(itemData, charsmax(itemData), "Reward \rAmount\w: \y%i Honor^n", warReward[id]);
	menu_additem(menu, itemData);

	menu_addtext(menu, "\wSelect one of the \rparameters\w above to change its \yvalue\w.^nThe clan you declare war on must \raccept\w it for it to start.^nWhen the war starts, \yhalf of the reward\w is taken from each clan's bank.^nWhen it ends, the winning clan receives \ythe whole reward\w.^n", 0);

	menu_additem(menu, "Declare \rWar");

	menu_setprop(menu, MPROP_EXITNAME, "Exit");

	menu_display(id, menu);

	return PLUGIN_HANDLED;
}

public declare_war_menu_handle(id, menu, item)
{
	if (!is_user_connected(id) || mapEnd) return PLUGIN_HANDLED;

	menu_destroy(menu);

	if (item == MENU_EXIT) {
		client_cmd(id, "spk %s", codSounds[SOUND_EXIT]);

		return PLUGIN_HANDLED;
	}

	client_cmd(id, "spk %s", codSounds[SOUND_SELECT]);

	switch (item) {
		case 0: client_cmd(id, "messagemode ENTER_FRAG_COUNT");
		case 1: client_cmd(id, "messagemode ENTER_REWARD_AMOUNT");
		case 2: {
			new queryData[512], tempId[1];

			tempId[0] = id;

			formatex(queryData, charsmax(queryData), "SELECT a.id, a.name, a.honor, (SELECT COUNT(clan) FROM `cod_clans_members` \
				WHERE clan = a.id) as members FROM `cod_clans` a WHERE id != '%i' AND NOT EXISTS (SELECT id FROM `cod_clans_wars` \
				WHERE (clan = '%i' AND clan2 = a.id) OR (clan2 = '%i' AND clan = a.id)) ORDER BY a.name ASC", clan[id], clan[id], clan[id]);

			SQL_ThreadQuery(sql, "declare_war_select", queryData, tempId, sizeof(tempId));
		}
	}

	return PLUGIN_HANDLED;
}

public declare_war_select(failState, Handle:query, error[], errorNum, tempId[], dataSize)
{
	if (failState) {
		if (failState == TQUERY_CONNECT_FAILED) cod_log_error(PLUGIN, "Could not connect to SQL database. Error: %s (%d)", error, errorNum);
		else if (failState == TQUERY_QUERY_FAILED) cod_log_error(PLUGIN, "Threaded query failed. Error: %s (%d)", error, errorNum);

		return PLUGIN_HANDLED;
	}

	new id = tempId[0];

	if (!is_user_connected(id)) return PLUGIN_HANDLED;

	new itemName[128], tempData[MAX_NAME], clanName[MAX_NAME], clansCount = 0, honor, members, clanId, menu = menu_create("\wSelect the \rclan\w you want to declare \ywar\w on:", "declare_war_confirm");

	while (SQL_MoreResults(query)) {
		clanId = SQL_ReadResult(query, SQL_FieldNameToNum(query, "id"));

		if (!clanId) {
			SQL_NextRow(query);

			continue;
		}

		members = SQL_ReadResult(query, SQL_FieldNameToNum(query, "members"));
		honor = SQL_ReadResult(query, SQL_FieldNameToNum(query, "honor"));

		SQL_ReadResult(query, SQL_FieldNameToNum(query, "name"), clanName, charsmax(clanName));

		formatex(tempData, charsmax(tempData), "%s#%i", clanName, clanId);
		formatex(itemName, charsmax(itemName), "\w%s \y(Members: \r%i\y | Honor: \r%.2f\y)", clanName, members, honor);

		menu_additem(menu, itemName, tempData);

		SQL_NextRow(query);

		clansCount++;
	}

	menu_setprop(menu, MPROP_PERPAGE, 6);
	menu_setprop(menu, MPROP_BACKNAME, "Back");
	menu_setprop(menu, MPROP_NEXTNAME, "Next");
	menu_setprop(menu, MPROP_EXITNAME, "Exit");

	if (!clansCount) {
		menu_destroy(menu);

		cod_print_chat(id, "There is no clan you could declare war on!");
	} else menu_display(id, menu);

	return PLUGIN_HANDLED;
}

public declare_war_confirm(id, menu, item)
{
	if (!is_user_connected(id) || mapEnd) return PLUGIN_HANDLED;

	if (item == MENU_EXIT) {
		client_cmd(id, "spk %s", codSounds[SOUND_EXIT]);

		menu_destroy(menu);

		return PLUGIN_HANDLED;
	}

	client_cmd(id, "spk %s", codSounds[SOUND_SELECT]);

	new tempData[192], itemData[MAX_NAME], clanName[MAX_NAME], tempClanId[6], itemAccess, menuCallback;

	menu_item_getinfo(menu, item, itemAccess, itemData, charsmax(itemData), _, _, menuCallback);

	menu_destroy(menu);

	strtok(itemData, clanName, charsmax(clanName), tempClanId, charsmax(tempClanId), '#');

	formatex(tempData, charsmax(tempData), "\yConfirm declaring war on clan \r%s\y?^n\wNumber of \rFrags\w: \y%i^n\wReward \rAmount\w: \y%i Honor", clanName, warFrags[id], warReward[id]);

	new menu = menu_create(tempData, "declare_war_confirm_handle");

	menu_additem(menu, "\yYes", itemData);
	menu_additem(menu, "No");

	menu_setprop(menu, MPROP_EXITNAME, "Exit");

	menu_display(id, menu);

	return PLUGIN_HANDLED;
}

public declare_war_confirm_handle(id, menu, item)
{
	if (!is_user_connected(id) || mapEnd) return PLUGIN_HANDLED;

	if (item == MENU_EXIT) {
		client_cmd(id, "spk %s", codSounds[SOUND_EXIT]);

		menu_destroy(menu);

		return PLUGIN_HANDLED;
	}

	if (item) {
		menu_destroy(menu);

		declare_war_menu(id);

		return PLUGIN_HANDLED;
	}

	client_cmd(id, "spk %s", codSounds[SOUND_SELECT]);

	new itemData[MAX_NAME], clanName[MAX_NAME], tempClanId[6], itemAccess, menuCallback;

	menu_item_getinfo(menu, item, itemAccess, itemData, charsmax(itemData), _, _, menuCallback);

	menu_destroy(menu);

	strtok(itemData, clanName, charsmax(clanName), tempClanId, charsmax(tempClanId), '#');

	declare_war(id, str_to_num(tempClanId));

	cod_print_chat(id, "Your clan declared war on clan^x03 %s^x01.", clanName);

	return PLUGIN_HANDLED;
}

public accept_war_menu(id)
{
	if (!is_user_connected(id) || !clan[id] || !cod_check_account(id) || mapEnd) return PLUGIN_HANDLED;

	new queryData[256], tempId[1];

	tempId[0] = id;

	formatex(queryData, charsmax(queryData), "SELECT id, clan, duration, reward, (SELECT name FROM `cod_clans` WHERE id = a.clan2) as name, (SELECT name FROM `cod_clans` WHERE id = a.clan) as name2 FROM `cod_clans_wars` a WHERE clan2 = '%i' AND started = '0'", clan[id]);

	SQL_ThreadQuery(sql, "accept_war_menu_handle", queryData, tempId, sizeof(tempId));

	return PLUGIN_HANDLED;
}

public accept_war_menu_handle(failState, Handle:query, error[], errorNum, tempId[], dataSize)
{
	if (failState) {
		if (failState == TQUERY_CONNECT_FAILED) cod_log_error(PLUGIN, "Could not connect to SQL database. Error: %s (%d)", error, errorNum);
		else if (failState == TQUERY_QUERY_FAILED) cod_log_error(PLUGIN, "Threaded query failed. Error: %s (%d)", error, errorNum);

		return PLUGIN_HANDLED;
	}

	new id = tempId[0];

	if (!is_user_connected(id)) return PLUGIN_HANDLED;

	new itemName[128], clanName[2][MAX_NAME], tempData[MAX_NAME], warsCount = 0, ownClan = 0, enemyClan = 1, warId, clanId, duration, reward, menu = menu_create("\ySelect a \rwar\y declaration\w:", "accept_war_confirm");

	while (SQL_MoreResults(query)) {
		warId = SQL_ReadResult(query, SQL_FieldNameToNum(query, "id"));
		clanId = SQL_ReadResult(query, SQL_FieldNameToNum(query, "clan"));

		SQL_ReadResult(query, SQL_FieldNameToNum(query, "name"), clanName[0], charsmax(clanName[]));
		SQL_ReadResult(query, SQL_FieldNameToNum(query, "name2"), clanName[1], charsmax(clanName[]));

		duration = SQL_ReadResult(query, SQL_FieldNameToNum(query, "duration"));
		reward = SQL_ReadResult(query, SQL_FieldNameToNum(query, "reward"));

		formatex(itemName, charsmax(itemName), "\w%s \rvs \w%s \y(Frags: \r%i\y | Reward: \r%i Honor\y)", clanName[ownClan], clanName[enemyClan], duration, reward);
		formatex(tempData, charsmax(tempData), "%s#%i#%i#%i#%i", clanName[enemyClan], clanId, warId, duration, reward);

		menu_additem(menu, itemName, tempData);

		SQL_NextRow(query);

		warsCount++;
	}

	menu_setprop(menu, MPROP_PERPAGE, 6);
	menu_setprop(menu, MPROP_BACKNAME, "Back");
	menu_setprop(menu, MPROP_NEXTNAME, "Next");
	menu_setprop(menu, MPROP_EXITNAME, "Exit");

	if (!warsCount) {
		menu_destroy(menu);

		cod_print_chat(id, "There are no war declarations to accept!");
	} else menu_display(id, menu);

	return PLUGIN_HANDLED;
}

public accept_war_confirm(id, menu, item)
{
	if (!is_user_connected(id) || mapEnd) return PLUGIN_HANDLED;

	if (item == MENU_EXIT) {
		client_cmd(id, "spk %s", codSounds[SOUND_EXIT]);

		menu_destroy(menu);

		return PLUGIN_HANDLED;
	}

	client_cmd(id, "spk %s", codSounds[SOUND_SELECT]);

	new dataParts[5][32], tempData[192], itemData[MAX_NAME], itemAccess, menuCallback;

	menu_item_getinfo(menu, item, itemAccess, itemData, charsmax(itemData), _, _, menuCallback);

	explode(itemData, '#', dataParts, sizeof(dataParts), charsmax(dataParts[]));

	formatex(tempData, charsmax(tempData), "\wWhat do you want to do with the \rwar\w declaration from clan \y%s\w?^n\wNumber of \rFrags\w: \y%s^n\wReward \rAmount\w: \y%s Honor", dataParts[0], dataParts[3], dataParts[4]);

	new menu = menu_create(tempData, "accept_war_confirm_handle");

	menu_additem(menu, "\yAccept", itemData);
	menu_additem(menu, "\rReject", itemData);

	menu_setprop(menu, MPROP_EXITNAME, "Exit");

	menu_display(id, menu);

	return PLUGIN_HANDLED;
}

public accept_war_confirm_handle(id, menu, item)
{
	if (!is_user_connected(id) || mapEnd) return PLUGIN_HANDLED;

	if (item == MENU_EXIT) {
		client_cmd(id, "spk %s", codSounds[SOUND_EXIT]);

		menu_destroy(menu);

		return PLUGIN_HANDLED;
	}

	client_cmd(id, "spk %s", codSounds[SOUND_SELECT]);

	new dataParts[5][32], itemData[96], itemAccess, menuCallback, warId;

	menu_item_getinfo(menu, item, itemAccess, itemData, charsmax(itemData), _, _, menuCallback);

	menu_destroy(menu);

	explode(itemData, '#', dataParts, sizeof(dataParts), charsmax(dataParts[]));

	warId = str_to_num(dataParts[2]);

	if (item) {
		remove_war(warId);

		wars_menu(id);

		cod_print_chat(id, "You successfully rejected the war declaration.");

		return PLUGIN_HANDLED;
	}

	new clanId = str_to_num(dataParts[1]), halfReward = str_to_num(dataParts[4]) / 2;

	if (get_clan_honor(clan[id]) < halfReward) {
		cod_print_chat(id, "The clan bank doesn't have enough^x03 Honor^x01 to cover half of the^x04 reward^x01!");

		wars_menu(id);

		return PLUGIN_HANDLED;
	}

	if (get_clan_honor(clanId) < halfReward) {
		cod_print_chat(id, "The bank of clan^x03 %s^x01 doesn't have enough^x03 Honor^x01 to cover half of the^x04 reward^x01!", dataParts[0]);

		wars_menu(id);

		return PLUGIN_HANDLED;
	}

	accept_war(id, warId, clanId, str_to_num(dataParts[3]), halfReward, dataParts[0]);

	return PLUGIN_HANDLED;
}

public remove_war_menu(id)
{
	if (!is_user_connected(id) || !clan[id] || !cod_check_account(id) || mapEnd) return PLUGIN_HANDLED;

	new queryData[256], tempId[1];

	tempId[0] = id;

	formatex(queryData, charsmax(queryData), "SELECT id, duration, reward, (SELECT name FROM `cod_clans` WHERE id = a.clan) as name, (SELECT name FROM `cod_clans` WHERE id = a.clan2) as name2 FROM `cod_clans_wars` a WHERE clan = '%i' AND started = '0'", clan[id]);

	SQL_ThreadQuery(sql, "remove_war_menu_handle", queryData, tempId, sizeof(tempId));

	return PLUGIN_HANDLED;
}

public remove_war_menu_handle(failState, Handle:query, error[], errorNum, tempId[], dataSize)
{
	if (failState) {
		if (failState == TQUERY_CONNECT_FAILED) cod_log_error(PLUGIN, "Could not connect to SQL database. Error: %s (%d)", error, errorNum);
		else if (failState == TQUERY_QUERY_FAILED) cod_log_error(PLUGIN, "Threaded query failed. Error: %s (%d)", error, errorNum);

		return PLUGIN_HANDLED;
	}

	new id = tempId[0];

	if (!is_user_connected(id)) return PLUGIN_HANDLED;

	new itemName[128], clanName[2][32], tempData[MAX_NAME], warsCount = 0, ownClan = 0, enemyClan = 1, warId, duration, reward, menu = menu_create("\ySelect a \rwar\y declaration to cancel\w:", "remove_war_confirm");

	while (SQL_MoreResults(query)) {
		warId = SQL_ReadResult(query, SQL_FieldNameToNum(query, "id"));

		SQL_ReadResult(query, SQL_FieldNameToNum(query, "name"), clanName[0], charsmax(clanName[]));
		SQL_ReadResult(query, SQL_FieldNameToNum(query, "name2"), clanName[1], charsmax(clanName[]));

		duration = SQL_ReadResult(query, SQL_FieldNameToNum(query, "duration"));
		reward = SQL_ReadResult(query, SQL_FieldNameToNum(query, "reward"));

		formatex(itemName, charsmax(itemName), "\w%s \rvs \w%s \y(Frags: \r%i\y | Reward: \r%i Honor\y)", clanName[ownClan], clanName[enemyClan], duration, reward);
		formatex(tempData, charsmax(tempData), "%s#%i#%i#%i", clanName[enemyClan], warId, duration, reward);

		menu_additem(menu, itemName, tempData);

		SQL_NextRow(query);

		warsCount++;
	}

	menu_setprop(menu, MPROP_PERPAGE, 6);
	menu_setprop(menu, MPROP_BACKNAME, "Back");
	menu_setprop(menu, MPROP_NEXTNAME, "Next");
	menu_setprop(menu, MPROP_EXITNAME, "Exit");

	if (!warsCount) {
		menu_destroy(menu);

		cod_print_chat(id, "There are no war declarations to cancel!");
	} else menu_display(id, menu);

	return PLUGIN_HANDLED;
}

public remove_war_confirm(id, menu, item)
{
	if (!is_user_connected(id) || mapEnd) return PLUGIN_HANDLED;

	if (item == MENU_EXIT) {
		client_cmd(id, "spk %s", codSounds[SOUND_EXIT]);

		menu_destroy(menu);

		return PLUGIN_HANDLED;
	}

	client_cmd(id, "spk %s", codSounds[SOUND_SELECT]);

	new dataParts[4][32], tempData[192], itemData[MAX_NAME], itemAccess, menuCallback;

	menu_item_getinfo(menu, item, itemAccess, itemData, charsmax(itemData), _, _, menuCallback);

	explode(itemData, '#', dataParts, sizeof(dataParts), charsmax(dataParts[]));

	formatex(tempData, charsmax(tempData), "\wDo you want to cancel the \rwar declaration\w with clan \y%s\w?^n\wNumber of \rFrags\w: \y%s^n\wReward \rAmount\w: \y%s Honor", dataParts[0], dataParts[2], dataParts[3]);

	new menu = menu_create(tempData, "remove_war_confirm_handle");

	menu_additem(menu, "\yYes", itemData);
	menu_additem(menu, "No");

	menu_setprop(menu, MPROP_EXITNAME, "Exit");

	menu_display(id, menu);

	return PLUGIN_HANDLED;
}

public remove_war_confirm_handle(id, menu, item)
{
	if (!is_user_connected(id) || mapEnd) return PLUGIN_HANDLED;

	if (item == MENU_EXIT) {
		client_cmd(id, "spk %s", codSounds[SOUND_EXIT]);

		menu_destroy(menu);

		return PLUGIN_HANDLED;
	}

	client_cmd(id, "spk %s", codSounds[SOUND_SELECT]);

	new dataParts[4][32], itemData[64], itemAccess, menuCallback, warId;

	menu_item_getinfo(menu, item, itemAccess, itemData, charsmax(itemData), _, _, menuCallback);

	menu_destroy(menu);

	explode(itemData, '#', dataParts, sizeof(dataParts), charsmax(dataParts[]));

	warId = str_to_num(dataParts[1]);

	if (item) {
		wars_menu(id);

		return PLUGIN_HANDLED;
	}

	if (remove_war(warId)) cod_print_chat(id, "You cancelled the war declaration with clan^x03 %s^x01.", dataParts[0]);
	else cod_print_chat(id, "The war with clan^x03 %s^x01 has already started!", dataParts[0]);

	return PLUGIN_HANDLED;
}

public deposit_honor_handle(id)
{
	if (!is_user_connected(id) || mapEnd || !clan[id] || !cod_check_account(id)) return PLUGIN_HANDLED;

	client_cmd(id, "spk %s", codSounds[SOUND_EXIT]);

	new honorData[16], honorAmount;

	read_args(honorData, charsmax(honorData));
	remove_quotes(honorData);

	honorAmount = str_to_num(honorData);

	if (honorAmount <= 0) {
		cod_print_chat(id, "You can't deposit less than^x03 1 honor^x01!");

		return PLUGIN_HANDLED;
	}

	if (cod_get_user_honor(id) < honorAmount) {
		cod_print_chat(id, "You don't have that much^x03 honor^x01!");

		return PLUGIN_HANDLED;
	}

	cod_add_user_honor(id, -honorAmount);

	set_clan_info(clan[id], CLAN_HONOR, honorAmount);

	add_deposited_honor(id, honorAmount);

	cod_print_chat(id, "You deposited^x03 %i^x01 Honor to the clan.", honorAmount);
	cod_print_chat(id, "Your clan now has^x03 %i^x01 Honor.", get_clan_info(clan[id], CLAN_HONOR));

	return PLUGIN_HANDLED;
}

public set_war_frags_handle(id)
{
	if (!is_user_connected(id) || !clan[id] || !cod_check_account(id) || get_user_status(id) <= STATUS_MEMBER || mapEnd) return PLUGIN_HANDLED;

	new fragsData[16], frags;

	read_args(fragsData, charsmax(fragsData));
	remove_quotes(fragsData);

	frags = str_to_num(fragsData);

	if (frags <= 0) {
		cod_print_chat(id, "The number of frags in a war can't be less than^x03 one^x01!");

		return PLUGIN_HANDLED;
	}

	warFrags[id] = frags;

	declare_war_menu(id);

	return PLUGIN_HANDLED;
}

public set_war_reward_handle(id)
{
	if (!is_user_connected(id) || !clan[id] || !cod_check_account(id) || get_user_status(id) <= STATUS_MEMBER || mapEnd) return PLUGIN_HANDLED;

	new rewardData[16], reward;

	read_args(rewardData, charsmax(rewardData));
	remove_quotes(rewardData);

	reward = str_to_num(rewardData);

	if (reward <= 0) {
		cod_print_chat(id, "The reward for winning can't be less than^x03 1 Honor^x01!");

		return PLUGIN_HANDLED;
	}

	if (reward % 2 != 0) {
		cod_print_chat(id, "The reward must be a^x03 number divisible by 2^x01.");

		return PLUGIN_HANDLED;
	}

	warReward[id] = reward;

	declare_war_menu(id);

	return PLUGIN_HANDLED;
}

public depositors_list(id)
{
	if (!is_user_connected(id) || mapEnd || !cod_check_account(id)) return PLUGIN_HANDLED;

	new queryData[128], tempId[1];

	tempId[0] = id;

	formatex(queryData, charsmax(queryData), "SELECT name, honor FROM `cod_clans_members` WHERE clan = '%i' AND honor > 0 ORDER BY honor DESC", clan[id]);

	SQL_ThreadQuery(sql, "show_depositors_list", queryData, tempId, sizeof(tempId));

	return PLUGIN_HANDLED;
}

public show_depositors_list(failState, Handle:query, error[], errorNum, tempId[], dataSize)
{
	if (failState) {
		if (failState == TQUERY_CONNECT_FAILED) cod_log_error(PLUGIN, "Could not connect to SQL database. Error: %s (%d)", error, errorNum);
		else if (failState == TQUERY_QUERY_FAILED) cod_log_error(PLUGIN, "Threaded query failed. Error: %s (%d)", error, errorNum);

		return PLUGIN_HANDLED;
	}

	new id = tempId[0];

	if (!is_user_connected(id) || mapEnd || !cod_check_account(id)) return PLUGIN_HANDLED;

	static motdData[2048], playerName[MAX_NAME], motdLength, rank, honor;

	rank = 0;

	motdLength = format(motdData, charsmax(motdData), "<body bgcolor=#000000><font color=#FFB000><pre>");
	motdLength += format(motdData[motdLength], charsmax(motdData) - motdLength, "%1s %-22.22s %12s^n", "#", "Nick", "Honor");

	while (SQL_MoreResults(query)) {
		rank++;

		SQL_ReadResult(query, SQL_FieldNameToNum(query, "name"), playerName, charsmax(playerName));
		replace_all(playerName, charsmax(playerName), "<", "");
		replace_all(playerName,charsmax(playerName), ">", "");

		honor = SQL_ReadResult(query, SQL_FieldNameToNum(query, "honor"));

		if (rank >= 10) motdLength += format(motdData[motdLength], charsmax(motdData) - motdLength, "%1i %22.22s %5d^n", rank, playerName, honor);
		else motdLength += format(motdData[motdLength], charsmax(motdData) - motdLength, "%1i %22.22s %6d^n", rank, playerName, honor);

		SQL_NextRow(query);
	}

	show_motd(id, motdData, "Depositors List");

	return PLUGIN_HANDLED;
}

public clans_top15(id)
{
	if (!is_user_connected(id) || mapEnd || !cod_check_account(id)) return PLUGIN_HANDLED;

	new queryData[256], tempId[1];

	tempId[0] = id;

	formatex(queryData, charsmax(queryData), "SELECT a.id, a.name, a.honor, a.kills, a.level, a.wins, (SELECT COUNT(clan) FROM `cod_clans_members` WHERE clan = a.id) as members FROM `cod_clans` a ORDER BY kills DESC LIMIT 15");

	SQL_ThreadQuery(sql, "show_clans_top15", queryData, tempId, sizeof(tempId));

	return PLUGIN_HANDLED;
}

public show_clans_top15(failState, Handle:query, error[], errorNum, tempId[], dataSize)
{
	if (failState) {
		if (failState == TQUERY_CONNECT_FAILED) cod_log_error(PLUGIN, "Could not connect to SQL database. Error: %s (%d)", error, errorNum);
		else if (failState == TQUERY_QUERY_FAILED) cod_log_error(PLUGIN, "Threaded query failed. Error: %s (%d)", error, errorNum);

		return PLUGIN_HANDLED;
	}

	new id = tempId[0];

	if (!is_user_connected(id) || mapEnd || !cod_check_account(id)) return PLUGIN_HANDLED;

	static motdData[2048], clanName[MAX_NAME], motdLength, clanId, rank, members, honor, kills, level, wins;

	rank = 0;

	motdLength = format(motdData, charsmax(motdData), "<body bgcolor=#000000><font color=#FFB000><pre>");
	motdLength += format(motdData[motdLength], charsmax(motdData) - motdLength, "%1s %-22.22s %4s %8s %6s %8s %6s^n", "#", "Name", "Members", "Level", "Kills", "Wars Won", "Honor");

	while (SQL_MoreResults(query)) {
		clanId = SQL_ReadResult(query, SQL_FieldNameToNum(query, "id"));

		if (!clanId) {
			SQL_NextRow(query);

			continue;
		}

		rank++;

		SQL_ReadResult(query, SQL_FieldNameToNum(query, "name"), clanName, charsmax(clanName));
		replace_all(clanName, charsmax(clanName), "<", "");
		replace_all(clanName, charsmax(clanName), ">", "");

		honor = SQL_ReadResult(query, SQL_FieldNameToNum(query, "honor"));
		kills = SQL_ReadResult(query, SQL_FieldNameToNum(query, "kills"));
		level = SQL_ReadResult(query, SQL_FieldNameToNum(query, "level"));
		wins = SQL_ReadResult(query, SQL_FieldNameToNum(query, "wins"));
		members = SQL_ReadResult(query, SQL_FieldNameToNum(query, "members"));

		if (rank >= 10) motdLength += format(motdData[motdLength], charsmax(motdData) - motdLength, "%1i %22.22s %5d %8d %10d %8d %10d^n", rank, clanName, members, level, kills, wins, honor);
		else motdLength += format(motdData[motdLength], charsmax(motdData) - motdLength, "%1i %22.22s %6d %8d %10d %8d %10d^n", rank, clanName, members, level, kills, wins, honor);

		SQL_NextRow(query);
	}

	show_motd(id, motdData, "Top 15 Clans");

	return PLUGIN_HANDLED;
}

public say_text(msgId, msgDest, msgEnt)
{
	if (!cvarChatPrefix) return PLUGIN_CONTINUE;

	new id = get_msg_arg_int(1);

	if (is_user_connected(id) && clan[id]) {
		new tempMessage[192], message[192], chatPrefix[MAX_NAME], playerName[MAX_NAME];

		get_msg_arg_string(2, tempMessage, charsmax(tempMessage));

		get_clan_info(clan[id], CLAN_NAME, chatPrefix, charsmax(chatPrefix));

		format(chatPrefix, charsmax(chatPrefix), "^x04[%s]", chatPrefix);

		if (!equal(tempMessage, "#Cstrike_Chat_All")) {
			add(message, charsmax(message), chatPrefix);
			add(message, charsmax(message), " ");
			add(message, charsmax(message), tempMessage);
		} else {
	        get_user_name(id, playerName, charsmax(playerName));

	        get_msg_arg_string(4, tempMessage, charsmax(tempMessage));
	        set_msg_arg_string(4, "");

	        add(message, charsmax(message), chatPrefix);
	        add(message, charsmax(message), "^x03 ");
	        add(message, charsmax(message), playerName);
	        add(message, charsmax(message), "^x01 :  ");
	        add(message, charsmax(message), tempMessage);
		}

		set_msg_arg_string(2, message);
	}

	return PLUGIN_CONTINUE;
}

public add_to_full_pack(esHandle, e, ent, host, hostFlags, player, pSet)
{
	if (!cvarEnemyGlow || !is_user_alive(host) || !is_user_alive(ent) || !clan[host] || !clan[ent] || !check_war_enemy(host, ent)) return;

	if (cvarEnemyGlow == GLOW_EXCEPT) {
		static Float:renderAmount;

		pev(ent, pev_renderamt, renderAmount);

		if (renderAmount <= 30.0) return;
	}

	set_es(esHandle, ES_RenderFx, kRenderFxGlowShell);
	set_es(esHandle, ES_RenderColor, 255, 0, 0);
	set_es(esHandle, ES_RenderMode, kRenderNormal);
	set_es(esHandle, ES_RenderAmt, 20);
}

public application_menu(id)
{
	if (!is_user_connected(id) || !cod_check_account(id) || mapEnd || clan[id]) return PLUGIN_HANDLED;

	new queryData[256], tempId[1];

	tempId[0] = id;

	formatex(queryData, charsmax(queryData), "SELECT a.id, a.name as 'clan', b.name FROM `cod_clans` a JOIN `cod_clans_members` b ON a.id = b.clan WHERE flag = '%i' ORDER BY a.kills DESC", STATUS_LEADER);

	SQL_ThreadQuery(sql, "application_menu_handle", queryData, tempId, sizeof(tempId));

	return PLUGIN_HANDLED;
}

public application_menu_handle(failState, Handle:query, error[], errorNum, tempId[], dataSize)
{
	if (failState) {
		if (failState == TQUERY_CONNECT_FAILED) cod_log_error(PLUGIN, "Could not connect to SQL database. Error: %s (%d)", error, errorNum);
		else if (failState == TQUERY_QUERY_FAILED) cod_log_error(PLUGIN, "Threaded query failed. Error: %s (%d)", error, errorNum);

		return PLUGIN_HANDLED;
	}

	new id = tempId[0];

	if (!is_user_connected(id) || !cod_check_account(id) || mapEnd || clan[id]) return PLUGIN_HANDLED;

	new itemName[128], itemData[MAX_NAME], clanName[MAX_NAME], userName[MAX_NAME], clanId, clansCount = 0,
	menu = menu_create("\ySubmit \rApplication:^n\wSelect the \rclan\w you want to \yapply\w to.", "application_handle");

	while (SQL_MoreResults(query)) {
		SQL_ReadResult(query, SQL_FieldNameToNum(query, "clan"), clanName, charsmax(clanName));
		SQL_ReadResult(query, SQL_FieldNameToNum(query, "name"), userName, charsmax(userName));

		clanId = SQL_ReadResult(query, SQL_FieldNameToNum(query, "id"));

		formatex(itemName, charsmax(itemName), "%s \y(Leader: \r%s\y)", clanName, userName);
		formatex(itemData, charsmax(itemData), "%s#%i", clanName, clanId);

		menu_additem(menu, itemName, itemData);

		SQL_NextRow(query);

		clansCount++;
	}

	menu_setprop(menu, MPROP_BACKNAME, "Back");
	menu_setprop(menu, MPROP_NEXTNAME, "Next");
	menu_setprop(menu, MPROP_EXITNAME, "Exit");

	if (!clansCount) {
		menu_destroy(menu);

		cod_print_chat(id, "There is no clan you could apply to!");
	} else menu_display(id, menu);

	return PLUGIN_HANDLED;
}

public application_handle(id, menu, item)
{
	if (!is_user_connected(id) || mapEnd || !cod_check_account(id)) return PLUGIN_HANDLED;

	if (item == MENU_EXIT) {
		client_cmd(id, "spk %s", codSounds[SOUND_EXIT]);

		menu_destroy(menu);

		return PLUGIN_HANDLED;
	}

	client_cmd(id, "spk %s", codSounds[SOUND_SELECT]);

	if (clan[id]) {
		cod_print_chat(id, "You can't apply if you are already in a clan!");

		show_clan_menu(id, 1);

		return PLUGIN_HANDLED;
	}

	new itemData[MAX_NAME], clanName[MAX_NAME], tempClanId[6], itemAccess, itemCallback;

	menu_item_getinfo(menu, item, itemAccess, itemData, charsmax(itemData), _, _, itemCallback);

	menu_destroy(menu);

	strtok(itemData, clanName, charsmax(clanName), tempClanId, charsmax(tempClanId), '#');

	if (check_applications(id, str_to_num(tempClanId))) {
		cod_print_chat(id, "You have already applied to this clan, wait for it to be reviewed!");

		show_clan_menu(id, 1);

		return PLUGIN_HANDLED;
	}

	new menuData[128];

	formatex(menuData, charsmax(menuData), "\ySubmit \rApplication^n\wAre you sure you want to \rapply\w to the clan \y%s\w?", clanName);

	new menu = menu_create(menuData, "application_confirm_handle");

	menu_additem(menu, "Yes", itemData);
	menu_additem(menu, "No");

	menu_display(id, menu);

	return PLUGIN_HANDLED;
}

public application_confirm_handle(id, menu, item)
{
	if (!is_user_connected(id) || mapEnd || !cod_check_account(id)) return PLUGIN_HANDLED;

	if (item == MENU_EXIT || item) {
		client_cmd(id, "spk %s", codSounds[SOUND_EXIT]);

		menu_destroy(menu);

		return PLUGIN_HANDLED;
	}

	new itemData[MAX_NAME], clanName[MAX_NAME], tempClanId[6], itemAccess, itemCallback;

	menu_item_getinfo(menu, item, itemAccess, itemData, charsmax(itemData), _, _, itemCallback);

	menu_destroy(menu);

	strtok(itemData, clanName, charsmax(clanName), tempClanId, charsmax(tempClanId), '#');

	new clanId = str_to_num(tempClanId);

	client_cmd(id, "spk %s", codSounds[SOUND_SELECT]);

	if (clan[id]) {
		cod_print_chat(id, "You can't apply if you are already in a clan!");

		show_clan_menu(id, 1);

		return PLUGIN_HANDLED;
	}

	add_application(id, clanId);

	cod_print_chat(id, "You applied to the clan^x03 %s^01.", clanName);

	return PLUGIN_HANDLED;
}

stock set_user_clan(id, playerClan = 0, owner = 0)
{
	if (!is_user_connected(id) || mapEnd || !cod_check_account(id)) return;

	if (playerClan == 0) {
		cod_add_user_bonus_health(id, -get_clan_info(clan[id], CLAN_HEALTH) * cvarHealthPerLevel);

		set_clan_info(clan[id], CLAN_MEMBERS, -1);

		TrieDeleteKey(Trie:get_clan_info(clan[id], CLAN_STATUS), playerName[id]);

		save_member(id, STATUS_NONE);

		clan[id] = 0;
	} else {
		clan[id] = playerClan;

		cod_add_user_bonus_health(id, get_clan_info(clan[id], CLAN_HEALTH) * cvarHealthPerLevel);

		set_clan_info(clan[id], CLAN_MEMBERS, 1);

		TrieSetCell(Trie:get_clan_info(clan[id], CLAN_STATUS), playerName[id], owner ? STATUS_LEADER : STATUS_MEMBER);

		save_member(id, owner ? STATUS_LEADER : STATUS_MEMBER, 1);
	}
}

stock set_user_status(id, status)
{
	if (!is_user_connected(id) || !cod_check_account(id) || mapEnd || !clan[id]) return;

	TrieSetCell(Trie:get_clan_info(clan[id], CLAN_STATUS), playerName[id], status);

	save_member(id, status);
}

stock get_user_status(id)
{
	if (!is_user_connected(id) || !cod_check_account(id) || mapEnd || !clan[id]) return STATUS_NONE;

	new status;

	TrieGetCell(Trie:get_clan_info(clan[id], CLAN_STATUS), playerName[id], status);

	return status;
}

public sql_init()
{
	new host[64], user[64], pass[64], db[64], queryData[512], error[128], errorNum;

	get_cvar_string("cod_sql_host", host, charsmax(host));
	get_cvar_string("cod_sql_user", user, charsmax(user));
	get_cvar_string("cod_sql_pass", pass, charsmax(pass));
	get_cvar_string("cod_sql_db", db, charsmax(db));

	sql = SQL_MakeDbTuple(host, user, pass, db);

	connection = SQL_Connect(sql, errorNum, error, charsmax(error));

	if (errorNum) {
		cod_log_error(PLUGIN, "SQL Query Error. [%d] %s", errorNum, error);

		sql = Empty_Handle;

		set_task(5.0, "sql_init");

		return;
	}

	sqlConnected = true;

	formatex(queryData, charsmax(queryData), "CREATE TABLE IF NOT EXISTS `cod_clans` (`id` INT NOT NULL AUTO_INCREMENT, `name` varchar(%i) NOT NULL, ", MAX_SAFE_NAME);
	add(queryData, charsmax(queryData), "`honor` INT NOT NULL, `kills` INT NOT NULL, `level` INT NOT NULL, `wins` INT NOT NULL, `health` INT NOT NULL, ");
	add(queryData, charsmax(queryData), "`gravity` INT NOT NULL, `damage` INT NOT NULL, `exp` INT NOT NULL, PRIMARY KEY (`id`));");

	new Handle:query = SQL_PrepareQuery(connection, queryData);

	SQL_Execute(query);

	formatex(queryData, charsmax(queryData), "CREATE TABLE IF NOT EXISTS `cod_clans_members` (`name` varchar(%i) NOT NULL, `clan` INT NOT NULL, `flag` INT NOT NULL, `honor` INT NOT NULL, PRIMARY KEY (`name`));", MAX_SAFE_NAME);

	query = SQL_PrepareQuery(connection, queryData);

	SQL_Execute(query);

	formatex(queryData, charsmax(queryData), "CREATE TABLE IF NOT EXISTS `cod_clans_applications` (`name` varchar(%i) NOT NULL, `clan` INT NOT NULL, PRIMARY KEY (`name`, `clan`));", MAX_SAFE_NAME);

	query = SQL_PrepareQuery(connection, queryData);

	SQL_Execute(query);

	formatex(queryData, charsmax(queryData), "CREATE TABLE IF NOT EXISTS `cod_clans_wars` (`id` INT NOT NULL AUTO_INCREMENT, `clan` INT NOT NULL, `clan2` INT NOT NULL, ");
	add(queryData, charsmax(queryData), "`progress` INT NOT NULL, `progress2` INT NOT NULL, `duration` INT NOT NULL, `reward` INT NOT NULL, `started` INT NOT NULL, PRIMARY KEY (`id`));");

	query = SQL_PrepareQuery(connection, queryData);

	SQL_Execute(query);

	SQL_FreeHandle(query);
}

public ignore_handle(failState, Handle:query, error[], errorNum, data[], dataSize)
{
	if (failState)  {
		if (failState == TQUERY_CONNECT_FAILED) cod_log_error(PLUGIN, "Could not connect to SQL database. Error: %s (%d)", error, errorNum);
		else if (failState == TQUERY_QUERY_FAILED) cod_log_error(PLUGIN, "Threaded query failed. Error: %s (%d)", error, errorNum);
	}

	return PLUGIN_CONTINUE;
}

public save_clan(clan)
{
	static queryData[512], safeClanName[MAX_SAFE_NAME], codClan[clanInfo];

	ArrayGetArray(codClans, clan, codClan);

	cod_sql_string(codClan[CLAN_NAME], safeClanName, charsmax(safeClanName));

	formatex(queryData, charsmax(queryData), "UPDATE `cod_clans` SET level = '%i', honor = '%i', kills = '%i', wins = '%i', health = '%i', gravity = '%i', exp = '%i', damage = '%i' WHERE name = ^"%s^"",
		codClan[CLAN_LEVEL], codClan[CLAN_HONOR], codClan[CLAN_KILLS], codClan[CLAN_WINS], codClan[CLAN_HEALTH], codClan[CLAN_GRAVITY], codClan[CLAN_EXP], codClan[CLAN_DAMAGE], safeClanName);

	SQL_ThreadQuery(sql, "ignore_handle", queryData);
}

public load_data(id)
{
	if (!sqlConnected) {
		set_task(1.0, "load_data", id);

		return;
	}

	new queryData[256], tempId[1];

	tempId[0] = id;

	formatex(queryData, charsmax(queryData), "SELECT a.flag, b.*, (SELECT COUNT(clan) FROM `cod_clans_members` WHERE clan = a.clan) AS members FROM `cod_clans_members` a JOIN `cod_clans` b ON a.clan = b.id WHERE a.name = ^"%s^"", playerName[id]);
	SQL_ThreadQuery(sql, "load_data_handle", queryData, tempId, sizeof(tempId));
}

public load_data_handle(failState, Handle:query, error[], errorNum, tempId[], dataSize)
{
	if (failState) {
		if (failState == TQUERY_CONNECT_FAILED) cod_log_error(PLUGIN, "Could not connect to SQL database. Error: %s (%d)", error, errorNum);
		else if (failState == TQUERY_QUERY_FAILED) cod_log_error(PLUGIN, "Threaded query failed. Error: %s (%d)", error, errorNum);

		return;
	}

	new id = tempId[0];

	if (SQL_MoreResults(query) && SQL_ReadResult(query, SQL_FieldNameToNum(query, "id"))) {
		new codClan[clanInfo];

		codClan[CLAN_ID] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "id"));

		if (!check_clan_loaded(codClan[CLAN_ID])) {
			SQL_ReadResult(query, SQL_FieldNameToNum(query, "name"), codClan[CLAN_NAME], charsmax(codClan[CLAN_NAME]));

			codClan[CLAN_LEVEL] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "level"));
			codClan[CLAN_HONOR] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "honor"));
			codClan[CLAN_HEALTH] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "health"));
			codClan[CLAN_GRAVITY] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "gravity"));
			codClan[CLAN_EXP] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "exp"));
			codClan[CLAN_DAMAGE] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "damage"));
			codClan[CLAN_KILLS] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "kills"));
			codClan[CLAN_WINS] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "wins"));
			codClan[CLAN_MEMBERS] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "members"));
			codClan[CLAN_STATUS] = _:TrieCreate();

			ArrayPushArray(codClans, codClan);

			new queryData[128];

			formatex(queryData, charsmax(queryData), "SELECT * FROM `cod_clans_wars` WHERE clan = '%i' AND started = '1'", codClan[CLAN_ID]);

			SQL_ThreadQuery(sql, "load_wars_data_handle", queryData);
		}

		clan[id] = codClan[CLAN_ID];

		new status = SQL_ReadResult(query, SQL_FieldNameToNum(query, "flag"));

		cod_add_user_bonus_health(id, get_clan_info(clan[id], CLAN_HEALTH) * cvarHealthPerLevel);

		TrieSetCell(Trie:get_clan_info(clan[id], CLAN_STATUS), playerName[id], status);
	} else {
		new queryData[128];

		formatex(queryData, charsmax(queryData), "INSERT IGNORE INTO `cod_clans_members` (`name`) VALUES (^"%s^");", playerName[id]);

		SQL_ThreadQuery(sql, "ignore_handle", queryData);
	}

	set_bit(id, loaded);
}

public show_clan_info(id)
{
	id -= TASK_INFO;

	if (get_bit(id, info)) return;

	if (!get_bit(id, loaded)) {
		set_task(5.0, "show_clan_info", id + TASK_INFO);

		return;
	}

	set_bit(id, info);

	if (get_user_status(id) > STATUS_MEMBER) {
		new applications = get_applications_count(clan[id]), wars = get_wars_count(clan[id], 0);

		if (applications > 0 && wars > 0) cod_print_chat(id, "You have^x03 %i join application(s)^x01 and^x03 %i war declaration(s)^x01 to review in your^x04 clan^x01.", applications, wars);
		else if(applications > 0) cod_print_chat(id, "You have^x03 %i join application(s)^x01 to review in your^x04 clan^x01.", applications);
		else if(wars > 0) cod_print_chat(id, "You have^x03 %i war declaration(s)^x01 to review in your^x04 clan^x01.", wars);
	}
}

public load_wars_data_handle(failState, Handle:query, error[], errorNum)
{
	if (failState) {
		if (failState == TQUERY_CONNECT_FAILED) cod_log_error(PLUGIN, "Could not connect to SQL database. Error: %s (%d)", error, errorNum);
		else if (failState == TQUERY_QUERY_FAILED) cod_log_error(PLUGIN, "Threaded query failed. Error: %s (%d)", error, errorNum);

		return;
	}

	new codWar[warInfo];

	while (SQL_MoreResults(query)) {
		codWar[WAR_ID] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "id"));
		codWar[WAR_CLAN] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "clan"));
		codWar[WAR_CLAN2] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "clan2"));
		codWar[WAR_PROGRESS] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "progress"));
		codWar[WAR_PROGRESS2] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "progress2"));
		codWar[WAR_DURATION] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "duration"));
		codWar[WAR_REWARD] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "reward"));

		ArrayPushArray(codWars, codWar);

		SQL_NextRow(query);
	}
}

public _cod_get_user_clan(id)
	return clan[id];

public _cod_get_user_clan_bonus(id)
	return get_clan_info(clan[id], CLAN_EXP) * cvarExpPerLevel;

public _cod_get_clan_name(clanId, dataReturn[], dataLength)
{
	param_convert(2);

	get_clan_info(clanId, CLAN_NAME, dataReturn, dataLength);
}

stock save_member(id, status = 0, change = 0, const name[] = "")
{
	new queryData[192], safeName[MAX_SAFE_NAME];

	if (strlen(name)) cod_sql_string(name, safeName, charsmax(safeName));
	else copy(safeName, charsmax(safeName), playerName[id]);

	if (status) {
		if (change) formatex(queryData, charsmax(queryData), "UPDATE `cod_clans_members` SET clan = '%i', flag = '%i' WHERE name = ^"%s^"", clan[id], status, safeName);
		else formatex(queryData, charsmax(queryData), "UPDATE `cod_clans_members` SET flag = '%i' WHERE name = ^"%s^"", status, safeName);
	} else formatex(queryData, charsmax(queryData), "UPDATE `cod_clans_members` SET clan = '0', flag = '0', honor = '0' WHERE name = ^"%s^"", safeName);

	SQL_ThreadQuery(sql, "ignore_handle", queryData);

	if (change) remove_applications(id, safeName);
}

stock declare_war(id, clanId)
{
	new queryData[192], clanName[32];

	formatex(queryData, charsmax(queryData), "INSERT INTO `cod_clans_wars` (`clan`, `clan2`, `duration`, `reward`) VALUES ('%i', '%i', '%i', '%i')", clan[id], clanId, warFrags[id], warReward[id]);

	SQL_ThreadQuery(sql, "ignore_handle", queryData);

	get_clan_info(clan[id], CLAN_NAME, clanName, charsmax(clanName));

	for (new i = 1; i <= MAX_PLAYERS; i++) {
		if (!is_user_connected(i) || is_user_bot(i) || is_user_hltv(i) || clan[i] != clanId || get_user_status(i) <= STATUS_MEMBER) continue;

		cod_print_chat(i, "Clan^x03 %s^x01 declared^x04 war^x01 on your clan! Accept or reject the war.", clanName);
	}
}

stock accept_war(id, warId, clanId, duration, honor, const enemyClanName[])
{
	new queryData[192], codWar[warInfo], clanName[MAX_NAME];

	formatex(queryData, charsmax(queryData), "UPDATE `cod_clans_wars` SET started = '1' WHERE id = '%i'", warId);

	SQL_ThreadQuery(sql, "ignore_handle", queryData);

	if (!get_clan_id(clanId)) {
		formatex(queryData, charsmax(queryData), "UPDATE `cod_clans` SET honor = honor - %i WHERE id = '%i'", honor, clanId);

		SQL_ThreadQuery(sql, "ignore_handle", queryData);
	} else set_clan_info(clanId, CLAN_HONOR, -honor);

	set_clan_info(clan[id], CLAN_HONOR, -honor);
	get_clan_info(clan[id], CLAN_NAME, clanName, charsmax(clanName));

	codWar[WAR_ID] = warId;
	codWar[WAR_CLAN] = clanId;
	codWar[WAR_CLAN2] = clan[id];
	codWar[WAR_DURATION] = duration;
	codWar[WAR_REWARD] = honor * 2;

	ArrayPushArray(codWars, codWar);

	for (new i = 1; i <= MAX_PLAYERS; i++) {
		if (!is_user_connected(i) || is_user_bot(i) || is_user_hltv(i) || !clan[i] || (clan[i] != clan[id] && clan[i] != clanId)) continue;

		cod_print_chat(i, "Your clan started a war with clan^x03 %s^x01 (Frags:^x04 %i^x01 | Reward:^x04 %i Honor^x01).", clan[i] == clan[id] ? clanName : enemyClanName, codWar[WAR_DURATION], codWar[WAR_REWARD]);
	}
}

stock remove_war(warId, started = 0)
{
	new queryData[128], error[128], Handle:query, bool:result, errorNum;

	formatex(queryData, charsmax(queryData), "DELETE FROM `cod_clans_wars` WHERE id = '%i' AND started = '%i'", warId, started);

	query = SQL_PrepareQuery(connection, queryData);

	if (SQL_Execute(query)) {
		if (SQL_AffectedRows(query)) result = true;
	} else {
		errorNum = SQL_QueryError(query, error, charsmax(error));

		cod_log_error(PLUGIN, "SQL Query Error. [%d] %s", errorNum, error);
	}

	SQL_FreeHandle(query);

	return result;
}

public remove_clan_wars(failState, Handle:query, error[], errorNum, tempId[], dataSize)
{
	if (failState) {
		if (failState == TQUERY_CONNECT_FAILED) cod_log_error(PLUGIN, "Could not connect to SQL database. Error: %s (%d)", error, errorNum);
		else if (failState == TQUERY_QUERY_FAILED) cod_log_error(PLUGIN, "Threaded query failed. Error: %s (%d)", error, errorNum);

		return;
	}

	new id = tempId[0], queryData[128], clanName[32], clanId[2], reward, enemyClan;

	while (SQL_MoreResults(query)) {
		SQL_ReadResult(query, SQL_FieldNameToNum(query, "name"), clanName, charsmax(clanName));

		clanId[0] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "clan"));
		clanId[1] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "clan2"));

		reward = SQL_ReadResult(query, SQL_FieldNameToNum(query, "reward"));

		enemyClan = id == clanId[0] ? clanId[1] : clanId[0];

		if (get_clan_id(enemyClan)) {
			set_clan_info(enemyClan, CLAN_HONOR, reward);
			set_clan_info(enemyClan, CLAN_WINS, 1);

			for (new i = 1; i <= MAX_PLAYERS; i++) {
				if (!is_user_connected(i) || is_user_bot(i) || is_user_hltv(i) || clan[i] != enemyClan) continue;

				cod_print_chat(i, "Clan^x03 %s^x01 has been disbanded, which ends the war with it. Victory!", clanName);
			}
		} else {
			formatex(queryData, charsmax(queryData), "UPDATE `cod_clans` SET money = money + %i WHERE id = '%i'", reward, enemyClan);

			SQL_ThreadQuery(sql, "ignore_handle", queryData);
		}

		SQL_NextRow(query);
	}

	formatex(queryData, charsmax(queryData), "DELETE FROM `cod_clans_wars` WHERE clan = '%i' OR clan2 = '%i'", id, id);

	SQL_ThreadQuery(sql, "ignore_handle", queryData);
}

public save_war(warId)
{
	static queryData[128], codWar[warInfo];

	ArrayGetArray(codWars, warId, codWar);

	formatex(queryData, charsmax(queryData), "UPDATE `cod_clans_wars` SET progress = '%i', progress2 = '%i' WHERE id = '%i'", codWar[WAR_PROGRESS], codWar[WAR_PROGRESS2], codWar[WAR_ID]);

	SQL_ThreadQuery(sql, "ignore_handle", queryData);
}

stock check_war(killer, victim)
{
	static codWar[warInfo], killerClan[32], victimClan[32], killerName[32], victimName[32];

	for (new i = 0; i < ArraySize(codWars); i++) {
		ArrayGetArray(codWars, i, codWar);

		if ((clan[killer] == codWar[WAR_CLAN] && clan[victim] == codWar[WAR_CLAN2]) || (clan[killer] == codWar[WAR_CLAN2] && clan[victim] == codWar[WAR_CLAN])) {
			new progress = clan[killer] == codWar[WAR_CLAN] ? WAR_PROGRESS : WAR_PROGRESS2;

			codWar[progress]++;

			get_clan_info(clan[victim], CLAN_NAME, victimClan, charsmax(victimClan));
			get_user_name(victim, victimName, charsmax(victimName));

			get_clan_info(clan[killer], CLAN_NAME, killerClan, charsmax(killerClan));
			get_user_name(killer, killerName, charsmax(killerName));

			if (codWar[progress] == codWar[WAR_DURATION]) {
				cod_print_chat(killer, "By killing^x03 %s^x01 you ended the war with clan^x03 %s^x01. Victory!", victimName, victimClan);
				cod_print_chat(victim, "By dying to^x03 %s^x01 you ended the war with clan^x03 %s^x01. Defeat...", killerName, killerClan);

				for (new j = 0; j <= MAX_PLAYERS; j++) {
					if (!is_user_connected(j) || is_user_bot(j) || is_user_hltv(j) || !clan[j] || j == killer || j == victim) continue;

					if (clan[j] == clan[killer]) cod_print_chat(j, "^x03 %s^x01 killed^x03 %s^x01 and ended the war with clan^x03 %s^x01. Victory!", killerName, victimName, victimClan);
					if (clan[j] == clan[victim]) cod_print_chat(j, "^x03 %s^x01 died to^x03 %s^x01 and ended the war with clan^x03 %s^x01. Defeat...", victimName, killerName, killerClan);
				}

				set_clan_info(clan[killer], CLAN_HONOR, codWar[WAR_REWARD]);
				set_clan_info(clan[killer], CLAN_WINS, 1);

				remove_war(codWar[WAR_ID], 1);

				ArrayDeleteItem(codWars, i);

			} else {
				cod_print_chat(killer, "By killing^x03 %s^x01 you scored a frag in the war with clan^x03 %s^x01. Score:^x04 %i - %i / %i^x01.", victimName, victimClan, codWar[progress], codWar[progress == WAR_PROGRESS ? WAR_PROGRESS2 : WAR_PROGRESS], codWar[WAR_DURATION]);

				ArraySetArray(codWars, i, codWar);

				save_war(i);
			}

			break;
		}
	}
}

stock check_war_enemy(id, enemy)
{
	static codWar[warInfo];

	for (new i = 0; i < ArraySize(codWars); i++) {
		ArrayGetArray(codWars, i, codWar);

		if ((clan[id] == codWar[WAR_CLAN] && clan[enemy] == codWar[WAR_CLAN2]) || (clan[id] == codWar[WAR_CLAN2] && clan[enemy] == codWar[WAR_CLAN])) return true;
	}

	return false;
}

stock add_deposited_honor(id, honor)
{
	new queryData[192];

	formatex(queryData, charsmax(queryData), "UPDATE `cod_clans_members` SET honor = honor + %d WHERE name = ^"%s^"", honor, playerName[id]);

	SQL_ThreadQuery(sql, "ignore_handle", queryData);
}

stock add_application(id, clanId)
{
	new queryData[192], userName[MAX_NAME];

	formatex(queryData, charsmax(queryData), "INSERT INTO `cod_clans_applications` (`name`, `clan`) VALUES (^"%s^", '%i');", playerName[id], clanId);

	SQL_ThreadQuery(sql, "ignore_handle", queryData);

	get_user_name(id, userName, charsmax(userName));

	for (new i = 1; i <= MAX_PLAYERS; i++) {
		if (!is_user_connected(i) || is_user_bot(i) || is_user_hltv(i) || clan[i] != clanId || get_user_status(i) <= STATUS_MEMBER) continue;

		cod_print_chat(i, "^x03%s^x01 applied to join the clan!", userName);
	}
}

stock check_applications(id, clanId)
{
	new queryData[192], error[128], errorNum, Handle:query, bool:foundApplication;

	formatex(queryData, charsmax(queryData), "SELECT * FROM `cod_clans_applications` WHERE `name` = ^"%s^" AND clan = '%i'", playerName[id], clanId);

	query = SQL_PrepareQuery(connection, queryData);

	if (SQL_Execute(query)) {
		if (SQL_NumResults(query)) foundApplication = true;
	} else {
		errorNum = SQL_QueryError(query, error, charsmax(error));

		cod_log_error(PLUGIN, "SQL Query Error. [%d] %s", errorNum, error);
	}

	SQL_FreeHandle(query);

	return foundApplication;
}

stock accept_application(id, const userName[])
{
	new player = get_user_index(userName);

	if (is_user_connected(player)) {
		new clanName[MAX_NAME];

		get_clan_info(clan[id], CLAN_NAME, clanName, charsmax(clanName));

		set_user_clan(player, clan[id]);

		cod_print_chat(player, "You have been accepted into the clan^x03 %s^x01!", clanName);
	} else {
		set_clan_info(clan[id], CLAN_MEMBERS, get_clan_info(clan[id], CLAN_MEMBERS) + 1);

		save_member(id, STATUS_MEMBER, 1, userName);
	}

	remove_applications(id, userName);
}

stock remove_application(id, const name[] = "")
{
	new player = get_user_index(name);

	if (is_user_connected(player)) {
		new clanName[MAX_NAME], userName[MAX_NAME];

		get_clan_info(clan[id], CLAN_NAME, clanName, charsmax(clanName));
		get_user_name(id, userName, charsmax(userName));

		cod_print_chat(player, "^x03%s^x01 rejected your application to the clan^x03 %s^x01!", userName, clanName);
	}

	new queryData[192], safeName[MAX_SAFE_NAME];

	if (strlen(name)) cod_sql_string(name, safeName, charsmax(safeName));
	else copy(safeName, charsmax(safeName), playerName[id]);

	formatex(queryData, charsmax(queryData), "DELETE FROM `cod_clans_applications` WHERE name = ^"%s^" AND clan = '%i'", safeName, clan[id]);

	SQL_ThreadQuery(sql, "ignore_handle", queryData);
}

stock remove_applications(id, const name[] = "")
{
	new queryData[192], safeName[MAX_SAFE_NAME];

	if (strlen(name)) cod_sql_string(name, safeName, charsmax(safeName));
	else copy(safeName, charsmax(safeName), playerName[id]);

	formatex(queryData, charsmax(queryData), "DELETE FROM `cod_clans_applications` WHERE name = ^"%s^"", safeName);

	SQL_ThreadQuery(sql, "ignore_handle", queryData);
}

stock get_applications_count(clan)
{
	new queryData[128], error[128], errorNum, Handle:query, applicationsCount = 0;

	formatex(queryData, charsmax(queryData), "SELECT * FROM `cod_clans_applications` WHERE `clan` = '%i'", clan);

	query = SQL_PrepareQuery(connection, queryData);

	if (SQL_Execute(query)) {
		while (SQL_MoreResults(query)) {
			applicationsCount++;

			SQL_NextRow(query);
		}
	} else {
		errorNum = SQL_QueryError(query, error, charsmax(error));

		cod_log_error(PLUGIN, "SQL Query Error. [%d] %s", errorNum, error);
	}

	SQL_FreeHandle(query);

	return applicationsCount;
}

stock get_wars_count(clanId, started = 1, initiated = 0)
{
	new queryData[128], error[128], Handle:query, warsCount = 0, errorNum;

	if(started) formatex(queryData, charsmax(queryData), "SELECT * FROM `cod_clans_wars` WHERE (clan = '%i' OR clan2 = '%i') AND started = '1'", clanId, clanId);
	else formatex(queryData, charsmax(queryData), "SELECT * FROM `cod_clans_wars` WHERE %s = '%i' AND started = '0'", initiated ? "clan" : "clan2", clanId);

	query = SQL_PrepareQuery(connection, queryData);

	if (SQL_Execute(query)) {
		while (SQL_MoreResults(query)) {
			warsCount++;

			SQL_NextRow(query);
		}
	} else {
		errorNum = SQL_QueryError(query, error, charsmax(error));

		cod_log_error(PLUGIN, "SQL Query Error. [%d] %s", errorNum, error);
	}

	SQL_FreeHandle(query);

	return warsCount;
}

stock check_clan_name(const clanName[])
{
	new queryData[192], safeClanName[MAX_SAFE_NAME], error[128], errorNum, Handle:query, bool:foundClan;

	cod_sql_string(clanName, safeClanName, charsmax(safeClanName));

	formatex(queryData, charsmax(queryData), "SELECT * FROM `cod_clans` WHERE `name` = ^"%s^"", safeClanName);

	query = SQL_PrepareQuery(connection, queryData);

	if (SQL_Execute(query)) {
		if (SQL_NumResults(query)) foundClan = true;
	} else {
		errorNum = SQL_QueryError(query, error, charsmax(error));

		cod_log_error(PLUGIN, "SQL Query Error. [%d] %s", errorNum, error);
	}

	SQL_FreeHandle(query);

	return foundClan;
}

public update_clan_name(clan, clanName[], clanNameLength)
{
	new queryData[512], oldClanName[MAX_NAME], safeOldClanName[MAX_SAFE_NAME], safeClanName[MAX_SAFE_NAME];

	get_clan_info(clan, CLAN_NAME, oldClanName, charsmax(oldClanName));
	set_clan_info(clan, CLAN_NAME, _, clanName, clanNameLength);

	cod_sql_string(oldClanName, safeOldClanName, charsmax(safeOldClanName));
	cod_sql_string(clanName, safeClanName, charsmax(safeClanName));

	formatex(queryData, charsmax(queryData), "UPDATE `cod_clans` SET `name` = ^"%s^" WHERE `name` = ^"%s^"", safeClanName, safeOldClanName);

	SQL_ThreadQuery(sql, "ignore_handle", queryData);
}

stock check_user_clan(const userName[])
{
	new queryData[192], safeUserName[MAX_SAFE_NAME], error[128], errorNum, Handle:query, bool:foundClan;

	cod_sql_string(userName, safeUserName, charsmax(safeUserName));

	formatex(queryData, charsmax(queryData), "SELECT * FROM `cod_clans_members` WHERE `name` = ^"%s^" AND clan > 0", userName);

	query = SQL_PrepareQuery(connection, queryData);

	if (SQL_Execute(query)) {
		if (SQL_NumResults(query)) foundClan = true;
	} else {
		errorNum = SQL_QueryError(query, error, charsmax(error));

		cod_log_error(PLUGIN, "SQL Query Error. [%d] %s", errorNum, error);
	}

	SQL_FreeHandle(query);

	return foundClan;
}

stock create_clan(id, const clanName[])
{
	new codClan[clanInfo], queryData[192], safeClanName[MAX_SAFE_NAME], error[128], errorNum, Handle:query, bool:success;

	cod_sql_string(clanName, safeClanName, charsmax(safeClanName));

	formatex(queryData, charsmax(queryData), "INSERT INTO `cod_clans` (`name`) VALUES (^"%s^");", safeClanName);

	query = SQL_PrepareQuery(connection, queryData);

	if (!SQL_Execute(query)) {
		errorNum = SQL_QueryError(query, error, charsmax(error));

		cod_log_error(PLUGIN, "SQL Query Error. [%d] %s", errorNum, error);
	}

	formatex(queryData, charsmax(queryData), "SELECT id FROM `cod_clans` WHERE name = ^"%s^";", safeClanName);

	query = SQL_PrepareQuery(connection, queryData);

	if (SQL_Execute(query)) {
		if (SQL_NumResults(query)) {
			clan[id] = SQL_ReadResult(query, SQL_FieldNameToNum(query, "id"));

			copy(codClan[CLAN_NAME], charsmax(codClan[CLAN_NAME]), clanName);
			codClan[CLAN_STATUS] = _:TrieCreate();
			codClan[CLAN_ID] = clan[id];

			ArrayPushArray(codClans, codClan);

			set_user_clan(id, clan[id], 1);
			set_user_status(id, STATUS_LEADER);

			if (cvarCreateFee) cod_add_user_honor(id, -cvarCreateFee);

			success = true;
		}
	} else {
		errorNum = SQL_QueryError(query, error, charsmax(error));

		cod_log_error(PLUGIN, "SQL Query Error. [%d] %s", errorNum, error);
	}

	SQL_FreeHandle(query);

	return success;
}

stock remove_clan(id)
{
	for (new player = 1; player <= MAX_PLAYERS; player++) {
		if (!is_user_connected(player) || is_user_hltv(player) || is_user_bot(id) || player == id) continue;

		if (clan[player] == clan[id]) {
			clan[player] = 0;

			cod_print_chat(player, "Your clan has been disbanded.");
		}
	}

	ArrayDeleteItem(codClans, get_clan_id(clan[id]));

	new queryData[192], tempId[1];

	tempId[0] = clan[id];

	formatex(queryData, charsmax(queryData), "SELECT a.*, (SELECT name FROM `cod_clans` WHERE id = '%i') as name FROM `cod_clans_wars` a WHERE (clan = '%i' OR clan2 = '%i') AND started = '1'", clan[id], clan[id], clan[id]);
	SQL_ThreadQuery(sql, "remove_clan_wars", queryData, tempId, sizeof(tempId));

	formatex(queryData, charsmax(queryData), "DELETE FROM `cod_clans` WHERE id = '%i'", clan[id]);
	SQL_ThreadQuery(sql, "ignore_handle", queryData);

	formatex(queryData, charsmax(queryData), "DELETE FROM `cod_clans_applications` WHERE clan = '%i'", clan[id]);
	SQL_ThreadQuery(sql, "ignore_handle", queryData);

	formatex(queryData, charsmax(queryData), "UPDATE `cod_clans_members` SET flag = '%i', clan = '0' WHERE clan = '%i'", STATUS_NONE, clan[id]);
	SQL_ThreadQuery(sql, "ignore_handle", queryData);

	clan[id] = 0;
}

stock check_clan_loaded(clan)
{
	static codClan[clanInfo];

	for (new i = 1; i < ArraySize(codClans); i++) {
		ArrayGetArray(codClans, i, codClan);

		if (clan == codClan[CLAN_ID]) return true;
	}

	return false;
}

stock get_clan_id(clan)
{
	static codClan[clanInfo];

	for (new i = 1; i < ArraySize(codClans); i++) {
		ArrayGetArray(codClans, i, codClan);

		if (clan == codClan[CLAN_ID]) return i;
	}

	return 0;
}

stock get_clan_honor(clanId)
{
	if (get_clan_id(clanId)) {
		new codClan[clanInfo];

		ArrayGetArray(codClans, get_clan_id(clanId), codClan);

		return codClan[CLAN_HONOR];
	}

	new queryData[128], error[128], Handle:query, honor, errorNum;

	formatex(queryData, charsmax(queryData), "SELECT honor FROM `cod_clans` WHERE id = '%i'", clanId);

	query = SQL_PrepareQuery(connection, queryData);

	if (SQL_Execute(query)) {
		if (SQL_NumResults(query)) honor = SQL_ReadResult(query, SQL_FieldNameToNum(query, "honor"));
	} else {
		errorNum = SQL_QueryError(query, error, charsmax(error));

		cod_log_error(PLUGIN, "SQL Query Error. [%d] %s", errorNum, error);
	}

	SQL_FreeHandle(query);

	return honor;
}

stock get_clan_info(clan, info, dataReturn[] = "", dataLength = 0)
{
	static codClan[clanInfo];

	for (new i = 0; i < ArraySize(codClans); i++) {
		ArrayGetArray(codClans, i, codClan);

		if (codClan[CLAN_ID] != clan) continue;

		if (info == CLAN_NAME) {
			copy(dataReturn, dataLength, codClan[info]);

			return 0;
		}

		return codClan[info];
	}

	return 0;
}

stock set_clan_info(clan, info, value = 0, dataSet[] = "", dataLength = 0)
{
	static codClan[clanInfo];

	for (new i = 1; i < ArraySize(codClans); i++) {
		ArrayGetArray(codClans, i, codClan);

		if (codClan[CLAN_ID] != clan) continue;

		if (info == CLAN_NAME) formatex(codClan[info], dataLength, dataSet);
		else codClan[info] += value;

		ArraySetArray(codClans, i, codClan);

		if (info != CLAN_MEMBERS) save_clan(i);

		break;
	}
}

stock explode(const string[], const character, output[][], const maxParts, const maxLength)
{
	new currentPart = 0, stringLength = strlen(string), currentLength = 0;

	do {
		currentLength += (1 + copyc(output[currentPart++], maxLength, string[currentLength], character));
	} while(currentLength < stringLength && currentPart < maxParts);
}
