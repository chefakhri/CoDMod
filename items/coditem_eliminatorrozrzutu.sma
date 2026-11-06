#include <amxmodx>
#include <cod>

#define PLUGIN "CoD Item Eliminator Rozrzutu"
#define VERSION "1.0"
#define AUTHOR "O'Zone"

#define NAME        "Recoil Eliminator"
#define DESCRIPTION "You have no recoil with any weapon"

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	cod_register_item(NAME, DESCRIPTION);
}

public cod_item_enabled(id, value)
	cod_set_user_recoil_eliminator(id, true, ITEM);