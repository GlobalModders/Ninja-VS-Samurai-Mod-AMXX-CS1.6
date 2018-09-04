#include <amxmodx>
#include <amxmisc>
#include <engine>
#include <fakemeta>
#include <hamsandwich>
#include <cstrike>
#include <gamemaster>
#include <orpheu>
#include <fakemeta_util>
#include <xs>

#define CAM_CLASS	"monster_cam"

#define	SKILL_1_CD_TASKID	15463
#define	SKILL_2_CD_TASKID	15464
#define	SKILL_3_CD_TASKID	15465

new g_iCamera[32], Float: origin[32][3];
new g_iInterface[32], g_iSkills[32], bool: g_bNoMana[32][5];
new skill_1_cd[32], skill_2_cd[32], skill_3_cd[32];
new Float: skill_1_cd_time[32], Float: skill_2_cd_time[32], Float: skill_3_cd_time[32];
new bool: g_iSkillActive_1[32];
//new g_totalSkills = 2;
new Float: CheckTime2[32];
new Float: mana[32];
new bool: g_iAttacking[32];
new g_iModel[32];

#define SetBits(%1,%2)    ( %1 |=    1 << ( %2 & 31 ) )
#define ClearBits(%1,%2)  ( %1 &= ~( 1 << ( %2 & 31 ) ) )
#define FBitSet(%1,%2)    ( %1 &     1 << ( %2 & 31 ) )

new isAlive;
new seqInitiation;
new shouldStopAnimation;

const PLAYER_IDLE_SEQ = 99;
const PLAYER_WALK_SEQ = 118;
const PLAYER_RUN_SEQ = 4;
//const PLAYER_RUN_1_SEQ = 6;
const PLAYER_JUMP_SEQ = 7;
const PLAYER_LEAP_SEQ = 13;
const PLAYER_ATTACK1_SEQ = 31;


enum PlayerAnim
{
    PLAYER_IDLE,
    PLAYER_WALK,
    PLAYER_JUMP,
    PLAYER_SUPERJUMP,
    PLAYER_DIE,
    PLAYER_ATTACK1,
    PLAYER_ATTACK1_RIGHT,
    PLAYER_SMALL_FLINCH,
    PLAYER_LARGE_FLINCH,
    PLAYER_RELOAD,
    PLAYER_HOLDBOMB
};

enum
{
	ACT_RESET = 0,		// Set m_Activity to this invalid value to force a reset to m_IdealActivity
	ACT_IDLE = 1,
	ACT_GUARD,
	ACT_WALK,
	ACT_RUN,
	ACT_FLY,				// Fly (and flap if appropriate)
	ACT_SWIM,
	ACT_HOP,				// vertical jump
	ACT_LEAP,				// long forward jump
	ACT_FALL,
	ACT_LAND,
	ACT_STRAFE_LEFT,
	ACT_STRAFE_RIGHT,
	ACT_ROLL_LEFT,			// tuck and roll, left
	ACT_ROLL_RIGHT,			// tuck and roll, right
	ACT_TURN_LEFT,			// turn quickly left (stationary)
	ACT_TURN_RIGHT,			// turn quickly right (stationary)
	ACT_CROUCH,				// the act of crouching down from a standing position
	ACT_CROUCHIDLE,			// holding body in crouched position (loops)
	ACT_STAND,				// the act of standing from a crouched position
	ACT_USE,
	ACT_SIGNAL1,
	ACT_SIGNAL2,
	ACT_SIGNAL3,
	ACT_TWITCH,
	ACT_COWER,
	ACT_SMALL_FLINCH,
	ACT_BIG_FLINCH,
	ACT_RANGE_ATTACK1,
	ACT_RANGE_ATTACK2,
	ACT_MELEE_ATTACK1,
	ACT_MELEE_ATTACK2,
	ACT_RELOAD,
	ACT_ARM,				// pull out gun, for instance
	ACT_DISARM,				// reholster gun
	ACT_EAT,				// monster chowing on a large food item (loop)
	ACT_DIESIMPLE,
	ACT_DIEBACKWARD,
	ACT_DIEFORWARD,
	ACT_DIEVIOLENT,
	ACT_BARNACLE_HIT,		// barnacle tongue hits a monster
	ACT_BARNACLE_PULL,		// barnacle is lifting the monster ( loop )
	ACT_BARNACLE_CHOMP,		// barnacle latches on to the monster
	ACT_BARNACLE_CHEW,		// barnacle is holding the monster in its mouth ( loop )
	ACT_SLEEP,
	ACT_INSPECT_FLOOR,		// for active idles, look at something on or near the floor
	ACT_INSPECT_WALL,		// for active idles, look at something directly ahead of you ( doesn't HAVE to be a wall or on a wall )
	ACT_IDLE_ANGRY,			// alternate idle animation in which the monster is clearly agitated. (loop)
	ACT_WALK_HURT,			// limp  (loop)
	ACT_RUN_HURT,			// limp  (loop)
	ACT_HOVER,				// Idle while in flight
	ACT_GLIDE,				// Fly (don't flap)
	ACT_FLY_LEFT,			// Turn left in flight
	ACT_FLY_RIGHT,			// Turn right in flight
	ACT_DETECT_SCENT,		// this means the monster smells a scent carried by the air
	ACT_SNIFF,				// this is the act of actually sniffing an item in front of the monster
	ACT_BITE,				// some large monsters can eat small things in one bite. This plays one time, EAT loops.
	ACT_THREAT_DISPLAY,		// without attacking, monster demonstrates that it is angry. (Yell, stick out chest, etc )
	ACT_FEAR_DISPLAY,		// monster just saw something that it is afraid of
	ACT_EXCITED,			// for some reason, monster is excited. Sees something he really likes to eat, or whatever.
	ACT_SPECIAL_ATTACK1,	// very monster specific special attacks.
	ACT_SPECIAL_ATTACK2,	
	ACT_COMBAT_IDLE,		// agitated idle.
	ACT_WALK_SCARED,
	ACT_RUN_SCARED,
	ACT_VICTORY_DANCE,		// killed a player, do a victory dance.
	ACT_DIE_HEADSHOT,		// die, hit in head. 
	ACT_DIE_CHESTSHOT,		// die, hit in chest
	ACT_DIE_GUTSHOT,		// die, hit in gut
	ACT_DIE_BACKSHOT,		// die, hit in back
	ACT_FLINCH_HEAD,
	ACT_FLINCH_CHEST,
	ACT_FLINCH_STOMACH,
	ACT_FLINCH_LEFTARM,
	ACT_FLINCH_RIGHTARM,
	ACT_FLINCH_LEFTLEG,
	ACT_FLINCH_RIGHTLEG,
};

