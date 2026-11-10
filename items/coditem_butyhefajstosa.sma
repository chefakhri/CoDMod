#include <amxmodx>
#include <hamsandwich>
#include <cod>

#define PLUGIN "CoD Item Buty Hefajstosa"
#define VERSION "1.0"
#define AUTHOR "O'Zone"

#define NAME        "Boots of Hephaestus"
#define DESCRIPTION "You take no fall damage. You get +%s condition"
#define RANDOM_MIN  20
#define RANDOM_MAX  25
#define UPGRADE_MIN -2
#define UPGRADE_MAX 4
#define VALUE_MAX   100

new itemActive, itemValue[MAX_PLAYERS + 1];

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	cod_register_item(NAME, DESCRIPTION, RANDOM_MIN, RANDOM_MAX);

	RegisterHam(Ham_TakeDamage, "player", "player_take_damage", 0);
}

public cod_item_enabled(id, value)
{
	set_bit(id, itemActive);

	itemValue[id] = value;

	cod_add_user_bonus_condition(id, itemValue[id]);
}

public cod_item_disabled(id)
{
	rem_bit(id, itemActive);

	cod_add_user_bonus_condition(id, -itemValue[id]);
}

public cod_item_upgrade(id)
{
	cod_add_user_bonus_condition(id, -itemValue[id]);

	cod_random_upgrade(itemValue[id], UPGRADE_MIN, UPGRADE_MAX, .valueMax = VALUE_MAX);

	cod_add_user_bonus_condition(id, itemValue[id]);
}

// Fall damage comes from the world, not from a player, so cod_damage_pre never sees it:
// block it directly in the damage hook.
public player_take_damage(victim, inflictor, attacker, Float:damage, damageBits)
{
	if (!(damageBits & DMG_FALL) || !get_bit(victim, itemActive)) return HAM_IGNORED;

	SetHamParamFloat(4, 0.0);

	return HAM_SUPERCEDE;
}

public cod_item_value(id)
	return itemValue[id];