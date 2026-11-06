#include <amxmodx>
#include <fakemeta>
#include <cod>

#define PLUGIN "CoD Item Noz Komandosa"
#define VERSION "1.0"
#define AUTHOR "O'Zone"

#define NAME        "Commando's Knife"
#define DESCRIPTION "Instant kill with knife (RMB)."

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	cod_register_item(NAME, DESCRIPTION);
}

public cod_item_damage_attacker(attacker, victim, weapon, &Float:damage, damageBits, hitPlace)
{
	if (weapon == CSW_KNIFE && !(pev(attacker, pev_button) & IN_ATTACK)) {
        damage = cod_kill_player(attacker, victim, damageBits);
    }
}
