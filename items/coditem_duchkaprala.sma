#include <amxmodx>
#include <fakemeta>
#include <cod>

#define PLUGIN "CoD Item Duch Kaprala"
#define VERSION "1.0"
#define AUTHOR "O'Zone"

#define TASK_ITEM 90342

#define NAME        "Corporal's Ghost"
#define DESCRIPTION "When activated, for %ss you can walk through walls"
#define RANDOM_MIN  7
#define RANDOM_MAX  8
#define UPGRADE_MIN -2
#define UPGRADE_MAX 3
#define VALUE_MAX   15

new itemValue[MAX_PLAYERS + 1], itemUsed;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	cod_register_item(NAME, DESCRIPTION, RANDOM_MIN, RANDOM_MAX);
}

public cod_item_enabled(id, value)
{
	rem_bit(id, itemUsed);

	itemValue[id] = value;
}

public cod_item_disabled(id)
	cod_set_user_noclip(id, false, ITEM);

public cod_item_upgrade(id)
	cod_random_upgrade(itemValue[id], UPGRADE_MIN, UPGRADE_MAX, .valueMax = VALUE_MAX);

public cod_item_value(id)
	return itemValue[id];

public cod_item_spawned(id, respawn)
{
	cod_set_user_noclip(id, false, ITEM);

	if (!respawn) {
		rem_bit(id, itemUsed);
	}
}

public cod_item_skill_used(id)
{
	if (get_bit(id, itemUsed)) {
		cod_show_hud(id, TYPE_DHUD, 0, 255, 210, -1.0, 0.45, 0, 0.0, 1.25, 0.0, 0.0, "You can use Corporal's Ghost only once per round!");

		return;
	}

	set_bit(id, itemUsed);

	cod_make_bartimer(id, itemValue[id]);
	cod_set_user_noclip(id, true, ITEM);

	set_task(float(itemValue[id]), "deactivate_item", id + TASK_ITEM);
}

public deactivate_item(id)
{
	id -= TASK_ITEM;

	cod_set_user_noclip(id, false, ITEM);
}
