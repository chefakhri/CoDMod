#include <amxmodx>
#include <cod>

#define PLUGIN "CoD Class Przyklad Awanse"
#define VERSION "1.0"
#define AUTHOR "O'Zone"

#define NAME         "Test"
#define DESCRIPTION  "Has 2 mines. 10 percent chance to instantly kill the enemy when hit with USP."
#define FRACTION     "Basic"
#define WEAPONS      (1<<CSW_M4A1)|(1<<CSW_USP)
#define HEALTH       10
#define INTELLIGENCE 0
#define STRENGTH     0
#define STAMINA      10
#define CONDITION    5

#define NAME2        "Trained Test"
#define DESCRIPTION2 "Has 3 mines. 10 percent chance to instantly kill the enemy when hit with USP."
#define HEALTH2      15

#define NAME3        "Elite Test"
#define DESCRIPTION3 "Has 4 mines. 20 percent chance to instantly kill the enemy when hit with USP."
#define HEALTH3      15
#define CONDITION3   10

#define NAME4        "Master Test"
#define DESCRIPTION4 "Has 5 mines. 20 percent chance to instantly kill the enemy when hit with USP."
#define WEAPONS4     (1<<CSW_M4A1)|(1<<CSW_AK47)|(1<<CSW_USP)
#define HEALTH4      15
#define CONDITION4   20

new classPromotion[MAX_PLAYERS + 1];

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);

	cod_register_class(NAME, DESCRIPTION, FRACTION, WEAPONS, HEALTH, INTELLIGENCE, STRENGTH, STAMINA, CONDITION);

	cod_register_promotion(NAME2, DESCRIPTION2, NAME, 25, PROMOTION_FIRST, .health = HEALTH2);
	cod_register_promotion(NAME3, DESCRIPTION2, NAME, 50, PROMOTION_SECOND, .health = HEALTH3, .condition = CONDITION3);
	cod_register_promotion(NAME4, DESCRIPTION2, NAME, 150, PROMOTION_THIRD, WEAPONS4, .health = HEALTH4, .condition = CONDITION4);
}

public cod_class_enabled(id, promotion)
{
	classPromotion[id] = promotion;

	switch (promotion) {
		case PROMOTION_NONE: cod_set_user_mines(id, 2, CLASS);
		case PROMOTION_FIRST: cod_set_user_mines(id, 3, CLASS);
		case PROMOTION_SECOND: cod_set_user_mines(id, 4, CLASS);
		case PROMOTION_THIRD: cod_set_user_mines(id, 5, CLASS);
	}
}

public cod_class_skill_used(id)
	cod_use_user_mine(id);

public cod_class_damage_attacker(attacker, victim, weapon, &Float:damage, damageBits, hitPlace)
{
	if (weapon == CSW_USP && damageBits & DMG_BULLET) {
		new kill = false;

		switch (classPromotion[attacker]) {
			case PROMOTION_NONE, PROMOTION_FIRST: kill = cod_percent_chance(10);
			case PROMOTION_SECOND, PROMOTION_THIRD: kill = cod_percent_chance(20);
		}

		if (kill) {
			damage = cod_kill_player(attacker, victim, damageBits);
		}
	}
}
