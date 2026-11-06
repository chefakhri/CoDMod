#include <amxmodx>
#include <cod>

#define PLUGIN "CoD Item Nano Kamizelka"
#define VERSION "1.0"
#define AUTHOR "O'Zone"

#define NAME        "Nano Vest"
#define DESCRIPTION "You are immune to rockets, mines, dynamite, lightning and other damaging bonuses."

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	cod_register_item(NAME, DESCRIPTION);
}

public cod_item_enabled(id, value)
	cod_set_user_resistance(id, true, ITEM);