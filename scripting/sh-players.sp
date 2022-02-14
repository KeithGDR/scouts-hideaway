/*****************************/
//Pragma
#pragma semicolon 1
#pragma newdecls required

/*****************************/
//Defines
#define PLUGIN_NAME "[SH] Players"
#define PLUGIN_DESCRIPTION "Saves and loads player data from a database for ease of access."
#define PLUGIN_VERSION "1.0.0"

#define NOT_REGISTERED -1

/*****************************/
//Includes
#include <sourcemod>
#include <sh/sh-utils>
#include <sh/sh-players>

/*****************************/
//ConVars

/*****************************/
//Globals

Database g_Database;
bool g_Late;
int g_PlayerID[MAXPLAYERS + 1] = {NOT_REGISTERED, ...};
Handle g_Forward_OnPlayerParsed;

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

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	//Register the library for other plugins to use.
	RegPluginLibrary("sh-players");

	//Create a native for other plugins to use for the players ID.
	CreateNative("SH_GetPlayerID", Native_GetPlayerID);

	//Register the forward for whenever the players parsed.
	g_Forward_OnPlayerParsed = CreateGlobalForward("SH_OnPlayerParsed", ET_Ignore, Param_Cell, Param_Cell);

	//Cache and save for later to see if this plugin was loaded late or not.
	g_Late = late;

	//Return success so the plugin loads.
	return APLRes_Success;
}

public void OnPluginStart()
{
	//Connect to the database as soon as the plugin loads.
	Database.Connect(OnSQLConnect, "default");

	//Register an easy command to check what your ID is or what others IDs are.
	RegConsoleCmd("sm_id", Command_ID, "Displays what the players ID is in chat.");
}

public void OnSQLConnect(Database db, const char[] error, any data)
{
	//Couldn't connect to the database, see why.
	if (db == null)
		ThrowError("Error while connecting to database: %s", error);
	
	//Save the database handle for usage later.
	g_Database = db;

	//Account for late loading and load players data.
	if (g_Late)
	{
		char auth[64];
		for (int i = 1; i <= MaxClients; i++)
			if (IsClientAuthorized(i) && GetClientAuthId(i, AuthId_Engine, auth, sizeof(auth)))
				OnClientAuthorized(i, auth);
	}
}

public void OnClientAuthorized(int client, const char[] auth)
{
	//Skip fake clients since they have no data.
	if (IsFakeClient(client))
		return;
	
	//Skip actual clients if the database is unavailable.
	if (g_Database == null)
		return;
	
	//Retrieve the steam2 auth id for use.
	char sSteam2[64];
	if (!GetClientAuthId(client, AuthId_Steam2, sSteam2, sizeof(sSteam2)))
		return;
	
	//Lets pull necessary player data for use elsewhere.
	char sQuery[256];
	g_Database.Format(sQuery, sizeof(sQuery), "SELECT id FROM `sh_players` WHERE steam2 = '%s';", sSteam2);
	g_Database.Query(OnParsePlayer, sQuery, GetClientUserId(client), DBPrio_Low);
}

public void OnParsePlayer(Database db, DBResultSet results, const char[] error, any data)
{
	//Give an error if the results aren't available due to some kind of an internal error.
	if (results == null)
		ThrowError("Error while parsing player data: %s", error);
	
	//Convert a client userid back into an index to keep the client consistent.
	int client;
	if ((client = GetClientOfUserId(data)) == 0)
		return;
	
	//Data was retrieved, client has joined the server before.
	if (results.FetchRow())
	{
		g_PlayerID[client] = results.FetchInt(0);

		//Call the forward so other plugins know.
		Call_StartForward(g_Forward_OnPlayerParsed);
		Call_PushCell(client);
		Call_PushCell(g_PlayerID[client]);
		Call_Finish();
	}
	else //Data wasn't retrieved so the client is new.
	{
		//If any of these SteamIDs return false then Steam's down so don't register the player.
		char sSteam2[64];
		if (!GetClientAuthId(client, AuthId_Steam2, sSteam2, sizeof(sSteam2)))
			return;

		char sSteam3[64];
		if (!GetClientAuthId(client, AuthId_Steam3, sSteam3, sizeof(sSteam3)))
			return;
		
		char sSteam64[64];
		if (!GetClientAuthId(client, AuthId_SteamID64, sSteam64, sizeof(sSteam64)))
			return;
		
		//Register the player and retrieve the ID of the player in the callback.
		char sQuery[512];
		g_Database.Format(sQuery, sizeof(sQuery), "INSERT INTO `sh_players` (steam2, steam3, steam64) VALUES ('%s', '%s', '%s');", sSteam2, sSteam3, sSteam64);
		g_Database.Query(OnCreatePlayer, sQuery, data, DBPrio_Low);
	}
}

public void OnCreatePlayer(Database db, DBResultSet results, const char[] error, any data)
{
	//Give an error if the results aren't available due to some kind of an internal error.
	if (results == null)
		ThrowError("Error while creating player data: %s", error);
	
	//Convert a client userid back into an index to keep the client consistent.
	int client;
	if ((client = GetClientOfUserId(data)) == 0)
		return;
	
	//Data was created so lets assign their new ID.
	if (results.FetchRow())
	{
		g_PlayerID[client] = results.InsertId;

		//Call the forward so other plugins know.
		Call_StartForward(g_Forward_OnPlayerParsed);
		Call_PushCell(client);
		Call_PushCell(g_PlayerID[client]);
		Call_Finish();
	}
}

public void OnClientDisconnect_Post(int client)
{
	//Make sure the client is unregistered on disconnect.
	g_PlayerID[client] = NOT_REGISTERED;
}

public int Native_GetPlayerID(Handle plugin, int numParams)
{
	//Get the player index.
	int client = GetNativeCell(1);

	//Check if the index is valid.
	if (client < 1 || client > MaxClients)
		ThrowNativeError(SP_ERROR_NATIVE, "Invalid client index (%d)", client);
	
	//Check if the client is a bot or not. (Bots can't be registered)
	if (IsFakeClient(client))
		ThrowNativeError(SP_ERROR_NATIVE, "Client is a bot (%d)", client);
	
	//Return either the ID of the player if they're registered or as unregistered.
	return g_PlayerID[client];
}

public Action Command_ID(int client, int args)
{
	//Automatically tie the client as the target if there's no extra parameter to specify a target.
	int target = client;

	//If there's a parameter, specify it as a potential target.
	if (args > 0)
	{
		char sTarget[MAX_TARGET_LENGTH];
		GetCmdArgString(sTarget, sizeof(sTarget));
		target = FindTarget(client, sTarget, true, false);
	}

	//Make sure the target has a valid index.
	if (target < 1 || target > MaxClients)
	{
		SH_Message(client, "Invalid target specified, please try again.");
		return Plugin_Handled;
	}

	//Make sure the target isn't a bot, bots can't be registered.
	if (IsFakeClient(target))
	{
		SH_Message(client, "Invalid target specified, please choose a player.");
		return Plugin_Handled;
	}

	//Send the message.
	SH_Message(client, "{darkorchid}%N{default}'s ID is {lawngreen}%i{default}.", target, g_PlayerID[target]);

	//Supress the command and mark it as a valid command.
	return Plugin_Handled;
}