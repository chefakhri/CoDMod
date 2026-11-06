#include <amxmodx>
#include <cod>

#define PLUGIN "CoD Item Farbowany Lis"
#define VERSION "1.0"
#define AUTHOR "O'Zone"

#define NAME        "Wolf in Sheep's Clothing"
#define DESCRIPTION "You have a 1/%s chance to respawn at the enemy spawn. You wear the enemy uniform."
#define RANDOM_MIN  3
#define RANDOM_MAX  4
#define VALUE_MIN   2

new itemValue[MAX_PLAYERS + 1];

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	cod_register_item(NAME, DESCRIPTION, RANDOM_MIN, RANDOM_MAX);
}

public cod_item_enabled(id, value)
{
	itemValue[id] = value;

	cod_set_user_model(id, true, ITEM);
}

public cod_item_value(id)
	return itemValue[id];

public cod_item_upgrade(id)
	cod_random_upgrade(itemValue[id], .valueMin = VALUE_MIN);

public cod_item_spawned(id)
{
	if (random_num(1, itemValue[id]) == 1) {
		cod_teleport_to_spawn(id, 1);
	}
}
