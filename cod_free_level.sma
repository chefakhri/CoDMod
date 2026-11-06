#include <amxmodx>
#include <cod>

#define PLUGIN "CoD Free Level"
#define VERSION "1.0"
#define AUTHOR "O'Zone"

new const commandLevel[][] = { "freelvl", "say /freelvl", "say /dajlvl", "say /dodajlvl" };

new cvarFreeLevel, cvarFreeLevelMode;

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	for (new i; i < sizeof commandLevel; i++) register_clcmd(commandLevel[i], "add_level");

	bind_pcvar_num(create_cvar("cod_free_level", "30"), cvarFreeLevel);
	bind_pcvar_num(create_cvar("cod_free_level_mode", "1"), cvarFreeLevelMode);

	set_task(30.0, "show_info", _, _, _, "b");
}

public show_info()
{
	for (new id = 1; id <= MAX_PLAYERS; id++) {
		if (!is_user_connected(id) || is_user_hltv(id) || is_user_bot(id)) {
			continue;
		}


		if (cod_get_user_level(id) < cvarFreeLevel){
			cod_show_hud(id, TYPE_DHUD, 0, 200, 200, -1.0, 0.25, 0, 1.0, 10.0, 1.0, 1.0, "[STARTER PACK] Type /freelvl to get a FREE LVL!");
			cod_print_chat(id, "Type^x03 /freelvl^x01 to get a FREE LVL!");
		}
	}
}

public add_level(id)
{
	if (cod_get_user_level(id) < cvarFreeLevel) {
		if (cvarFreeLevelMode) {
			cod_set_user_exp(id, cod_get_level_exp(cvarFreeLevel - 1));

			cod_print_chat(id, "You received experience for^x03 %i^x01 starter levels.", cvarFreeLevel);
		} else {
			cod_set_user_exp(id, cod_get_level_exp(cvarFreeLevel - 1) - cod_get_user_exp(id));

			cod_print_chat(id, "You received^x03 %i^x01 starter level.", cvarFreeLevel);
		}
	} else {
		cod_print_chat(id, "You already got free levels for this class or your level is already too high!");
	}

	return PLUGIN_HANDLED;
}