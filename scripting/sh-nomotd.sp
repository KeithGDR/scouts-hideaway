/*****************************/
//Pragma
#pragma semicolon 1
#pragma newdecls required

/*****************************/
//Defines
#define PLUGIN_NAME "[SH] No MOTD"
#define PLUGIN_DESCRIPTION "Disables MOTDs on connect."
#define PLUGIN_VERSION "1.0.0"

/*****************************/
//Includes
#include <sourcemod>

/*****************************/
//ConVars

/*****************************/
//Globals

bool g_Blocked[MAXPLAYERS + 1];

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
	HookUserMessage(GetUserMessageId("Train"), UserMessageHook, true);

	for (int i = 1; i <= MaxClients; i++)
		g_Blocked[i] = IsClientInGame(i);
}

public Action UserMessageHook(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init) 
{
	if (playersNum != 1)
		return Plugin_Continue;
	
	int client = players[0];

	if (IsClientConnected(client) && !g_Blocked[client] && !IsFakeClient(client))
	{
		g_Blocked[client] = true;
		RequestFrame(KillMOTD, GetClientUserId(client));
	}

	return Plugin_Continue;
}

public void KillMOTD(any data)
{
	int client = GetClientOfUserId(data);
	
	if (!client)
		return;
	
	ShowVGUIPanel(client, "info", _, false);
	ShowVGUIPanel(client, "team", _, true);
}

public void OnClientDisconnect_Post(int client)
{
	g_Blocked[client] = false;
}