public plugin_precache()
{
	precache_model("models/camera.mdl")
	precache_model("models/nvs/interface/interface_v1.mdl");
	precache_model("models/nvs/interface/skills.mdl");
	precache_model("models/StarWars/skill_1_cooldown.mdl");
	precache_model("models/StarWars/skill_2_cooldown.mdl");
	precache_model("models/StarWars/skill_3_cooldown.mdl");
	precache_model("models/player/nvs_player_base/nvs_player_base.mdl");
	precache_model("models/player/nvs_ryoku/nvs_ryoku.mdl");
}

public plugin_init()
{
	register_plugin("Cameras", "1.0", "GlobalModders.net");
	register_clcmd("amx_viewcamera", "view_cam");
	register_clcmd("amx_createcam", "create_cam");
	register_clcmd("+skill_1", "press_skill_1");
	register_clcmd("+skill_2", "press_skill_2");
	register_clcmd("+skill_3", "press_skill_3");
	
	RegisterHam(Ham_Spawn, "player", "fw_PlayerSpawn_Post", 1);
	RegisterHam(Ham_TakeDamage, "player", "fw_PlayerTakeDamage_Post", 1);
	
	register_forward(FM_AddToFullPack, "fw_addtofullpack", 1);
	
	OrpheuRegisterHook(OrpheuGetFunction("SetAnimation", "CBasePlayer"), "Player_SetAnimation", OrpheuHookPre);
}

public fw_PlayerSpawn_Post(id)
{
	//fm_strip_user_weapons(id);
	
	if(is_user_alive(id))
		GM_Set_PlayerModel(id, "nvs_player_base");
	
	set_pev(id, pev_renderamt, 0);
	set_pev(id, pev_rendermode, kRenderTransAlpha);
	
	mana[id] = 100.0;
	if(is_valid_ent(g_iInterface[id])) {
		set_pev(g_iInterface[id], pev_body, floatround((pev(id, pev_health)/100.0) * 20.0));
		set_pev(g_iInterface[id], pev_skin, floatround((mana[id]/100.0) * 20.0));
		set_pev(g_iSkills[id], pev_body, 0);
		client_cmd(id, "amx_viewcamera");
	}
	else
		client_cmd(id, "amx_createcam");
}

public fw_PlayerTakeDamage_Post(Victim, idInflictor, iAttacker, Float: flDamage, bitsDamageType)
{
	if(is_valid_ent(g_iInterface[Victim])) {
		set_pev(g_iInterface[Victim], pev_body, floatround((pev(Victim, pev_health)/100.0) * 20.0));
	}
}

public mana_add(id, Float: value)
{
	mana[id] += value;
	if(is_valid_ent(g_iInterface[id])) {
		set_pev(g_iInterface[id], pev_skin, floatround((mana[id]/100.0) * 20.0));
	}
	
	if(mana[id] < 5.0 && !g_bNoMana[id][0]) {
		set_pev(g_iSkills[id], pev_body, pev(g_iSkills[id], pev_body) + get_body(0, 2));
		g_bNoMana[id][0] = true;
	}
	else if(mana[id] >= 5.0 && g_bNoMana[id][0]) {
		set_pev(g_iSkills[id], pev_body, pev(g_iSkills[id], pev_body) - get_body(0, 2));
		g_bNoMana[id][0] = false;
	}
	
	if(mana[id] < 15.0 && !g_bNoMana[id][1]) {
		set_pev(g_iSkills[id], pev_body, pev(g_iSkills[id], pev_body) + get_body(1, 2));
		g_bNoMana[id][1] = true;
	}
	else if(mana[id] >= 15.0 && g_bNoMana[id][1]) {
		set_pev(g_iSkills[id], pev_body, pev(g_iSkills[id], pev_body) - get_body(1, 2));
		g_bNoMana[id][1] = false;
	}
	
	if(mana[id] < 30.0 && !g_bNoMana[id][2]) {
		set_pev(g_iSkills[id], pev_body, pev(g_iSkills[id], pev_body) + get_body(2, 2));
		g_bNoMana[id][2] = true;
	}
	else if(mana[id] >= 30.0 && g_bNoMana[id][2]) {
		set_pev(g_iSkills[id], pev_body, pev(g_iSkills[id], pev_body) - get_body(2, 2));
		g_bNoMana[id][2] = false;
	}
}

