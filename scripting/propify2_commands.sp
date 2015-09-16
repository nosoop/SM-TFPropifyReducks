#include <sourcemod>

#define GAME_TF2
#include <thelpers/thelpers>

#pragma semicolon 1
#pragma newdecls required

#include <propify2>

#define PLUGIN_VERSION "0.1.0"
public Plugin myinfo = {
    name = "[TF2] Propify Commands",
    author = "nosoop",
    description = "Basic commands for admins to turn things into props.",
    version = PLUGIN_VERSION,
    url = "https://github.com/nosoop"
};

PropifyPropList g_PropList = null;

public void OnPluginStart() {
	Propify2_GetPropList(g_PropList);

	RegAdminCmd("sm_prop", ConCmd_PropPlayer, ADMFLAG_SLAY);
}

public Action ConCmd_PropPlayer(int iClient, int nArgs) {
	PropifyTFPlayer player = Propify2_GetPlayer(iClient);
	
	if (!player.IsPropped) {
		PropifyPropEntry entry = g_PropList.Get(GetRandomInt(0, g_PropList.Length - 1));
		
		player.SetProp(entry, PROPIFYFLAG_NO_WEAPONS);
		delete entry;
		
		player.ThirdPerson = true;
	} else {
		player.Unprop();
	}
	
	return Plugin_Handled;
}