#include <amxmodx>
#include <cod>

#define PLUGIN "CoD Shop"
#define VERSION "1.3.0"
#define AUTHOR "O'Zone"

new const commandShopMenu[][] = { "sklep", "say /shop", "say_team /shop", "say /sklep", "say_team /sklep" };

enum _:shopInfo { REPAIR, BUY, UPGRADE, SMALL_BANDAGE, BIG_BANDAGE, SMALL_EXP, MEDIUM_EXP, BIG_EXP, RANDOM_EXP,
	ROCKET, MINE, DYNAMITE, MEDKIT, THUNDER, TELEPORT, JUMP, BUNNY_HOP, SILENT, ARMOR, DAMAGE, INVISIBLE };

new cvarCostRepair, cvarCostItem, cvarCostUpgrade, cvarCostSmallBandage, cvarCostBigBandage, cvarCostSmallExp,
	cvarCostMediumExp,cvarCostBigExp, cvarCostRandomExp, cvarCostRocket, cvarCostMine, cvarCostDynamite, cvarCostMedkit,
	cvarCostThunder,cvarCostTeleport, cvarCostJump, cvarCostBunnyHop, cvarCostSilent, cvarCostArmor, cvarCostDamage,
	cvarCostInvisible,cvarDurabilityAmount, cvarSmallExp, cvarMediumExp,cvarBigExp, cvarMinRandomExp, cvarMaxRandomExp,
	cvarSmallBandageHP,cvarBigBandageHP, cvarArmorAmount, cvarDamageAmount, cvarMaxDurability, bool:mapEnd, damageBonus;

new shopSlot[MAX_PLAYERS + 1], pendingOption[MAX_PLAYERS + 1], pendingPrice[MAX_PLAYERS + 1];

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	for (new i; i < sizeof commandShopMenu; i++) register_clcmd(commandShopMenu[i], "shop_menu");

	bind_pcvar_num(create_cvar("cod_shop_repair_cost", "10"), cvarCostRepair);
	bind_pcvar_num(create_cvar("cod_shop_item_cost", "15"), cvarCostItem);
	bind_pcvar_num(create_cvar("cod_shop_upgrade_cost", "10"), cvarCostUpgrade);
	bind_pcvar_num(create_cvar("cod_shop_small_bandage_cost", "6"), cvarCostSmallBandage);
	bind_pcvar_num(create_cvar("cod_shop_big_bandage_cost", "15"), cvarCostBigBandage);
	bind_pcvar_num(create_cvar("cod_shop_small_exp_cost", "6"), cvarCostSmallExp);
	bind_pcvar_num(create_cvar("cod_shop_medium_exp_cost", "14"), cvarCostMediumExp);
	bind_pcvar_num(create_cvar("cod_shop_big_exp_cost", "25"), cvarCostBigExp);
	bind_pcvar_num(create_cvar("cod_shop_random_exp_cost", "15"), cvarCostRandomExp);
	bind_pcvar_num(create_cvar("cod_shop_rocket_cost", "15"), cvarCostRocket);
	bind_pcvar_num(create_cvar("cod_shop_mine_cost", "15"), cvarCostMine);
	bind_pcvar_num(create_cvar("cod_shop_dynamite_cost", "15"), cvarCostDynamite);
	bind_pcvar_num(create_cvar("cod_shop_medkit_cost", "15"), cvarCostMedkit);
	bind_pcvar_num(create_cvar("cod_shop_thunder_cost", "15"), cvarCostThunder);
	bind_pcvar_num(create_cvar("cod_shop_teleport_cost", "30"), cvarCostTeleport);
	bind_pcvar_num(create_cvar("cod_shop_jump_cost", "20"), cvarCostJump);
	bind_pcvar_num(create_cvar("cod_shop_bunny_hop_cost", "25"), cvarCostBunnyHop);
	bind_pcvar_num(create_cvar("cod_shop_silent_cost", "15"), cvarCostSilent);
	bind_pcvar_num(create_cvar("cod_shop_armor_cost", "20"), cvarCostArmor);
	bind_pcvar_num(create_cvar("cod_shop_damage_cost", "35"), cvarCostDamage);
	bind_pcvar_num(create_cvar("cod_shop_invisible_cost", "50"), cvarCostInvisible);

	bind_pcvar_num(create_cvar("cod_shop_durability_amount", "50"), cvarDurabilityAmount);
	bind_pcvar_num(create_cvar("cod_shop_small_bandage_hp", "25"), cvarSmallBandageHP);
	bind_pcvar_num(create_cvar("cod_shop_big_bandage_hp", "75"), cvarBigBandageHP);
	bind_pcvar_num(create_cvar("cod_shop_small_exp", "25"), cvarSmallExp);
	bind_pcvar_num(create_cvar("cod_shop_medium_exp", "75"), cvarMediumExp);
	bind_pcvar_num(create_cvar("cod_shop_big_exp", "150"), cvarBigExp);
	bind_pcvar_num(create_cvar("cod_shop_random_exp_min", "1"), cvarMinRandomExp);
	bind_pcvar_num(create_cvar("cod_shop_random_exp_max", "200"), cvarMaxRandomExp);
	bind_pcvar_num(create_cvar("cod_shop_armor_amount", "100"), cvarArmorAmount);
	bind_pcvar_num(create_cvar("cod_shop_damage_amount", "10"), cvarDamageAmount);

	bind_pcvar_num(get_cvar_pointer("cod_max_durability"), cvarMaxDurability);
}