public create_cam(id)
{
	create_camera(id);
}

public view_cam(id)
{
	view_camera(id);
}

stock create_camera(id)
{
	new Float: v_angle[3], Float: angles[3];
	entity_get_vector(id, EV_VEC_origin, origin[id]);
	entity_get_vector(id, EV_VEC_v_angle, v_angle);
	entity_get_vector(id, EV_VEC_angles, angles);
	
	new ent = create_entity("info_target");

	entity_set_string(ent, EV_SZ_classname, "JJG75_Camera");

	entity_set_int(ent, EV_INT_solid, 0);
	entity_set_int(ent, EV_INT_movetype, MOVETYPE_NOCLIP);
	entity_set_edict(ent, EV_ENT_owner, id);
	entity_set_model(ent, "models/camera.mdl");

	new Float:mins[3];
	mins[0] = -1.0;
	mins[1] = -1.0;
	mins[2] = -1.0;

	new Float:maxs[3];
	maxs[0] = 1.0;
	maxs[1] = 1.0;
	maxs[2] = 1.0;

	entity_set_size(ent, mins, maxs);

	entity_set_origin(ent, origin[id]);
	entity_set_vector(ent, EV_VEC_v_angle, v_angle);
	entity_set_vector(ent, EV_VEC_angles, angles);

	g_iCamera[id] = ent;
	
	new ent2 = create_entity("info_target");

	entity_set_string(ent2, EV_SZ_classname, "interface");

	entity_set_int(ent2, EV_INT_solid, 0);
	entity_set_int(ent2, EV_INT_movetype, MOVETYPE_NOCLIP);
	entity_set_edict(ent2, EV_ENT_owner, id);
	entity_set_model(ent2, "models/nvs/interface/interface_v1.mdl");

	entity_set_origin(ent2, origin[id]);
	entity_set_vector(ent2, EV_VEC_v_angle, v_angle);
	entity_set_vector(ent2, EV_VEC_angles, angles);

	g_iInterface[id] = ent2;
	set_pev(g_iInterface[id], pev_body, floatround((pev(id, pev_health)/100.0) * 20.0));
	set_pev(g_iInterface[id], pev_skin, floatround((mana[id]/100.0) * 20.0));
	
	new ent3 = create_entity("info_target");

	entity_set_string(ent3, EV_SZ_classname, "player_model");

	entity_set_int(ent3, EV_INT_solid, 0);
	entity_set_int(ent3, EV_INT_movetype, MOVETYPE_FOLLOW);
	entity_set_edict(ent3, EV_ENT_owner, id);
	entity_set_edict(ent3, EV_ENT_aiment, id);
	entity_set_model(ent3, "models/player/nvs_ryoku/nvs_ryoku.mdl");

	g_iModel[id] = ent3;
	
	new ent4 = create_entity("info_target");

	entity_set_string(ent4, EV_SZ_classname, "skills");

	entity_set_int(ent4, EV_INT_solid, 0);
	entity_set_int(ent4, EV_INT_movetype, MOVETYPE_NOCLIP);
	entity_set_edict(ent4, EV_ENT_owner, id);
	entity_set_model(ent4, "models/nvs/interface/skills.mdl");

	entity_set_origin(ent4, origin[id]);
	entity_set_vector(ent4, EV_VEC_v_angle, v_angle);
	entity_set_vector(ent4, EV_VEC_angles, angles);

	g_iSkills[id] = ent4;
	
	view_cam(id);

	return 1;
}

stock view_camera(id)
{
	if(is_valid_ent(g_iCamera[id]))
	{
		attach_view(id, g_iCamera[id]);
		return 1;
	}
	return 0;
}

public press_skill_1(id)
{
	if(!is_valid_ent(skill_1_cd[id]) && mana[id] >= 5.0) {
		new ent = create_entity("info_target");

		entity_set_string(ent, EV_SZ_classname, "skill_1_cd");

		entity_set_int(ent, EV_INT_solid, 0);
		entity_set_int(ent, EV_INT_movetype, MOVETYPE_NOCLIP);
		entity_set_edict(ent, EV_ENT_owner, id);
		entity_set_model(ent, "models/StarWars/skill_1_cooldown.mdl");
		
		entity_set_float(ent, EV_FL_frame, 0.0);
		entity_set_float(ent, EV_FL_framerate, 0.0);
		
		set_pev(ent, pev_rendermode, kRenderTransAlpha);
		set_pev(ent, pev_renderamt, 200.0);

		skill_1_cd[id] = ent;
		
		mana_add(id, -5.0);
		
		if(is_valid_ent(g_iSkills[id]) && mana[id] >= 5.0) {
			set_pev(g_iSkills[id], pev_body, pev(g_iSkills[id], pev_body) + get_body(0, 1));
			set_task(1.0, "release_skill_1", id);
		}
		
		skill_1_cd_time[id] = 3.0;
		set_task(0.1, "skill_1_cooldown", id + SKILL_1_CD_TASKID);
	}
}

public release_skill_1(id)
{
	if(is_valid_ent(g_iSkills[id])) {
		set_pev(g_iSkills[id], pev_body, pev(g_iSkills[id], pev_body) - get_body(0, 1));
		if(pev(g_iSkills[id], pev_body) < 0)
			set_pev(g_iSkills[id], pev_body, 0);
	}
}

