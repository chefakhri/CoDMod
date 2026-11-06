#include <amxmodx>
#include <cod>

#define PLUGIN "CoD Item Krwawe Naboje"
#define VERSION "1.0"
#define AUTHOR "O'Zone"

#define NAME        "Bloody Bullets"
#define DESCRIPTION "The lower your health, the more damage you deal (-1% health = +1% damage)"

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	cod_register_item(NAME, DESCRIPTION);
}

public cod_item_damage_attacker(attacker, victim, weapon, &Float:damage, damageBits, hitPlace)
{
	new health = cod_get_user_health(attacker, 1), maxHealth = cod_get_user_max_health(attacker);

	if (health < maxHealth) {
        damage *= (1.0 + 1.0 - float(health / maxHealth));
    }
}
