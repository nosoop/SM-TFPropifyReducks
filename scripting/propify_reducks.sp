#include <sourcemod>

#define GAME_TF2
#include <thelpers/thelpers>

#pragma semicolon 1
#pragma newdecls required

#include "propify2/methodmaps.sp"
#include "propify2/dirtykvparser.sp"

#define PLUGIN_VERSION "0.5.0"
public Plugin myinfo = {
    name = "[TF2] Propify Re-ducks",
    author = "nosoop",
    description = "The props... have moved!  Propify with transitional syntax-y goodness.",
    version = PLUGIN_VERSION,
    url = "https://github.com/nosoop"
};

PropifyPropList g_PropList;
ArrayList g_PropConfigs;
PropifyTFPlayer g_proppablePlayers[MAXPLAYERS+1];
KeyValueSectionParser g_PropListParser;

public void OnPluginStart() {
	g_PropList = new PropifyPropList();
	g_PropConfigs = new ArrayList(PLATFORM_MAX_PATH);
		
	HookEvent("player_spawn", Event_PlayerSpawn_Post, EventHookMode_Post);
	HookEvent("post_inventory_application", Event_PlayerInventoryApplication_Post, EventHookMode_Post);
		
	// Besides the whole 1.7-rewrite stuff, prop list parsing *must* be passed to a private forward that calls a function now
	g_PropListParser = new KeyValueSectionParser();
	g_PropListParser.AddCallbackFunction("proplist", INVALID_HANDLE, KeyValueSection_PropList);
	g_PropListParser.AddCallbackFunction("includes", INVALID_HANDLE, KeyValueSection_Includes);
	
	// TODO create command for reloading prop lists
	
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
		player.Unpropify();
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
	g_PropList.Clear();
	g_PropConfigs.PushString("base");
	
	char listName[PLATFORM_MAX_PATH];
	for (int i = 0; i < g_PropConfigs.Length; i++) {
		g_PropConfigs.GetString(i, listName, sizeof(listName));
		ParsePropConfig(listName);
	}
	
	g_PropConfigs.Clear();
}

void ParsePropConfig(const char[] listName) {
	int nProps = g_PropList.Length;
	
	char sPropFilePath[PLATFORM_MAX_PATH];
	Format(sPropFilePath, sizeof(sPropFilePath), "data/propify/%s.txt", listName);
	BuildPath(Path_SM, sPropFilePath, sizeof(sPropFilePath), sPropFilePath);
	
	if (FileExists(sPropFilePath)) {
		KeyValues kv = new KeyValues(listName);
		kv.ImportFromFile(sPropFilePath);
		g_PropListParser.Parse(kv);
		delete kv;
	}
	
	int nAdded = g_PropList.Length - nProps;
	
	if (nAdded > 0) {
		PrintToServer("%d props added from prop list %s.", nAdded, listName);
	}
}

/**
 * Adds the name / path of pairs in the `proplist` section to the prop list.
 */
public void KeyValueSection_PropList(const char[] key, const char[] value) {
	g_PropList.AddPropToList(key, value);
}

/**
 * Adds the value of pairs in the `includes` section into the list of configs to check.
 */
public void KeyValueSection_Includes(const char[] key, const char[] value) {
	if (g_PropConfigs.FindString(value) == -1) {
		g_PropConfigs.PushString(value);
	}
}

/**
 * Hook for `post_inventory_application` to restrip propped players of weapons as necessary
 */
public void Event_PlayerInventoryApplication_Post(Event event, const char[] name, bool dontBroadcast) {
	PropifyTFPlayer player = g_proppablePlayers[GetClientOfUserId(event.GetInt("userid"))];
	
	if (player != null && player.IsPropped && player.IsDisarmed) {
		player.Disarm();
	}
}

/**
 * Hook for `player_spawn` to unset player prop (which also regrants the weapons removed by `post_inventory_application`).
 */
public void Event_PlayerSpawn_Post(Event event, const char[] name, bool dontBroadcast) {
	PropifyTFPlayer player = g_proppablePlayers[GetClientOfUserId(event.GetInt("userid"))];
	player.Unpropify();
}

#include "propify2/natives.sp"
