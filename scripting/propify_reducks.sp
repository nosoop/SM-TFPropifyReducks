#include <sourcemod>

#define GAME_TF2
#include <thelpers/thelpers>

#pragma semicolon 1
#pragma newdecls required

#include "propify2/methodmaps.sp"
#include "propify2/dirtykvparser.sp"

#define PLUGIN_VERSION "0.1.0"
public Plugin myinfo = {
    name = "[TF2] Propify Re-ducks",
    author = "nosoop",
    description = "The props... have moved!  Propify with transitional syntax-y goodness.",
    version = PLUGIN_VERSION,
    url = "https://github.com/nosoop"
};

PropifyPropList g_PropList;
PropifyTFPlayer g_proppablePlayers[MAXPLAYERS+1];
KeyValueSectionParser g_PropListParser;

public void OnPluginStart() {
	g_PropList = new PropifyPropList();
		
	HookEvent("player_spawn", Event_PlayerSpawn_Post, EventHookMode_Post);
	HookEvent("post_inventory_application", Event_PlayerInventoryApplication_Post, EventHookMode_Post);
	
	// Test prop command for fine-tuning prop behavior
	RegAdminCmd("sm_prop", ConCmd_PropPlayer, ADMFLAG_ROOT);
	
	// Besides the whole 1.7-rewrite stuff, prop list parsing *must* be passed to a private forward that calls a function now
	g_PropListParser = new KeyValueSectionParser();
	g_PropListParser.AddCallbackFunction("proplist", INVALID_HANDLE, KeyValueSection_PropList);
	
	// Late loads, as always.
	for (int i = MaxClients; i > 0; --i) {
		if (IsClientInGame(i)) {
			OnClientPutInServer(i);
		}
	}
}

/* Basic cleanup routine. */
public void OnPluginEnd() {
	for (int i = MaxClients; i > 0; --i) {
		if (IsClientInGame(i)) {
			OnClientDisconnect(i);
		}
	}
	g_PropList.Clear();
}

/* Overlay prop-making methods onto player. */
public void OnClientPutInServer(int iClient) {
	g_proppablePlayers[iClient] = new PropifyTFPlayer(iClient);
}

public void OnClientDisconnect(int iClient) {
	PropifyTFPlayer player = g_proppablePlayers[iClient];
	if (player.IsPropped) {
		player.Unprop();
	} else {
		player.Reset();
	}
	g_proppablePlayers[iClient] = null;
}

/* Do fancy prop loading stuff */
public void OnMapStart() {
	LoadPropConfigs();
}

void LoadPropConfigs() {
	ParsePropConfigs("base_main");
	
	// TODO hold an ArrayList of prop lists that have been included
}

void ParsePropConfigs(const char[] listName) {
	KeyValues kv = new KeyValues(listName);
	
	int pre = g_PropList.Length;
	
	char sPropFilePath[PLATFORM_MAX_PATH];
    Format(sPropFilePath, sizeof(sPropFilePath), "data/propify/%s.txt", listName);
    BuildPath(Path_SM, sPropFilePath, sizeof(sPropFilePath), sPropFilePath);
	
	kv.ImportFromFile(sPropFilePath);
	g_PropListParser.Parse(kv);
	delete kv;
	
	int post = g_PropList.Length;
	
	PrintToServer("%d props added from prop list %s.", post-pre, listName);
}

public void KeyValueSection_PropList(const char[] key, const char[] value) {
	g_PropList.AddPropToList(key, value);
}


/**
 * Hook for `post_inventory_application` to restrip propped players of weapons as necessary
 */
public void Event_PlayerInventoryApplication_Post(Event event, const char[] name, bool dontBroadcast) {
	PropifyTFPlayer player = g_proppablePlayers[GetClientOfUserId(event.GetInt("userid"))];
	
	if (player != null && player.IsPropped && player.IsDisarmed) {
		player.RemoveWeapons();
	}
}

/**
 * Hook for `player_spawn` to unset player prop (which also regrants the weapons removed by `post_inventory_application`).
 */
public void Event_PlayerSpawn_Post(Event event, const char[] name, bool dontBroadcast) {
	PropifyTFPlayer player = g_proppablePlayers[GetClientOfUserId(event.GetInt("userid"))];
	player.Unprop();
}

// Test prop command
public Action ConCmd_PropPlayer(int iClient, int nArgs) {
	PropifyTFPlayer player = g_proppablePlayers[iClient];
	
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
