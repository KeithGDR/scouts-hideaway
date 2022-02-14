#if defined _sh_utils_included
  #endinput
#endif
#define _sh_utils_included

#include <colors>

stock void SH_Message(int client, char[] message, any ...)
{
	char sMessage[255];
	VFormat(sMessage, sizeof(sMessage), message, 3);

	CPrintToChat(client, "{crimson}[{ghostwhite}SH{crimson}] {default}%s", sMessage);
}

stock void SH_MessageAll(char[] message, any ...)
{
	char sMessage[255];
	VFormat(sMessage, sizeof(sMessage), message, 2);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;

		CPrintToChat(i, "{crimson}[{ghostwhite}SH{crimson}] {default}%s", sMessage);
	}
}