#include <amxmodx>
#include <cod>

#define PLUGIN "CoD Item Kucacz"
#define VERSION "1.0"
#define AUTHOR "O'Zone"

#define NAME        "Croucher"
#define DESCRIPTION "You are practically invisible while crouching"

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	cod_register_item(NAME, DESCRIPTION);
}

public cod_item_enabled(id, value)
	cod_set_user_render(id, 20, ITEM, RENDER_DUCK);