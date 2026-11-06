#include <amxmodx>
#include <cod>

#define PLUGIN "CoD Item Stroj Ninjy"
#define VERSION "1.0"
#define AUTHOR "O'Zone"

#define NAME        "Ninja Suit"
#define DESCRIPTION "You are invisible while standing still with a knife"

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	cod_register_item(NAME, DESCRIPTION);
}

public cod_item_enabled(id, value)
	cod_set_user_render(id, 0, ITEM, RENDER_STAND, 1<<CSW_KNIFE);