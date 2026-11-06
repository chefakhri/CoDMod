#include <amxmodx>
#include <cod>

#define PLUGIN "CoD Item Krolicza Lapka"
#define VERSION "1.0"
#define AUTHOR "O'Zone"

#define NAME        "Rabbit's Foot"
#define DESCRIPTION "You have automatic BunnyHop - hold space"

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	cod_register_item(NAME, DESCRIPTION);
}

public cod_item_enabled(id, value)
	cod_set_user_bunnyhop(id, true, ITEM);
