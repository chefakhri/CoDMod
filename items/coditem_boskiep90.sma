#include <amxmodx>
#include <cod>

#define PLUGIN "CoD Item Boskie P90"
#define VERSION "1.0"
#define AUTHOR "O'Zone"

#define NAME        "Divine P90"
#define DESCRIPTION "You get a P90 with unlimited ammo and no recoil"

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	cod_register_item(NAME, DESCRIPTION);
}

public cod_item_enabled(id, value)
{
	cod_give_weapon(id, CSW_P90);

	cod_set_user_unlimited_ammo(id, true, ITEM, 1<<CSW_P90);
	cod_set_user_recoil_eliminator(id, true, ITEM, 1<<CSW_P90);
}

public cod_item_disabled(id)
	cod_take_weapon(id, CSW_P90);