public skill_1_cooldown(id)
{
	id = id - SKILL_1_CD_TASKID;
	skill_1_cd_time[id] -= 0.1;
	if(skill_1_cd_time[id] <= 0.0) {
		client_print(id, print_chat, "Skill_1 Ready!");
		if(is_valid_ent(skill_1_cd[id])) {
			engfunc(EngFunc_RemoveEntity, skill_1_cd[id]);
			skill_1_cd[id] = 0;
		}
	}
	else {
		if(is_valid_ent(skill_1_cd[id])) {
			entity_set_float(skill_1_cd[id], EV_FL_frame, 254.0 - ((skill_1_cd_time[id] / 3.0) * 254.0));
		}
		set_task(0.1, "skill_1_cooldown", id + SKILL_1_CD_TASKID);
	}
}

public press_skill_2(id)
{
	if(!is_valid_ent(skill_2_cd[id]) && mana[id] >= 15.0) {
		new ent = create_entity("info_target");

		entity_set_string(ent, EV_SZ_classname, "skill_2_cd");

		entity_set_int(ent, EV_INT_solid, 0);
		entity_set_int(ent, EV_INT_movetype, MOVETYPE_NOCLIP);
		entity_set_edict(ent, EV_ENT_owner, id);
		entity_set_model(ent, "models/StarWars/skill_2_cooldown.mdl");
		
		entity_set_float(ent, EV_FL_frame, 0.0);
		entity_set_float(ent, EV_FL_framerate, 0.0);
		
		set_pev(ent, pev_rendermode, kRenderTransAlpha);
		set_pev(ent, pev_renderamt, 200.0);

		skill_2_cd[id] = ent;
		
		mana_add(id, -15.0);
		
		if(is_valid_ent(g_iSkills[id]) && mana[id] >= 15.0) {
			set_pev(g_iSkills[id], pev_body, pev(g_iSkills[id], pev_body) + get_body(1, 1));
			set_task(1.0, "release_skill_2", id);
		}
		
		skill_2_cd_time[id] = 15.0;
		set_task(0.1, "skill_2_cooldown", id + SKILL_2_CD_TASKID);
	}
}

public release_skill_2(id)
{
	if(is_valid_ent(g_iSkills[id])) {
		set_pev(g_iSkills[id], pev_body, pev(g_iSkills[id], pev_body) - get_body(1, 1));
		if(pev(g_iSkills[id], pev_body) < 0)
			set_pev(g_iSkills[id], pev_body, 0);
	}
}

public skill_2_cooldown(id)
{
	id = id - SKILL_2_CD_TASKID;
	skill_2_cd_time[id] -= 0.1;
	if(skill_2_cd_time[id] <= 0.0) {
		client_print(id, print_chat, "Skill_2 Ready!");
		if(is_valid_ent(skill_2_cd[id])) {
			engfunc(EngFunc_RemoveEntity, skill_2_cd[id]);
			skill_2_cd[id] = 0;
		}
	}
	else {
		if(is_valid_ent(skill_2_cd[id])) {
			entity_set_float(skill_2_cd[id], EV_FL_frame, 254.0 - ((skill_2_cd_time[id] / 15.0) * 254.0));
		}
		set_task(0.1, "skill_2_cooldown", id + SKILL_2_CD_TASKID);
	}
}

public press_skill_3(id)
{
	if(!is_valid_ent(skill_3_cd[id]) && mana[id] >= 30.0) {
		new ent = create_entity("info_target");

		entity_set_string(ent, EV_SZ_classname, "skill_3_cd");

		entity_set_int(ent, EV_INT_solid, 0);
		entity_set_int(ent, EV_INT_movetype, MOVETYPE_NOCLIP);
		entity_set_edict(ent, EV_ENT_owner, id);
		entity_set_model(ent, "models/StarWars/skill_3_cooldown.mdl");
		
		entity_set_float(ent, EV_FL_frame, 0.0);
		entity_set_float(ent, EV_FL_framerate, 0.0);
		
		set_pev(ent, pev_rendermode, kRenderTransAlpha);
		set_pev(ent, pev_renderamt, 200.0);

		skill_3_cd[id] = ent;
		
		mana_add(id, -30.0);
		
		if(is_valid_ent(g_iSkills[id]) && mana[id] >= 30.0) {
			set_pev(g_iSkills[id], pev_body, pev(g_iSkills[id], pev_body) + get_body(2, 1));
			set_task(1.0, "release_skill_3", id);
		}
		
		skill_3_cd_time[id] = 60.0;
		set_task(0.1, "skill_3_cooldown", id + SKILL_3_CD_TASKID);
	}
}

public release_skill_3(id)
{
	if(is_valid_ent(g_iSkills[id])) {
		set_pev(g_iSkills[id], pev_body, pev(g_iSkills[id], pev_body) - get_body(2, 1));
		if(pev(g_iSkills[id], pev_body) < 0)
			set_pev(g_iSkills[id], pev_body, 0);
	}
}

