#include <amxmodx>
#include <cod>
#include <fakemeta>

#define PLUGIN "CoD Item Przeklete Naboje"
#define VERSION "1.0"
#define AUTHOR "O'Zone"

#define NAME        "Cursed Bullets"
#define DESCRIPTION "You have a 1/%s chance to launch the enemy into the air on hit"
#define RANDOM_MIN  6
#define RANDOM_MAX  9
#define VALUE_MIN   3

new itemValue[MAX_PLAYERS + 1];

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	cod_register_item(NAME, DESCRIPTION, RANDOM_MIN, RANDOM_MAX);
}

public cod_item_enabled(id, value)
	itemValue[id] = value;

public cod_item_upgrade(id)
	return cod_random_upgrade(itemValue[id], .valueMin = VALUE_MIN);

public cod_item_value(id)
	return itemValue[id];

public cod_item_damage_attacker(attacker, victim, weapon, &Float:damage, damageBits, hitPlace)
{
	if (damageBits & DMG_BULLET && random_num(1, itemValue[attacker]) == 1) {
		new Float:velocity[3];

		velocity[0] = 0.0;
		velocity[1] = 0.0;
		velocity[2] = 0.0;

		pev(victim, pev_velocity, velocity);

		velocity[2] = random_float(400.0, 600.0);

		set_pev(victim, pev_velocity, velocity);
	}
}