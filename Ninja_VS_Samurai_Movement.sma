#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <fun>
#include <orpheu>

#define PLUGIN "Moving Mekanikusu"
#define VERSION "1.0"
#define AUTHOR "Sam Tsuki - Dias Pendragon - Sneaky.amxx"

#define PLAYER_SPEED 500.0
#define CLIMB_SPEED 200.0
#define WALLJUMP_HEIGHT 450.0
#define CLIMBJUMP_HEIGHT 225.0

#define SetTrue(%1,%2) (%1 |= 1<<(%2&31))
#define SetFalse(%1,%2) (%1 &= ~1<<(%2&31))
#define IsTrue(%1,%2) (%1 & 1<<(%2&31))

//new Float:g_WallOrigin[32][3]
new g_bFalling, g_bJump, g_bWallBlock;
new Float:g_fVelocity[32][3];
new g_iJumpCount[32];
new g_HamBot
new bool: g_iOnWall[32], Float: g_iOrigin[32][3], Float: g_fNormalVector[32][3];

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_event("CurWeapon", "Event_CurWeapon", "be", "1=1")
	
	register_touch("player", "worldspawn", "Touch_World")
	register_touch("player", "func_wall", "Touch_World")
	register_touch("player", "func_breakable", "Touch_World")
	
	RegisterHam(Ham_Spawn, "player", "fw_PlayerSpawn_Post", 1)
}

public plugin_cfg()
{
	server_cmd("mp_freezetime 0")	
	server_cmd("sv_maxspeed 9999")
	server_cmd("sv_airaccelerate 100")
	server_cmd("sv_gravity 600")
}

public client_putinserver(id)
{
	if(!g_HamBot && is_user_bot(id))
	{
		g_HamBot = 1
		set_task(0.1, "Register_HamBot", id)
	}
}
 
public Register_HamBot(id)
{
	RegisterHamFromEntity(Ham_Spawn, id, "fw_PlayerSpawn_Post", 1)
}

public client_disconnect(id)
{
	client_cmd(id,"cl_forwardspeed 400")
	client_cmd(id,"cl_backspeed 400")
	client_cmd(id,"cl_sidespeed 400")
}

public client_PreThink(id)
{
	if(!is_user_alive(id))
		return
		
	// CLIMB WALL
	//static Button; Button = get_user_button(id)
	//if(Button & IN_DUCK) WallClimb(id, Button)
	
	if(g_iOnWall[id]) {
		static Button; Button = get_user_button(id);
		pev(id, pev_origin, g_iOrigin[id]);
		WallClimb(id, g_iOrigin[id], g_fNormalVector[id], Button);
	}
	
	// WALL JUMP
	// Whether user is falling
	if (is_user_alive(id) && is_user_connected(id) && pev(id, pev_flFallVelocity) >= 350.0)
		SetTrue(g_bFalling, id);
	else
		SetFalse(g_bFalling, id);

	// Wall jump stuff
	// Skipping one frame after jump from ground, because of entities dumb touch system
	if (IsTrue(g_bWallBlock, id))
		SetFalse(g_bWallBlock, id);
	static buttons, oldbuttons;
	buttons = pev(id, pev_button);
	oldbuttons = pev(id, pev_oldbuttons);
	// If user performs "manual" jump
	if (buttons & IN_JUMP && !(oldbuttons & IN_JUMP) && pev(id, pev_flags) & FL_ONGROUND){
		pev(id, pev_velocity, g_fVelocity[id]);		// Sets base velocity and
		g_iJumpCount[id] = 10;		// allowed jumps number
		SetTrue(g_bWallBlock, id);
	}
	// Wall jump performance
	// If user touched wall and pressed JUMP button
	if (IsTrue(g_bJump, id)){
		if (pev(id, pev_flags) & FL_ONGROUND){
		// If user is not in air wall jump doesn't count as performed
			SetFalse(g_bJump, id);
		}
		else {
			// Otherwise jump
			set_pev(id, pev_velocity, g_fVelocity[id]);
			g_iJumpCount[id]--;
			SetFalse(g_bJump, id);
		}
	}
	
	// Auto BHOP
	entity_set_float(id, EV_FL_fuser2, 0.0)
	if(entity_get_int(id, EV_INT_button) & 2) 
	{
		new flags = entity_get_int(id, EV_INT_flags)

		if (flags & FL_WATERJUMP)
			return
		if ( entity_get_int(id, EV_INT_waterlevel) >= 2 )
			return
		if ( !(flags & FL_ONGROUND) )
			return

		new Float:velocity[3]
		entity_get_vector(id, EV_VEC_velocity, velocity)
		velocity[2] += 250.0
		entity_set_vector(id, EV_VEC_velocity, velocity)
		
		static OrpheuFunction:handleSetAnimation;
		handleSetAnimation = OrpheuGetFunction("SetAnimation", "CBasePlayer");
		OrpheuCallSuper(handleSetAnimation, id, 2);
	}
}

