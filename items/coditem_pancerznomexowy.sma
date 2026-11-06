#include <amxmodx>
#include <cod>

#define PLUGIN "CoD Item Pancerz Nomexowy"
#define VERSION "1.0"
#define AUTHOR "O'Zone"

#define NAME        "Nomex Armor"
#define DESCRIPTION "You have a 1/%s chance to reflect a bullet that hits you"
#define RANDOM_MIN  5
#define RANDOM_MAX  7
#define VALUE_MIN   3

new itemValue[MAX_PLAYERS + 1];

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	cod_register_item(NAME, DESCRIPTION, RANDOM_MIN, RANDOM_MAX);
}

public cod_item_enabled(id, value)
	itemValue[id] = value;

public cod_item_value(id)
	return itemValue[id];

public cod_item_upgrade(id)
	cod_random_upgrade(itemValue[id], .valueMin = VALUE_MIN);

public cod_item_damage_victim(attacker, victim, weapon, &Float:damage, damageBits, hitPlace)
{
	if (damageBits & DMG_BULLET && random_num(1, itemValue[victim]) == 1) {
		damage = COD_BLOCK;

		cod_inflict_damage(victim, attacker, damage, 0.0, DMG_BULLET);
	}
}
