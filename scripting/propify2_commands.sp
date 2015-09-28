#include <sourcemod>

#define GAME_TF2
#include <thelpers/thelpers>

#pragma semicolon 1
#pragma newdecls required

#include <propify2>

#define PLUGIN_VERSION "0.3.0"
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
	RegAdminCmd("sm_prop_weapon", ConCmd_PropPlayerWeapon, ADMFLAG_SLAY);
}

/**
 * Turns the player that used this command into a prop, disarming them in the process.
 */
public Action ConCmd_PropPlayer(int iClient, int nArgs) {
	PropifyTFPlayer player = Propify2_GetPlayer(iClient);
	
	if (!player.IsPropped) {
		PropifyPropEntry entry = g_PropList.Get(GetRandomInt(0, g_PropList.Length - 1));
		
		player.Propify(entry, PROPIFYFLAG_NO_WEAPONS);
		delete entry;
		
		player.ThirdPerson = true;
	} else {
		player.Unpropify();
	}
	
	return Plugin_Handled;
}

/**
 * Turns the player that used this command into a prop, with their weapons kept intact.
 */
public Action ConCmd_PropPlayerWeapon(int iClient, int nArgs) {
	PropifyTFPlayer player = Propify2_GetPlayer(iClient);
	
	if (!player.IsPropped) {
		PropifyPropEntry entry = g_PropList.Get(GetRandomInt(0, g_PropList.Length - 1));
		
		player.Propify(entry);
		delete entry;
		
		player.ThirdPerson = true;
	} else {
		player.Unpropify();
	}
	
	return Plugin_Handled;
}