/*
public WallClimb(id, button)
{
	static Float:origin[3]
	pev(id, pev_origin, origin)

	if(get_distance_f(origin, g_WallOrigin[id]) > 25.0)
		return 
	
	if(pev(id, pev_flags) & FL_ONGROUND)
		return
		
	static Float:velocity[3]
	if(button & IN_FORWARD)
	{
		velocity_by_aim(id, floatround(WALLJUMP_HEIGHT), velocity)
		fm_set_user_velocity(id, velocity)
	}
	
	return
}	
*/

public WallClimb(id, Float: iOrigin[3], Float: fNormalVector[3], button)
{
	if ((pev(id, pev_flags) & FL_ONGROUND) || !(button & IN_DUCK)) {
		g_iOnWall[id] = false;
		set_pev(id, pev_maxspeed, PLAYER_SPEED);
		
		return;
	}
	
	new Float: endOrigin[3], Float: fraction, Float: fRightAngle[3], Float: fUpAngle[3];
	vector_to_angle(fNormalVector, fRightAngle);
	vector_to_angle(fNormalVector, fUpAngle);
	angle_vector(fRightAngle, ANGLEVECTOR_RIGHT, fRightAngle);
	angle_vector(fUpAngle, ANGLEVECTOR_UP, fUpAngle);
	xs_vec_mul_scalar(fNormalVector, -32.0, endOrigin);
	xs_vec_add(endOrigin, iOrigin, endOrigin);
	
	engfunc(EngFunc_TraceHull, iOrigin, endOrigin, IGNORE_MONSTERS, HULL_HEAD, id, 0);
	get_tr2(0, TR_flFraction, fraction);
	get_tr2(0, TR_vecPlaneNormal, g_fNormalVector[id]);
	free_tr2(0);
	
	if(fraction != 1.0) {
		g_iOnWall[id] = true;
		
		set_pev(id, pev_maxspeed, -1.0);
		
		if(button & IN_JUMP) {
			g_fVelocity[id][0] = CLIMBJUMP_HEIGHT * fNormalVector[0];
			g_fVelocity[id][1] = CLIMBJUMP_HEIGHT * fNormalVector[1];
			g_fVelocity[id][2] = CLIMBJUMP_HEIGHT;
			
			g_iOnWall[id] = false;
			set_pev(id, pev_velocity, g_fVelocity[id]);
			
			set_pev(id, pev_maxspeed, PLAYER_SPEED);
			return;
		}
		
		//new Float: Up_Velocity;
		new Float: Final_Velocity[3], Float: Up_Velocity[3];
		if(button & IN_FORWARD)
			velocity_by_aim(id, floatround(CLIMB_SPEED), Final_Velocity);
		else if(button & IN_BACK) 
			velocity_by_aim(id, -floatround(CLIMB_SPEED), Final_Velocity);
		else {
			xs_vec_mul_scalar(g_fVelocity[id], 0.0, g_fVelocity[id]);
			return;
		}
		
		//Up_Velocity = g_fVelocity[id][2];
		
		xs_vec_normalize(Final_Velocity, Final_Velocity);
		xs_vec_normalize(Final_Velocity, Up_Velocity);
		
		new Float: fraction = xs_vec_dot(Final_Velocity, fRightAngle);
		
		xs_vec_mul_scalar(fRightAngle, fraction, fRightAngle);
		
		xs_vec_mul_scalar(fRightAngle, CLIMB_SPEED, Final_Velocity);
		
		fraction = xs_vec_dot(Up_Velocity, fUpAngle);
		
		xs_vec_mul_scalar(fUpAngle, fraction, fUpAngle);
		
		xs_vec_mul_scalar(fUpAngle, CLIMB_SPEED, Up_Velocity);
		
		Up_Velocity[0] *= -1.0;
		Up_Velocity[1] *= -1.0;
		
		xs_vec_mul_scalar(g_fVelocity[id], 0.0, g_fVelocity[id]);
		xs_vec_add(g_fVelocity[id], Final_Velocity, g_fVelocity[id]);
		xs_vec_add(g_fVelocity[id], Up_Velocity, g_fVelocity[id]);
		
		//g_fVelocity[id][2] = Up_Velocity;
		
		pev(id, pev_origin, g_iOrigin[id]);
	}
	else {
		g_iOnWall[id] = false;
		set_pev(id, pev_maxspeed, PLAYER_SPEED);
	}
}

