#include <sourcemod>
#include <sdktools_functions>
#include <sdkhooks>
#include <cstrike>

#define PI 3.141592

new bool:CanJump[MAXPLAYERS+1];

public Plugin:myinfo =
{
	name = "Defrag",
	author = "Panzer",
	description = "Bhopping gives you speed",
	version = "1.0",
	url = "http://www.sourcemod.net/"
};

public OnPluginStart()
{
	for (new client = 1; client <= MaxClients; client++)
	{
        if (IsValidEntity(client) && IsClientInGame(client))
		{
			SDKHook(client, SDKHook_PostThink, OnPostThink);
		}
	}
	
	ServerCommand("sm_cvar sv_airaccelerate 15");
	ServerCommand("sm_cvar sv_maxvelocity 999999");
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
}

public OnMapStart()
{
	new ent = CreateEntityByName("game_player_equip");
	DispatchKeyValue(ent, "weapon_knife", "1");
}

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_PostThink, OnPostThink);
}

public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	
	// God mode
	SetEntProp(client, Prop_Data, "m_takedamage", 0, 1);
	
	// Noblock (remove player collisions)
	SetEntProp(client, Prop_Data, "m_CollisionGroup", 2);
}

public Event_PlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	CreateTimer(0.01, RespawnPlayer, client);
}

public Action:RespawnPlayer(Handle:timer, any:client)
{
	if (client >= 1 && client <= MaxClients && !IsPlayerAlive(client) && GetClientTeam(client) != 1)
		CS_RespawnPlayer(client);
}

public OnPostThink(ent)
{
	// Not on ground
	if (!(GetEntityFlags(ent) & FL_ONGROUND))
	{
		new Float:vel[3];
		new Float:angs[3];
		GetEntPropVector(ent, Prop_Data, "m_vecVelocity", vel);
		GetClientAbsAngles(ent, angs);
		new Float:angsRad = DegToRad(angs[1])
		// Fix positive 180 degree value
		if (angs[1] == 180.0)
			angsRad *= -1;
		
		// X and Y velocity components for determining boost magnitude
		new Float:forwardX =  2 * Cosine(angsRad);
		new Float:forwardY = 2 * Sine(angsRad);
		new Float:rightX = 2 * Cosine(angsRad - (PI / 2));
		new Float:rightY = 2 * Sine(angsRad - (PI / 2));
		new Float:leftX = -1 * rightX;
		new Float:leftY = -1 * rightY;
		
		// Angle of velocity vector
		new Float:velAng;
		velAng = ArcTangent2(vel[1], vel[0]);
		
		// Difference between the angle of the velocity vector and the direction the player is facing
		new Float:angDif;
		angDif = angsRad - velAng;
		if (angDif > PI)
			angDif -= 2 * PI;
		if (angDif < -1 * PI)
			angDif += 2 * PI;
		
		if (GetClientButtons(ent) & IN_FORWARD && GetClientButtons(ent) & IN_MOVERIGHT && angDif < PI / 22.5)
		{
			// Forward speed boost
			vel[0] += forwardX;
			vel[1] += forwardY;
			// Right speed boost
			vel[0] += rightX;
			vel[1] += rightY;
		}
		if (GetClientButtons(ent) & IN_FORWARD && GetClientButtons(ent) & IN_MOVELEFT && angDif > PI / 22.5)
		{
			// Forward speed boost
			vel[0] += forwardX;
			vel[1] += forwardY;
			// Left speed boost
			vel[0] += leftX;
			vel[1] += leftY;
		}
		TeleportEntity(ent, NULL_VECTOR, NULL_VECTOR, vel);
		
		//PrintCenterText(ent, "%f %f %f", angsRad, velAng, angDif);
	}
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon)
{
	// Client can jump again when letting go of jump after bhopping
	if (CanJump[client] == false && !(buttons & IN_JUMP))
		CanJump[client] = true;

	// Auto jump when client is allowed to jump and is holding jump key
	if (CanJump[client] && buttons & IN_JUMP && GetEntProp(client, Prop_Data, "m_nWaterLevel") <= 1)
		if (!(GetEntityFlags(client) & FL_ONGROUND))
			buttons &= ~IN_JUMP;
		else
			CanJump[client] = false;
}