public skill_3_cooldown(id)
{
	id = id - SKILL_3_CD_TASKID;
	skill_3_cd_time[id] -= 0.1;
	if(skill_3_cd_time[id] <= 0.0) {
		client_print(id, print_chat, "Skill_3 Ready!");
		if(is_valid_ent(skill_3_cd[id])) {
			engfunc(EngFunc_RemoveEntity, skill_3_cd[id]);
			skill_3_cd[id] = 0;
		}
	}
	else {
		if(is_valid_ent(skill_3_cd[id])) {
			entity_set_float(skill_3_cd[id], EV_FL_frame, 254.0 - ((skill_3_cd_time[id] / 60.0) * 254.0));
		}
		set_task(0.1, "skill_3_cooldown", id + SKILL_3_CD_TASKID);
	}
}
/*
public client_PostThink(id)
{
	set_pdata_int(id, 73, 6, 5);
	set_pdata_int(id, 74, 6, 5);
	set_pev(id, pev_gaitsequence, 0);
	
}
*/
public client_PreThink(id)
{
	/*
	if(g_iCamera[id])
	{
		new Float: iOrigin[3], Float: CamOrigin[3];
		entity_get_vector(id, EV_VEC_origin, iOrigin);
		new Float: v_angle[3], Float: angles[3];
		entity_get_vector(id, EV_VEC_angles, angles);
		entity_get_vector(id, EV_VEC_v_angle, v_angle);
		for(new Float: i = 0.0; i <= 200.0; i += 0.1)
		{
			CamOrigin[0] = -i * floatcos(v_angle[1], degrees) * floatcos(v_angle[0], degrees);
			CamOrigin[1] = -i * floatsin(v_angle[1], degrees) * floatcos(v_angle[0], degrees);
			CamOrigin[2] = i * floatsin(v_angle[0], degrees);
			CamOrigin[0] += iOrigin[0];
			CamOrigin[1] += iOrigin[1];
			CamOrigin[2] += iOrigin[2];
			if(PointContents(CamOrigin) == CONTENTS_SOLID || PointContents(CamOrigin) == CONTENTS_SKY)
				break;
		}
		entity_set_origin(g_iCamera[id], CamOrigin);
		entity_set_vector(g_iCamera[id], EV_VEC_angles, v_angle);
		entity_set_vector(g_iCamera[id], EV_VEC_v_angle, v_angle);
	}
	*/
	
	if(g_iCamera[id])
	{
		new Float: iOrigin[3], Float: CamOrigin[3], Float: voffsets[3], Float: forvec[3], Float: rightvec[3];
		entity_get_vector(id, EV_VEC_origin, iOrigin);
		entity_get_vector(id, EV_VEC_view_ofs, voffsets);
		new Float: v_angle[3];
		entity_get_vector(id, EV_VEC_v_angle, v_angle);
		/*
		for(new i = 0; i <= 200; i++)
		{
			xs_vec_add(iOrigin, voffsets, CamOrigin);
			velocity_by_aim(g_iCamera[id], -i , forvec);
			
			xs_vec_add(CamOrigin, forvec, CamOrigin);
			//CamOrigin[2] += 36.0;
			if(PointContents(CamOrigin) == CONTENTS_SOLID || PointContents(CamOrigin) == CONTENTS_SKY)
				break;
		}
		*/
		xs_vec_add(iOrigin, voffsets, CamOrigin);
		velocity_by_aim(g_iCamera[id], -80 , forvec);
		
		vector_to_angle(forvec, rightvec);
		angle_vector(rightvec, ANGLEVECTOR_RIGHT, rightvec);
		xs_vec_mul_scalar(rightvec, -16.0, rightvec);
		
		xs_vec_add(CamOrigin, forvec, CamOrigin);
		xs_vec_add(CamOrigin, rightvec, CamOrigin);
		
		engfunc(EngFunc_TraceLine, iOrigin, CamOrigin, IGNORE_MONSTERS, id, 0) 
		static Float: flFraction;
		get_tr2(0, TR_flFraction, flFraction);
		if(flFraction != 1.0) // adjust camera place if close to a wall 
		{
			xs_vec_sub(CamOrigin, forvec, CamOrigin);
			xs_vec_sub(CamOrigin, rightvec, CamOrigin);
			
			forvec[0] *= flFraction;
			forvec[1] *= flFraction;
			forvec[2] *= flFraction;
			rightvec[0] *= flFraction;
			rightvec[1] *= flFraction;
			rightvec[2] *= flFraction;
			xs_vec_add(CamOrigin, forvec, CamOrigin);
			xs_vec_add(CamOrigin, rightvec, CamOrigin);
		}
		
		new Float: real_angles[3];
		real_angles[0] = -v_angle[0];
		real_angles[1] = v_angle[1];
		real_angles[2] = v_angle[2];
		
		message_begin(MSG_ONE_UNRELIABLE,SVC_TEMPENTITY,{0,0,0},id);
		write_byte(TE_ELIGHT);
		write_short(g_iInterface[id]);
		engfunc(EngFunc_WriteCoord, CamOrigin[0]);
		engfunc(EngFunc_WriteCoord, CamOrigin[1]);
		engfunc(EngFunc_WriteCoord, CamOrigin[2]);
		write_coord(10);
		write_byte(255);
		write_byte(255);
		write_byte(255);
		write_byte(1);
		write_coord(0);
		message_end();
		
		entity_set_origin(g_iInterface[id], CamOrigin);
		entity_set_vector(g_iInterface[id], EV_VEC_angles, real_angles);
		
		entity_set_origin(g_iSkills[id], CamOrigin);
		entity_set_vector(g_iSkills[id], EV_VEC_angles, real_angles);
		
		if(is_valid_ent(skill_1_cd[id])) {
			entity_set_origin(skill_1_cd[id], CamOrigin);
			entity_set_vector(skill_1_cd[id], EV_VEC_angles, real_angles);
		}
		
		if(is_valid_ent(skill_2_cd[id])) {
			entity_set_origin(skill_2_cd[id], CamOrigin);
			entity_set_vector(skill_2_cd[id], EV_VEC_angles, real_angles);
		}
		
		if(is_valid_ent(skill_3_cd[id])) {
			entity_set_origin(skill_3_cd[id], CamOrigin);
			entity_set_vector(skill_3_cd[id], EV_VEC_angles, real_angles);
		}
		
		entity_set_origin(g_iCamera[id], CamOrigin);
		entity_set_vector(g_iCamera[id], EV_VEC_angles, v_angle);
		entity_set_vector(g_iCamera[id], EV_VEC_v_angle, v_angle);
		//entity_set_vector(g_iInterface[id], EV_VEC_v_angle, v_angle);
	}
}

