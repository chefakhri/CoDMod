#include <amxmodx>
#include <cod>

#define PLUGIN "CoD Item Autodestrukcja"
#define VERSION "1.0"
#define AUTHOR "O'Zone"

#define NAME        "Self Destruct"
#define DESCRIPTION "Instant death for you and the enemies close to you"

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	cod_register_item(NAME, DESCRIPTION);
}

public cod_item_skill_used(id)
	cod_make_explosion(id, 300, 1, 300.0, 999.9, 0.0, 1);
