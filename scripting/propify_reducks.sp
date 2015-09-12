#include <sourcemod>

#define GAME_TF2
#include <thelpers/thelpers>

#pragma semicolon 1
#pragma newdecls required

#include "propify2/methodmaps.sp"

#define PLUGIN_VERSION "0.0.1"
public Plugin myinfo = {
    name = "[TF2] Propify Re-ducks",
    author = "nosoop",
    description = "The props... have moved!  Propify with transitional syntax-y goodness.",
    version = PLUGIN_VERSION,
    url = "https://github.com/nosoop"
};

PropifyPropList g_PropList;
PropifyTFPlayer g_proppablePlayers[MAXPLAYERS+1];

public void OnPluginStart() {
	g_PropList = new PropifyPropList();
	
	// Temporary prop list
	g_PropList.AddPropToList("Oildrum", "models/props_2fort/oildrum.mdl");
	g_PropList.AddPropToList("Spy's Box", "models/workshop/player/items/spy/taunt_spy_boxtrot/taunt_spy_boxtrot.mdl");
	g_PropList.AddPropToList("Barricade Sign", "models/props_gameplay/sign_barricade001a.mdl");
	g_PropList.AddPropToList("Computer Cart", "models/props_well/computer_cart01.mdl");
	g_PropList.AddPropToList("Skull Sign", "models/props_mining/sign001.mdl");
	
	// Test prop command for fine-tuning prop behavior
	RegAdminCmd("sm_prop", ConCmd_PropPlayer, ADMFLAG_ROOT);
	
	// Late loads, as always.
	for (int i = MaxClients; i > 0; --i) {
		if (IsClientInGame(i)) {
			OnClientConnected(i);
		}
	}
}

// Test prop command
public Action ConCmd_PropPlayer(int iClient, int nArgs) {
	PropifyPropEntry entry = g_PropList.Get(GetRandomInt(0, g_PropList.Length - 1));
	g_proppablePlayers[iClient].SetPropByEntry(entry);	
	delete entry;
	
	return Plugin_Handled;
}

public void OnMapStart() {
	/* Do fancy prop loading stuff */
}

public void OnClientConnected(int iClient) {
	g_proppablePlayers[iClient] = new PropifyTFPlayer(iClient);
}

public void OnClientDisconnect(int iClient) {
	g_proppablePlayers[iClient].Reset();
}

public void OnPluginEnd() {
	g_PropList.Clear();
}