public fw_addtofullpack(es_handle,e,ent,host,hostflags,player,pSet)
{
    if(host == ent)
   	{
		new Float: angle[3];
		pev(host, pev_angles, angle);
		angle[0] *= -1.0;
      	set_es(es_handle, ES_Angles, angle);
    }
    return FMRES_IGNORED;
}

stock get_body(iSkill, iActive)
{
	new iPevBody = power(3, iSkill) * iActive;
	return iPevBody;
}

public OrpheuHookReturn:Player_SetAnimation (const player, PlayerAnim:playerAnim)
{
	#define ACT_RANGE_ATTACK1   28
   
	// Linux extra offsets
	#define extra_offset_player   5
	#define extra_offset_animating   4
   
	// CBaseAnimating
	#define m_flFrameRate      36
	#define m_flGroundSpeed      37
	#define m_flLastEventCheck   38
	#define m_fSequenceFinished   39
	#define m_fSequenceLoops   40
	#define m_szAnimExtention	1968
   
	// CBaseMonster
	#define m_Activity      73
	#define m_IdealActivity      74
   
	// CBasePlayer
	#define m_flLastAttackTime   220
	
	#define Length2D(%0) (floatsqroot(%0[0] * %0[0] + %0[1] * %0[1]))
	
	new animDesired;
	new Float: speed, Float: velocity[3];
	new szAnim[64]
	new AnimExt[64];
	//copy(AnimExt, sizeof(AnimExt), "knife");
	get_pdata_string(player, m_szAnimExtention, AnimExt, sizeof(AnimExt), 0, extra_offset_animating);
	
	pev(player, pev_velocity, velocity);
	speed = Length2D(velocity);
	
	if (pev(player, pev_flags) & FL_FROZEN)
	{
		speed = 0.0;
		playerAnim = PLAYER_IDLE;
	}

	switch (playerAnim) {
		case PLAYER_JUMP: {
			if(speed > 330.0)
				set_pdata_int(player, m_IdealActivity, ACT_LEAP, extra_offset_player);
			else
				set_pdata_int(player, m_IdealActivity, ACT_HOP, extra_offset_player);
		}
			
		case PLAYER_SUPERJUMP: {
			set_pdata_int(player, m_IdealActivity, ACT_LEAP, extra_offset_player);
		}
			
		case PLAYER_DIE: {
			set_pdata_int(player, m_IdealActivity, ACT_DIESIMPLE, extra_offset_player);
		}
		
		case PLAYER_ATTACK1: {
			switch(get_pdata_int(player, m_Activity, extra_offset_player))
			{
				case ACT_HOVER: {}
				case ACT_SWIM: {}
				case ACT_HOP: {}
				case ACT_LEAP: {}
				case ACT_DIESIMPLE:
					set_pdata_int(player, m_IdealActivity, get_pdata_int(player, m_Activity, extra_offset_player), extra_offset_player);
					
				default:
					set_pdata_int(player, m_IdealActivity, ACT_RANGE_ATTACK1, extra_offset_player);
					
			}
		}
		case PLAYER_IDLE: {
			set_pdata_int(player, m_IdealActivity, ACT_IDLE, extra_offset_player);
		}
		case PLAYER_WALK: {
			if (!(pev(player, pev_flags) & FL_ONGROUND) && (get_pdata_int(player, m_Activity, extra_offset_player) == ACT_HOP ||
			get_pdata_int(player, m_Activity, extra_offset_player) == ACT_LEAP)) {
				set_pdata_int(player, m_IdealActivity, get_pdata_int(player, m_Activity, extra_offset_player), extra_offset_player);
			}
			else if ( pev(player, pev_waterlevel) > 1 ) {
				if (speed == 0.0)
					set_pdata_int(player, m_IdealActivity, ACT_HOVER, extra_offset_player);
				else
					set_pdata_int(player, m_IdealActivity, ACT_SWIM, extra_offset_player);
			}
			else {
				set_pdata_int(player, m_IdealActivity, ACT_WALK, extra_offset_player);
			}
		}
	}
	
	switch (get_pdata_int(player, m_IdealActivity, extra_offset_player)) {
		case ACT_IDLE: {
			if (get_pdata_int(player, m_Activity, extra_offset_player) != ACT_RANGE_ATTACK1 || get_pdata_int(player, m_fSequenceFinished, extra_offset_player))
			{
				if (pev(player, pev_flags) & FL_DUCKING)	// crouching
					copy(szAnim, sizeof(szAnim), "crouch_aim_");
				else
					copy(szAnim, sizeof(szAnim), "ref_aim_");
				strcat(szAnim, AnimExt, sizeof(szAnim));
				animDesired = lookup_sequence(player, szAnim);
				if (animDesired == -1)
					animDesired = 0;
				set_pdata_int(player, m_Activity, ACT_WALK, extra_offset_player);
			}
			else
			{
				animDesired = pev(player, pev_sequence);
			}
			if ((pev(player, pev_flags) & FL_ONGROUND))
				set_pev(player, pev_gaitsequence, LookupActivity(ACT_IDLE));
		}
		case ACT_HOVER: {
			if (get_pdata_int(player, m_Activity, extra_offset_player) != ACT_RANGE_ATTACK1 || get_pdata_int(player, m_fSequenceFinished, extra_offset_player))
			{
				if (pev(player, pev_flags) & FL_DUCKING)	// crouching
					copy(szAnim, sizeof(szAnim), "crouch_aim_");
				else
					copy(szAnim, sizeof(szAnim), "ref_aim_");
				
				if(speed > 330.0) {
					strcat(szAnim, "run_", sizeof(szAnim));
					set_pev(player, pev_gaitsequence, LookupActivity(ACT_LEAP));
				}
				else if(speed != 0.0) {
					strcat(szAnim, "walk_", sizeof(szAnim));
					set_pev(player, pev_gaitsequence, LookupActivity(ACT_HOP));
				}
				else
					set_pev(player, pev_gaitsequence, LookupActivity(ACT_HOP));
				
				strcat(szAnim, AnimExt, sizeof(szAnim));
				animDesired = lookup_sequence(player, szAnim);
				if (animDesired == -1)
					animDesired = 0;
				set_pdata_int(player, m_Activity, ACT_WALK, extra_offset_player);
			}
			else
			{
				animDesired = pev(player, pev_sequence);
			}
		}
		case ACT_LEAP: {
			if (get_pdata_int(player, m_Activity, extra_offset_player) != ACT_RANGE_ATTACK1 || get_pdata_int(player, m_fSequenceFinished, extra_offset_player))
			{
				if (pev(player, pev_flags) & FL_DUCKING)	// crouching
					copy(szAnim, sizeof(szAnim), "crouch_aim_");
				else
					copy(szAnim, sizeof(szAnim), "ref_aim_");
				
				strcat(szAnim, "run_", sizeof(szAnim));
				
				strcat(szAnim, AnimExt, sizeof(szAnim));
				animDesired = lookup_sequence(player, szAnim);
				if (animDesired == -1)
					animDesired = 0;
				set_pdata_int(player, m_Activity, ACT_WALK, extra_offset_player);
			}
			else
			{
				animDesired = pev(player, pev_sequence);
			}
			set_pev(player, pev_gaitsequence, LookupActivity(ACT_LEAP));
		}
		case ACT_SWIM: {}
		case ACT_HOP: {
			if (get_pdata_int(player, m_Activity, extra_offset_player) != ACT_RANGE_ATTACK1 || get_pdata_int(player, m_fSequenceFinished, extra_offset_player))
			{
				if (pev(player, pev_flags) & FL_DUCKING)	// crouching
					copy(szAnim, sizeof(szAnim), "crouch_aim_");
				else
					copy(szAnim, sizeof(szAnim), "ref_aim_");
				
				strcat(szAnim, "walk_", sizeof(szAnim));
				
				strcat(szAnim, AnimExt, sizeof(szAnim));
				animDesired = lookup_sequence(player, szAnim);
				if (animDesired == -1)
					animDesired = 0;
				set_pdata_int(player, m_Activity, ACT_WALK, extra_offset_player);
			}
			else
			{
				animDesired = pev(player, pev_sequence);
			}
			set_pev(player, pev_gaitsequence, LookupActivity(ACT_HOP));
		}
		case ACT_DIESIMPLE: {}

		case ACT_RANGE_ATTACK1: {
			if (pev(player, pev_flags) & FL_DUCKING)	// crouching
				copy(szAnim, sizeof(szAnim), "crouch_shoot_");
			else
				copy(szAnim, sizeof(szAnim), "ref_shoot_");
			
			if(speed == 0.0 && (pev(player, pev_flags) & FL_ONGROUND))
				strcat(szAnim, "idle_", sizeof(szAnim));
			
			strcat(szAnim, AnimExt, sizeof(szAnim));
			animDesired = lookup_sequence(player, szAnim);
			if (animDesired == -1)
				animDesired = 0;

			if ( pev(player, pev_sequence) != animDesired || !get_pdata_int(player, m_fSequenceLoops, extra_offset_player))
			{
				set_pev(player, pev_frame, 0.0);
			}
			
			if (!get_pdata_int(player, m_fSequenceLoops, extra_offset_player))
			{
				set_pev(player, pev_effects, pev(player,pev_effects) | EF_NOINTERP);
			}
			
			set_pdata_int(player, m_Activity, get_pdata_int(player, m_IdealActivity, extra_offset_player), extra_offset_player);
			
			set_pev(player, pev_sequence, animDesired);
			set_pev(player, pev_frame, 0.0);
			ResetSequenceInfo(player);
			return OrpheuSupercede;
		}
		
		case ACT_WALK: {
			if (get_pdata_int(player, m_Activity, extra_offset_player) != ACT_RANGE_ATTACK1 || get_pdata_int(player, m_fSequenceFinished, extra_offset_player))
			{
				if (pev(player, pev_flags) & FL_DUCKING)	// crouching
					copy(szAnim, sizeof(szAnim), "crouch_aim_");
				else
					copy(szAnim, sizeof(szAnim), "ref_aim_");
				
				if(pev(player, pev_gaitsequence) == PLAYER_RUN_SEQ)
					strcat(szAnim, "run_", sizeof(szAnim));
				else if(pev(player, pev_gaitsequence) == PLAYER_WALK_SEQ)
					strcat(szAnim, "walk_", sizeof(szAnim));
				
				strcat(szAnim, AnimExt, sizeof(szAnim));
				animDesired = lookup_sequence(player, szAnim);
				if (animDesired == -1)
					animDesired = 0;
				set_pdata_int(player, m_Activity, ACT_WALK, extra_offset_player);
			}
			else
			{
				animDesired = pev(player, pev_sequence);
			}
		}
		
		default: {
			if (get_pdata_int(player, m_Activity, extra_offset_player) == get_pdata_int(player, m_IdealActivity, extra_offset_player)) {
				return OrpheuSupercede;
			}
			
			set_pdata_int(player, m_Activity, get_pdata_int(player, m_IdealActivity, extra_offset_player), extra_offset_player);
			
			animDesired = LookupActivity(get_pdata_int(player, m_Activity, extra_offset_player));
			// Already using the desired animation?
			if (pev(player, pev_sequence) == animDesired) {
				return OrpheuSupercede;
			}
			
			set_pev(player, pev_gaitsequence, PLAYER_IDLE_SEQ);
			set_pev(player, pev_sequence, animDesired);
			set_pev(player, pev_frame, 0.0);
			ResetSequenceInfo(player);
			return OrpheuSupercede;
		}
	}
	
	if(get_pdata_int(player, m_IdealActivity, extra_offset_player) == ACT_WALK && (pev(player, pev_flags) & FL_ONGROUND)) {
		if (pev(player, pev_flags) & FL_DUCKING)
		{
			if (speed == 0.0)
			{
				set_pev(player, pev_gaitsequence, LookupActivity(ACT_CROUCHIDLE));
				// pev->gaitsequence	= LookupActivity( ACT_CROUCH );
			}
			else
			{
				set_pev(player, pev_gaitsequence, LookupActivity(ACT_CROUCH));
			}
		}
		else if (speed > 330.0)
		{
			client_print(player, print_chat, "here");
			set_pev(player, pev_gaitsequence, LookupActivity(ACT_RUN));
		}
		else if (speed > 0.0)
		{
			set_pev(player, pev_gaitsequence, LookupActivity(ACT_WALK));
		}
		else
		{
			// pev->gaitsequence	= LookupActivity( ACT_WALK );
			set_pev(player, pev_gaitsequence, LookupActivity(ACT_IDLE));
		}
	}
	
	// Already using the desired animation?
	if (pev(player, pev_sequence) == animDesired) {
		return OrpheuSupercede;
	}
	

	//ALERT( at_console, "Set animation to %d\n", animDesired );
	// Reset to first frame of desired animation
	set_pev(player, pev_sequence, animDesired);
	set_pev(player, pev_frame, 0.0);
	ResetSequenceInfo(player);
	
	return OrpheuSupercede;
}

