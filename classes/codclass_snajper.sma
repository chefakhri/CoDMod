#include <amxmodx>
#include <fakemeta>
#include <cod>

#define PLUGIN "CoD Class Snajper"
#define VERSION "1.0"
#define AUTHOR "O'Zone"

#define NAME         "Sniper"
#define DESCRIPTION  "Deals 130 percent damage with AWP (+int) and has a 1/2 chance to instantly kill with knife (RMB)."
#define FRACTION     "Basic"
#define WEAPONS      (1<<CSW_AWP)|(1<<CSW_DEAGLE)
#define HEALTH       0
#define INTELLIGENCE 0
#define STRENGTH     0
#define STAMINA      20
#define CONDITION    10

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	cod_register_class(NAME, DESCRIPTION, FRACTION, WEAPONS, HEALTH, INTELLIGENCE, STRENGTH, STAMINA, CONDITION);
}

public cod_class_damage_attacker(attacker, victim, weapon, &Float:damage, damageBits, hitPlace)
{
	if (weapon == CSW_KNIFE && pev(attacker, pev_button) & IN_ATTACK2 && cod_percent_chance(50)) {
        damage = cod_kill_player(attacker, victim, damageBits);
    }

	if (weapon == CSW_AWP && damageBits & DMG_BULLET) {
        damage = damage * (1.3 + (cod_get_user_intelligence(attacker) * 0.2 / 100.0));
    }
}