public cod_end_map()
	mapEnd = true;

public shop_menu(id)
{
	if (!is_user_connected(id) || !cod_check_account(id) || mapEnd) return PLUGIN_HANDLED;

	client_cmd(id, "spk %s", codSounds[SOUND_SELECT]);

	new menuData[128], menuPrice[10], menu = menu_create("\yShop \rMenu\w:", "shop_menu_handle");

	if (cvarMaxDurability && cvarCostRepair) {
		formatex(menuData, charsmax(menuData), "Repair Item \r[\y+%i Durability\r] \wCost:\r %iH", cvarDurabilityAmount, cvarCostRepair);
		formatex(menuPrice, charsmax(menuPrice), "%i#%i", cvarCostRepair, REPAIR);
		menu_additem(menu, menuData, menuPrice);
	}

	if (cvarCostItem) {
		formatex(menuData, charsmax(menuData), "Buy Item \r[\yRandom Item\r] \wCost:\r %iH", cvarCostItem);
		formatex(menuPrice, charsmax(menuPrice), "%i#%i", cvarCostItem, BUY);
		menu_additem(menu, menuData, menuPrice);
	}

	if (cvarCostUpgrade) {
		formatex(menuData, charsmax(menuData), "Upgrade Item \r[\yItem Enhancement\r] \wCost:\r %iH", cvarCostUpgrade);
		formatex(menuPrice, charsmax(menuPrice), "%i#%i", cvarCostUpgrade, UPGRADE);
		menu_additem(menu, menuData, menuPrice);
	}

	if (cvarCostSmallBandage) {
		formatex(menuData, charsmax(menuData), "Small Bandage \r[\y+%i HP\r] \wCost:\r %iH", cvarSmallBandageHP, cvarCostSmallBandage);
		formatex(menuPrice, charsmax(menuPrice), "%i#%i", cvarCostSmallBandage, SMALL_BANDAGE);
		menu_additem(menu, menuData, menuPrice);
	}

	if (cvarCostBigBandage) {
		formatex(menuData, charsmax(menuData), "Big Bandage \r[\y+%i HP\r] \wCost:\r %iH", cvarBigBandageHP, cvarCostBigBandage);
		formatex(menuPrice, charsmax(menuPrice), "%i#%i", cvarCostBigBandage, BIG_BANDAGE);
		menu_additem(menu, menuData, menuPrice);
	}

	if (cvarCostSmallExp) {
		formatex(menuData, charsmax(menuData), "Small Experience \r[\y%i Exp\r] \wCost:\r %iH", cvarSmallExp, cvarCostSmallExp);
		formatex(menuPrice, charsmax(menuPrice), "%i#%i", cvarCostSmallExp, SMALL_EXP);
		menu_additem(menu, menuData, menuPrice);
	}

	if (cvarCostMediumExp) {
		formatex(menuData, charsmax(menuData), "Medium Experience \r[\y%i Exp\r] \wCost:\r %iH", cvarMediumExp, cvarCostMediumExp);
		formatex(menuPrice, charsmax(menuPrice), "%i#%i", cvarCostMediumExp, MEDIUM_EXP);
		menu_additem(menu, menuData, menuPrice);
	}

	if (cvarCostBigExp) {
		formatex(menuData, charsmax(menuData), "Big Experience \r[\y%i Exp\r] \wCost:\r %iH", cvarBigExp, cvarCostBigExp);
		formatex(menuPrice, charsmax(menuPrice), "%i#%i", cvarCostBigExp, BIG_EXP);
		menu_additem(menu, menuData, menuPrice);
	}

	if (cvarCostRandomExp) {
		formatex(menuData, charsmax(menuData), "Random Experience \r[\yRandom %i to %i Exp\r] \wCost:\r %iH", cvarMinRandomExp, cvarMaxRandomExp, cvarCostRandomExp);
		formatex(menuPrice, charsmax(menuPrice), "%i#%i", cvarCostRandomExp, RANDOM_EXP);
		menu_additem(menu, menuData, menuPrice);
	}

	if (cvarCostRocket) {
		formatex(menuData, charsmax(menuData), "Extra Rocket \r[\y+1 Rocket\r] \wCost:\r %iH", cvarCostRocket);
		formatex(menuPrice, charsmax(menuPrice), "%i#%i", cvarCostRocket, ROCKET);
		menu_additem(menu, menuData, menuPrice);
	}

	if (cvarCostMine) {
		formatex(menuData, charsmax(menuData), "Extra Mine \r[\y+1 Mine\r] \wCost:\r %iH", cvarCostMine);
		formatex(menuPrice, charsmax(menuPrice), "%i#%i", cvarCostMine, MINE);
		menu_additem(menu, menuData, menuPrice);
	}

	if (cvarCostDynamite) {
		formatex(menuData, charsmax(menuData), "Extra Dynamite \r[\y+1 Dynamite\r] \wCost:\r %iH", cvarCostDynamite);
		formatex(menuPrice, charsmax(menuPrice), "%i#%i", cvarCostDynamite, DYNAMITE);
		menu_additem(menu, menuData, menuPrice);
	}

	if (cvarCostMedkit) {
		formatex(menuData, charsmax(menuData), "Extra Medkit \r[\y+1 Medkit\r] \wCost:\r %iH", cvarCostMedkit);
		formatex(menuPrice, charsmax(menuPrice), "%i#%i", cvarCostMedkit, MEDKIT);
		menu_additem(menu, menuData, menuPrice);
	}

	if (cvarCostThunder) {
		formatex(menuData, charsmax(menuData), "Extra Lightning \r[\y+1 Lightning\r] \wCost:\r %iH", cvarCostThunder);
		formatex(menuPrice, charsmax(menuPrice), "%i#%i", cvarCostThunder, THUNDER);
		menu_additem(menu, menuData, menuPrice);
	}

	if (cvarCostTeleport) {
		formatex(menuData, charsmax(menuData), "Extra Teleport \r[\y+1 Teleport\r] \wCost:\r %iH", cvarCostTeleport);
		formatex(menuPrice, charsmax(menuPrice), "%i#%i", cvarCostTeleport, TELEPORT);
		menu_additem(menu, menuData, menuPrice);
	}

	if (cvarCostJump) {
		formatex(menuData, charsmax(menuData), "Extra Jump \r[\y+1 Mid-Air Jump\r] \wCost:\r %iH", cvarCostJump);
		formatex(menuPrice, charsmax(menuPrice), "%i#%i", cvarCostJump, JUMP);
		menu_additem(menu, menuData, menuPrice);
	}

	if (cvarCostBunnyHop) {
		formatex(menuData, charsmax(menuData), "Bunny Hop \r[\yAuto BunnyHop\r] \wCost:\r %iH", cvarCostBunnyHop);
		formatex(menuPrice, charsmax(menuPrice), "%i#%i", cvarCostBunnyHop, BUNNY_HOP);
		menu_additem(menu, menuData, menuPrice);
	}

	if (cvarCostSilent) {
		formatex(menuData, charsmax(menuData), "Silent Walk \r[\yNo Footstep Sounds\r] \wCost:\r %iH", cvarCostSilent);
		formatex(menuPrice, charsmax(menuPrice), "%i#%i", cvarCostSilent, SILENT);
		menu_additem(menu, menuData, menuPrice);
	}

	if (cvarCostArmor) {
		formatex(menuData, charsmax(menuData), "Extra Armor \r[\y+%i Armor\r] \wCost:\r %iH", cvarArmorAmount, cvarCostArmor);
		formatex(menuPrice, charsmax(menuPrice), "%i#%i", cvarCostArmor, ARMOR);
		menu_additem(menu, menuData, menuPrice);
	}

	if (cvarCostDamage) {
		formatex(menuData, charsmax(menuData), "More Damage \r[\y+%i Damage\r] \wCost:\r %iH", cvarDamageAmount, cvarCostDamage);
		formatex(menuPrice, charsmax(menuPrice), "%i#%i", cvarCostDamage, DAMAGE);
		menu_additem(menu, menuData, menuPrice);
	}

	if (cvarCostInvisible) {
		formatex(menuData, charsmax(menuData), "Invisibility Cloak \r[\yFull Invisibility\r] \wCost:\r %iH", cvarCostInvisible);
		formatex(menuPrice, charsmax(menuPrice), "%i#%i", cvarCostInvisible, INVISIBLE);
		menu_additem(menu, menuData, menuPrice);
	}

	menu_setprop(menu, MPROP_EXITNAME, "Exit");
	menu_setprop(menu, MPROP_BACKNAME, "Back");
	menu_setprop(menu, MPROP_NEXTNAME, "Next");

	menu_display(id, menu);

	return PLUGIN_HANDLED;
}