stock LookupActivity(const activity)
{
	switch(activity) {
		case ACT_IDLE:
			return PLAYER_IDLE_SEQ;
		
		case ACT_RUN:
			return PLAYER_RUN_SEQ;
		
		case ACT_WALK:
			return PLAYER_WALK_SEQ;
		
		case ACT_HOP:
			return PLAYER_JUMP_SEQ;
		
		case ACT_LEAP:
			return PLAYER_LEAP_SEQ;
	}
	return PLAYER_IDLE_SEQ;
}

public finish_attack(id)
{
	g_iAttacking[id] = false;
}

InitiateSequence ( const player, const sequence )
{
    set_pev( player, pev_sequence, sequence );
	set_pev(player, pev_gaitsequence, 2);
    set_pev( player, pev_frame, 0 );

    ResetSequenceInfo( player );
}

stock bool:IsMoving ( const player )
{
    #define Length2D(%0) ( floatsqroot( %0[ 0 ] * %0[ 0 ] + %0[ 1 ] * %0[ 1 ] ) )

    static Float:velocity[ 3 ];
    pev( player, pev_velocity, velocity );

    return Length2D( velocity ) > 0;
}

stock ResetSequenceInfo ( const player )
{
    static OrpheuFunction:handleResetSequenceInfo;

    if ( !handleResetSequenceInfo ) {
        handleResetSequenceInfo = OrpheuGetFunction( "ResetSequenceInfo", "CBaseAnimating" );
    }

    OrpheuCall( handleResetSequenceInfo, player );
}

UpdateAnimationState ( const player, const animationState )
{
    set_pev( player, pev_framerate, float( animationState ) );
}

stock fm_cs_get_user_model(id, Model[], Len)
{
	if(!is_user_connected(id))
		return;
	
	engfunc(EngFunc_InfoKeyValue, engfunc(EngFunc_GetInfoKeyBuffer, id), "model", Model, Len);
}

const ACT_RELOAD            = 32;
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang3082\\ f0\\ fs16 \n\\ par }
*/