public client_PostThink(id) 
{
	if(!is_user_alive(id)) 
		return
		
	if(g_iOnWall[id])
		set_pev(id, pev_velocity, g_fVelocity[id]);
}

public fuck_ent(ent, Float:VicOrigin[3], Float:speed, Float:Z)
{
	static Float:fl_Velocity[3], Float:EntOrigin[3], Float:distance_f, Float:fl_Time
	
	pev(ent, pev_origin, EntOrigin)
	
	distance_f = get_distance_f(EntOrigin, VicOrigin)
	fl_Time = distance_f / speed
		
	fl_Velocity[0] = (EntOrigin[0]- VicOrigin[0]) / fl_Time
	fl_Velocity[1] = (EntOrigin[1]- VicOrigin[1]) / fl_Time
	fl_Velocity[2] = Z //(EntOrigin[2]- VicOrigin[2]) / fl_Time

	set_pev(ent, pev_velocity, fl_Velocity)
}

public Touch_World(id, world) 
{
	if(is_user_alive(id) && !g_iOnWall[id]) 
	{
		//pev(id, pev_origin, g_WallOrigin[id]);
		
		// Wall jump stuff
		// If user is touching wall, not on ground, has some wall jumps left and currently  in jump
		if (!(pev(id, pev_flags) & FL_ONGROUND) && g_iJumpCount[id]
		     && (pev(id, pev_button) & IN_JUMP || pev(id, pev_button) & IN_DUCK) && !IsTrue(g_bWallBlock, id)){
			// Reverse velocity on X axis
			//g_fVelocity[id][0] *= (-1);
			// Set velocity upwards equal to 300.0 units/s
			//g_fVelocity[id][2] = 300.0;
			
			new Float: iOrigin[3], Float: endOrigin[3], Float: linear, Float: fNormalVector[3], Float: fAngleVector[3], Float: tr_fraction;
			pev(id, pev_origin, iOrigin);
			pev(id, pev_velocity, endOrigin);
			xs_vec_add(fAngleVector, endOrigin, fAngleVector);
			linear = floatsqroot(floatpower(endOrigin[0], 2.0) + floatpower(endOrigin[1], 2.0) + floatpower(endOrigin[2], 2.0));
			xs_vec_normalize(endOrigin, endOrigin);
			xs_vec_mul_scalar(endOrigin, 32.0, endOrigin);
			endOrigin[2] = 0.0;
			xs_vec_add(endOrigin, iOrigin, endOrigin);
			engfunc(EngFunc_TraceHull, iOrigin, endOrigin, IGNORE_MONSTERS, HULL_HEAD, id, 0);
			get_tr2(0, TR_flFraction, tr_fraction);
			get_tr2(0, TR_vecEndPos, endOrigin);
			get_tr2(0, TR_vecPlaneNormal, fNormalVector);
			free_tr2(0);
			
			if(tr_fraction == 1.0 || engfunc(EngFunc_PointContents, endOrigin) == CONTENTS_SKY)
				return;
			
			// CLIMB WALL
			static Button; Button = get_user_button(id);
			if(Button & IN_DUCK) {
				g_fNormalVector[id][0] = fNormalVector[0];
				g_fNormalVector[id][1] = fNormalVector[1];
				g_fNormalVector[id][2] = fNormalVector[2];
				g_iOnWall[id] = true;
				return;
			}
			
			xs_vec_normalize(fAngleVector, fAngleVector);
			
			new Float: fraction = xs_vec_dot(fAngleVector, fNormalVector);
			
			xs_vec_mul_scalar(fNormalVector, fraction, fNormalVector);
			xs_vec_sub(fNormalVector, fAngleVector, fAngleVector);
			xs_vec_mul_scalar(fAngleVector, (1-(fraction*fraction))/xs_vec_len(fAngleVector), fAngleVector);
			
			xs_vec_add(fNormalVector, fAngleVector, fNormalVector);
			
			xs_vec_mul_scalar(fNormalVector, linear, g_fVelocity[id]);
			
			g_fVelocity[id][0] *= -1.0;
			g_fVelocity[id][1] *= -1.0;
			g_fVelocity[id][2] = WALLJUMP_HEIGHT;
			
			SetTrue(g_bJump, id);
		}
	}
}


public fw_PlayerSpawn_Post(id)
{
	client_cmd(id,"cl_forwardspeed 9999")
	client_cmd(id,"cl_sidespeed 9999")
	client_cmd(id,"cl_backspeed 9999")
	client_cmd(id,"hud_centerid 0")
}

public Event_CurWeapon(id)
{
	if(!is_user_alive(id))
		return
		
	set_user_maxspeed(id, PLAYER_SPEED)
}
