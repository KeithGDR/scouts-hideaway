/*****************************/
//Pragma
#pragma semicolon 1
#pragma newdecls required

/*****************************/
//Defines
#define PLUGIN_NAME "[SH] Kick Immunity"
#define PLUGIN_DESCRIPTION "Disables autokick for clients who have admin flags."
#define PLUGIN_VERSION "1.0.0"

/*****************************/
//Includes
#include <sourcemod>
#include <sh/sh-utils>

/*****************************/
//ConVars

/*****************************/
//Globals

/*****************************/
//Plugin Info
public Plugin myinfo = 
{
	name = PLUGIN_NAME, 
	author = "Drixevel", 
	description = PLUGIN_DESCRIPTION, 
	version = PLUGIN_VERSION, 
	url = "https://scoutshideaway.com/"
};

public void OnPluginStart()
{
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i))
			OnClientPostAdminCheck(i);
}

public void OnClientPostAdminCheck(int client)
{
	if (CheckCommandAccess(client, "", ADMFLAG_RESERVATION, true))
	{
		ServerCommand("mp_disable_autokick %i", GetClientUserId(client));
		SH_Message(client, "You have logged in as admin so you have auto kick {lawngreen}immunity{default}!");
	}
}