public shop_menu_handle(id, menu, item)
{
	if (!is_user_connected(id) || !cod_check_account(id) || mapEnd) return PLUGIN_HANDLED;

	if (item == MENU_EXIT) {
		client_cmd(id, "spk %s", codSounds[SOUND_EXIT]);

		menu_destroy(menu);

		return PLUGIN_HANDLED;
	}

	client_cmd(id, "spk %s", codSounds[SOUND_SELECT]);

	new itemData[16], dataParts[2][8], itemAccess, itemCallback;

	menu_item_getinfo(menu, item, itemAccess, itemData, charsmax(itemData), _, _, itemCallback);

	menu_destroy(menu);

	explode(itemData, '#', dataParts, sizeof(dataParts), charsmax(dataParts[]));

	new price = str_to_num(dataParts[0]);
	item = str_to_num(dataParts[1]);

	if (cod_get_user_honor(id) < price) {
		cod_print_chat(id, "You don't have enough^x03 Honor^x01!");

		return PLUGIN_HANDLED;
	}

	shopSlot[id] = 1;

	if (item == REPAIR || item == UPGRADE) {
		if (cod_get_user_items_count(id) == 2) {
			// Two items: ask which one to repair / upgrade
			new itemName[MAX_NAME], menuData[MAX_NAME + 16], slotMenu = menu_create(item == REPAIR ? "\yRepair which \ritem\w?" : "\yUpgrade which \ritem\w?", "shop_slot_handle");

			for (new slot = 1; slot <= 2; slot++) {
				cod_get_item_name(cod_get_user_slot_item(id, slot), itemName, charsmax(itemName));

				formatex(menuData, charsmax(menuData), "%s \d[slot %i]", itemName, slot);

				menu_additem(slotMenu, menuData);
			}

			menu_setprop(slotMenu, MPROP_EXITNAME, "Exit");

			pendingOption[id] = item;
			pendingPrice[id] = price;

			menu_display(id, slotMenu);

			return PLUGIN_HANDLED;
		}

		if (!cod_get_user_slot_item(id, 1) && cod_get_user_slot_item(id, 2)) shopSlot[id] = 2;
	}

	return shop_purchase(id, item, price);
}

