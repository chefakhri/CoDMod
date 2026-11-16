#include <amxmodx>
#include <fakemeta>
#include <hamsandwich>
#include <cod>

#define PLUGIN "CoD Item Skrzydla Archaniola"
#define VERSION "1.0"
#define AUTHOR "O'Zone"

#define NAME        "Archangel's Wings"
#define DESCRIPTION "You have lower gravity. Using the item mid-jump slams you to the ground, causing an earthquake"

#define TASK_FALL	3921

new fallProtection;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	cod_register_item(NAME, DESCRIPTION);

	RegisterHam(Ham_TakeDamage, "player", "player_damage_pre", 0);
}

public cod_item_enabled(id, value)
	cod_set_user_gravity(id, 0.4, ITEM);

public cod_item_skill_used(id)
{
	if (!(pev(id, pev_flags) & FL_ONGROUND)) {
		new Float:velocity[3];

		pev(id, pev_velocity, velocity);

		velocity[2] = -800.0;

		set_bit(id, fallProtection);

		set_pev(id, pev_velocity, velocity);

		cod_screen_shake(id);

		cod_make_explosion(id, 200, 0, 200.0, 250.0);

		// The protection lasts until the slam's landing (see player_damage_pre). The timer is only a
		// safety limit, e.g. for landing in water; restart it so an earlier slam's timer can't end
		// this slam's protection while the player is still falling.
		remove_task(id + TASK_FALL);
		set_task(3.0, "disable_protection", id + TASK_FALL);
	}
}

public client_disconnected(id)
{
	rem_bit(id, fallProtection);
	remove_task(id + TASK_FALL);
}

public disable_protection(id)
{
	id -= TASK_FALL;

	rem_bit(id, fallProtection);
}

public player_damage_pre(victim, inflictor, attacker, Float:damage, damageBits)
{
	if (get_bit(victim, fallProtection) && damageBits & DMG_FALL) {
		// Only the slam's own landing is protected
		rem_bit(victim, fallProtection);
		remove_task(victim + TASK_FALL);

		return HAM_SUPERCEDE;
	}

	return HAM_IGNORED;
}
