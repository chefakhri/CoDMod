#include <amxmodx>
#include <fakemeta>
#include <cod>

#define PLUGIN "CoD Class Grabiezca"
#define VERSION "1.0"
#define AUTHOR "O'Zone"

#define NAME         "Plunderer"
#define DESCRIPTION  "25 percent chance to steal the victim's item. Full magazine after a kill."
#define FRACTION     "Basic"
#define WEAPONS      (1<<CSW_FAMAS)|(1<<CSW_USP)
#define HEALTH       10
#define INTELLIGENCE 0
#define STRENGTH     5
#define STAMINA      0
#define CONDITION    15

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	cod_register_class(NAME, DESCRIPTION, FRACTION, WEAPONS, HEALTH, INTELLIGENCE, STRENGTH, STAMINA, CONDITION);
}

public cod_class_kill(killer, victim, hitPlace)
{
	cod_refill_ammo(killer);

	new slot = pick_steal_slot(killer, victim);

	if (slot && cod_percent_chance(25)) {
		show_question(killer, victim, slot);
	}
}

// Which of the victim's items to steal: one the killer doesn't have yet, preferring one that fits
// a free slot of the killer; if none fits, one at random (it replaces the killer's item in that slot)
pick_steal_slot(killer, victim)
{
	new candidates[2], count, freeCandidates[2], freeCount, item;

	for (new slot = 1; slot <= 2; slot++) {
		item = cod_get_user_slot_item(victim, slot);

		if (!item || cod_user_has_item(killer, item)) continue;

		candidates[count++] = slot;

		if (!cod_get_user_slot_item(killer, cod_get_item_target_slot(item))) freeCandidates[freeCount++] = slot;
	}

	if (freeCount) return freeCandidates[random(freeCount)];

	return count ? candidates[random(count)] : 0;
}

public show_question(id, victim, slot)
{
	new menuTitle[64], itemName[64], tempId[8];

	cod_get_item_name(cod_get_user_slot_item(victim, slot), itemName, charsmax(itemName));

	formatex(tempId, charsmax(tempId), "%i#%i", victim, slot);

	format(menuTitle, charsmax(menuTitle), "\yDo you want to steal the item: \r%s\y?", itemName);

	new menu = menu_create(menuTitle, "show_question_handle");

	menu_additem(menu, "Yes", tempId);
	menu_setprop(menu, MPROP_EXITNAME, "No");

	menu_display(id, menu);
}

public show_question_handle(id, menu, item)
{
	if (item) {
		client_cmd(id, "spk %s", codSounds[SOUND_EXIT]);

		menu_destroy(menu);

		return;
	}

	client_cmd(id, "spk %s", codSounds[SOUND_SELECT]);

	new itemData[8], victimData[4], slotData[4], victim, slot, itemAccess, menuCallback;

	menu_item_getinfo(menu, item, itemAccess, itemData, charsmax(itemData), _, _, menuCallback);

	strtok(itemData, victimData, charsmax(victimData), slotData, charsmax(slotData), '#');

	victim = str_to_num(victimData);
	slot = str_to_num(slotData);

	menu_destroy(menu);

	if (!is_user_connected(victim) || (slot != 1 && slot != 2)) return;

	new itemValue, item = cod_get_user_slot_item(victim, slot, itemValue);

	if (!item || cod_user_has_item(id, item)) return;

	new thiefName[32];

	get_user_name(id, thiefName, charsmax(thiefName));

	cod_print_chat(victim, "Your item was stolen by^x03 %s^x01.", thiefName);

	cod_set_user_slot_item(victim, slot);
	cod_set_user_item(id, item, itemValue, true);
}