public shop_slot_handle(id, menu, item)
{
	menu_destroy(menu);

	if (!is_user_connected(id) || !cod_check_account(id) || mapEnd || item == MENU_EXIT) return PLUGIN_HANDLED;

	if (cod_get_user_honor(id) < pendingPrice[id]) {
		cod_print_chat(id, "You don't have enough^x03 Honor^x01!");

		return PLUGIN_HANDLED;
	}

	shopSlot[id] = item + 1;

	return shop_purchase(id, pendingOption[id], pendingPrice[id]);
}

public shop_purchase(id, item, price)
{
	switch (item) {
		case REPAIR: {
			if (!cod_get_user_slot_item(id, shopSlot[id])) {
				cod_print_chat(id, "You don't have any item^x01!");

				return PLUGIN_HANDLED;
			}

			if (cod_get_slot_item_durability(id, shopSlot[id]) >= cod_max_item_durability()) {
				cod_print_chat(id, "Your item is already fully^x03 repaired^x01!");

				return PLUGIN_HANDLED;
			}

			cod_print_chat(id, "You bought^x03 +%i^x01 item durability!", cvarDurabilityAmount);

			if (cod_get_slot_item_durability(id, shopSlot[id]) + cvarDurabilityAmount >= cod_max_item_durability()) {
				cod_set_slot_item_durability(id, shopSlot[id], cod_max_item_durability());

				cod_print_chat(id, "Your item is now fully repaired!");
			} else {
				cod_set_slot_item_durability(id, shopSlot[id], cod_get_slot_item_durability(id, shopSlot[id]) + cvarDurabilityAmount);

				cod_print_chat(id, "Your item's durability is now^x03 %i^x01!", cod_get_slot_item_durability(id, shopSlot[id]));
			}
		} case BUY: {
			cod_print_chat(id, "You bought a^x03 Random Item^x01!");

			cod_set_user_item(id, RANDOM);
		} case UPGRADE: {
			if (!cod_get_user_slot_item(id, shopSlot[id])) {
				cod_print_chat(id, "You don't have any item!");

				return PLUGIN_HANDLED;
			}

			if (!cod_upgrade_user_slot_item(id, shopSlot[id], 1)) {
				cod_print_chat(id, "Your item can't be upgraded!");

				return PLUGIN_HANDLED;
			}

			cod_print_chat(id, "You bought an^x03 Item Upgrade^x01!");

			if (!cod_upgrade_user_slot_item(id, shopSlot[id])) {
				cod_print_chat(id, "Your item can no longer be^x03 upgraded^x01. No honor was charged.");

				return PLUGIN_HANDLED;
			}
		} case SMALL_BANDAGE: {
			if (cod_get_user_health(id, 1) >= cod_get_user_max_health(id)) {
				cod_print_chat(id, "You are already fully^x03 healed^x01!");

				return PLUGIN_HANDLED;
			}

			cod_set_user_health(id, cod_get_user_health(id, 1) + cvarSmallBandageHP);

			cod_print_chat(id, "You bought a^x03 Small Bandage^x01!");
		} case BIG_BANDAGE: {
			if (cod_get_user_health(id, 1) >= cod_get_user_max_health(id)) {
				cod_print_chat(id, "You are already fully^x03 healed^x01!");

				return PLUGIN_HANDLED;
			}

			cod_set_user_health(id, cod_get_user_health(id, 1) + cvarBigBandageHP);

			cod_print_chat(id, "You bought a^x03 Big Bandage^x01!");
		} case SMALL_EXP: {
			cod_print_chat(id, "You bought^x03 Small Experience^x01!");

			cod_print_chat(id, "You got^x03 %i^x01 exp!", cvarSmallExp);

			cod_set_user_exp(id, cvarSmallExp);
		} case MEDIUM_EXP: {
			cod_print_chat(id, "You bought^x03 Medium Experience^x01!");

			cod_print_chat(id, "You got^x03 %i^x01 exp!", cvarMediumExp);

			cod_set_user_exp(id, cvarMediumExp);
		} case BIG_EXP: {
			cod_print_chat(id, "You bought^x03 Big Experience^x01!");

			cod_print_chat(id, "You got^x03 %i^x01 exp!", cvarBigExp);

			cod_set_user_exp(id, cvarBigExp);
		} case RANDOM_EXP: {
			new randomExp = random_num(cvarMinRandomExp, cvarMaxRandomExp);

			cod_print_chat(id, "You bought^x03 Random Experience^x01!");

			cod_print_chat(id, "You got^x03 %i^x01 exp!", randomExp);

			cod_set_user_exp(id, randomExp);
		} case ROCKET: {
			cod_print_chat(id, "You bought an^x03 Extra Rocket^x01!");

			cod_add_user_rockets(id, 1, ADDITIONAL);
		} case MINE: {
			cod_print_chat(id, "You bought an^x03 Extra Mine^x01!");

			cod_add_user_mines(id, 1, ADDITIONAL);
		} case DYNAMITE: {
			cod_print_chat(id, "You bought an^x03 Extra Dynamite^x01!");

			cod_add_user_dynamites(id, 1, ADDITIONAL);
		} case MEDKIT: {
			cod_print_chat(id, "You bought an^x03 Extra Medkit^x01!");

			cod_add_user_medkits(id, 1, ADDITIONAL);
		} case THUNDER: {
			cod_print_chat(id, "You bought an^x03 Extra Lightning^x01!");

			cod_add_user_thunders(id, 1, ADDITIONAL);
		} case TELEPORT: {
			if (cod_get_user_teleports(id) == FULL) {
				cod_print_chat(id, "You already have an unlimited^x03 Teleport^x01!");

				return PLUGIN_HANDLED;
			}

			cod_print_chat(id, "You bought an^x03 Extra Teleport^x01!");

			cod_add_user_teleports(id, 1, ADDITIONAL);
		} case JUMP: {
			if (cod_get_user_multijumps(id) >= 3) {
				cod_print_chat(id, "You can have at most^x03 3 Extra Jumps^x01!");

				return PLUGIN_HANDLED;
			}

			cod_print_chat(id, "You bought an^x03 Extra Jump^x01!");

			cod_add_user_multijumps(id, 1, ROUND);
		} case BUNNY_HOP: {
			if (cod_get_user_bunnyhop(id)) {
				cod_print_chat(id, "You already have^x03 Bunny Hop^x01!");

				return PLUGIN_HANDLED;
			}

			cod_print_chat(id, "You bought^x03 BunnyHop^x01!");

			cod_set_user_bunnyhop(id, 1, ROUND);
		} case SILENT: {
			if (cod_get_user_footsteps(id)) {
				cod_print_chat(id, "You already have^x03 Silent Walk^x01!");

				return PLUGIN_HANDLED;
			}

			cod_print_chat(id, "You bought^x03 Silent Walk^x01!");

			cod_set_user_footsteps(id, 1, ROUND);
		} case ARMOR: {
			if (cod_get_user_armor(id) >= 300) {
				cod_print_chat(id, "You can have at most^x03 300 Armor^x01!");

				return PLUGIN_HANDLED;
			}

			cod_print_chat(id, "You bought^x03 Extra Armor^x01!");

			cod_add_user_armor(id, cvarArmorAmount);
		} case DAMAGE: {
			if (get_bit(id, damageBonus)) {
				cod_print_chat(id, "You already bought^x03 More Damage^x01 this round!");

				return PLUGIN_HANDLED;
			}

			cod_print_chat(id, "You bought^x03 More Damage^x01!");

			set_bit(id, damageBonus);
		} case INVISIBLE: {
			if (!cod_get_user_render(id)) {
				cod_print_chat(id, "You already have^x03 Full Invisibility^x01!");

				return PLUGIN_HANDLED;
			}

			cod_print_chat(id, "You bought the^x03 Invisibility Cloak^x01!");

			cod_set_user_render(id, 0, ROUND);
		}
	}

	cod_add_user_honor(id, -price);

	return PLUGIN_HANDLED;
}

public cod_damage_post(attacker, victim, weapon, Float:damage, damageBits, hitPlace)
	if (get_bit(attacker, damageBonus)) cod_inflict_damage(attacker, victim, float(cvarDamageAmount), 0.0, damageBits);

public cod_new_round()
	for (new i = 1; i <= MAX_PLAYERS; i++) rem_bit(i, damageBonus);

stock explode(const string[], const character, output[][], const maxParts, const maxLength)
{
	new currentPart = 0, stringLength = strlen(string), currentLength = 0;

	do {
		currentLength += (1 + copyc(output[currentPart++], maxLength, string[currentLength], character));
	} while(currentLength < stringLength && currentPart < maxParts);
}