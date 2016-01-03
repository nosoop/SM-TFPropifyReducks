#include <sourcemod>

#define GAME_TF2
#include <thelpers/thelpers>

#pragma semicolon 1
#pragma newdecls required

#include "propify2/methodmaps.sp"
#include "propify2/dirtykvparser.sp"

#define PLUGIN_VERSION "0.6.6"
public Plugin myinfo = {
    name = "[TF2] Propify Re-ducks",
    author = "nosoop",
    description = "The props... have moved!  Propify with transitional syntax-y goodness.",
    version = PLUGIN_VERSION,
    url = "https://github.com/nosoop"
};

// See function Prop_OnCondZoomed
#define MANUAL_UNSCOPE_TIME_THRESHOLD 0.20

// Provide a global prop list for compatibility with original Propify plugin
PropifyPropList g_PropList;
ArrayList g_PropConfigs;
PropifyTFPlayer g_proppablePlayers[MAXPLAYERS+1];
KeyValueSectionParser g_PropListParser;

public void OnPluginStart() {
	g_PropConfigs = new ArrayList(PLATFORM_MAX_PATH);
	
	HookEvent("player_spawn", Event_PlayerSpawn_Post, EventHookMode_Post);
	HookEvent("player_death", Event_PlayerSpawn_Post, EventHookMode_Post);
	// TODO add convar and method to drop props as ragdolls?
	HookEvent("post_inventory_application", Event_PlayerInventoryApplication_Post, EventHookMode_Post);
	
	RegAdminCmd("sm_propify2_reloadlist", AdminCmd_ReloadPropList, ADMFLAG_ROOT, "Reloads the prop list.");
		
	// Besides the whole 1.7-rewrite stuff, prop list parsing *must* be passed to a private forward that calls a function now
	g_PropListParser = new KeyValueSectionParser();
	g_PropListParser.AddCallbackFunction("proplist", INVALID_HANDLE, KeyValueSection_PropList);
	g_PropListParser.AddCallbackFunction("includes", INVALID_HANDLE, KeyValueSection_Includes);
	
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

/**
 * Modifies prop behavior based on condition.
 */
public void TF2_OnConditionAdded(int client, TFCond condition) {
	PropifyTFPlayer player = g_proppablePlayers[client];
	if (player.IsPropped) {
		switch (condition) {
			case TFCond_Stealthed: { Prop_OnCondStealthed(player, true); }
			case TFCond_Taunting: { Prop_OnCondTaunting(player, true); }
			case TFCond_Cloaked: { Prop_OnCondCloaked(player, true); }
			case TFCond_Zoomed: { Prop_OnCondZoomed(player, true); }
		}
	}
}

/**
 * Resets prop behavior based on condition.
 */
public void TF2_OnConditionRemoved(int client, TFCond condition) {
	PropifyTFPlayer player = g_proppablePlayers[client];
	if (player.IsPropped) {
		switch (condition) {
			case TFCond_Stealthed: { Prop_OnCondStealthed(player, false); }
			case TFCond_Taunting: { Prop_OnCondTaunting(player, false); }
			case TFCond_Cloaked: { Prop_OnCondCloaked(player, false); }
			case TFCond_Zoomed: { Prop_OnCondZoomed(player, false); }
		}
	}
}

/**
 * Prevent prop rotation if player is taunting while propped.
 */
void Prop_OnCondTaunting(PropifyTFPlayer player, bool bTaunting) {
	// TODO use SetCustomModelRotates without stun, prevent taunt on proplock?
	player.IsPropLocked = bTaunting;
}

/**
 * Visual indication to self and allies that propped player is currently cloaked.
 * (Player is fully invisible to players on the enemy team regardless.)
 */
void Prop_OnCondCloaked(PropifyTFPlayer player, bool bCloaked) {
	// Stealth takes precedence over cloak.
	bool bStealthed = TF2_IsPlayerInCondition(player.Index, TFCond_Stealthed);
	SetEntityAlpha(player, bStealthed || bCloaked? 80 : 255);
}

/**
 * Visual indication to self / allies that propped player is stealthed (Halloween spell).
 */
void Prop_OnCondStealthed(PropifyTFPlayer player, bool bStealthed) {
	// Ensure alpha remains even if stealth is removed.
	bool bCloaked = TF2_IsPlayerInCondition(player.Index, TFCond_Cloaked);
	SetEntityAlpha(player, bStealthed || bCloaked? 80 : 255);
}

/**
 * Workaround to prevent the third-person camera from offsetting sniper zoom.
 */
void Prop_OnCondZoomed(PropifyTFPlayer player, bool bZoomed) {
	// Third-person mode according to Propify's internal bool
	if (player.ThirdPerson) {
		// If in the process of unscoping
		if (!bZoomed && !IsFakeClient(player.Index)) {
			int activeWeapon = GetEntPropEnt(player.Index, Prop_Send, "m_hActiveWeapon"),
			primaryWeapon = GetPlayerWeaponSlot(player.Index, TFWeaponSlot_Primary);
			
			/**
			 * If m_flRezoomTime is in the future, then that definitely (?) means cl_autorezoom == 1.
			 * Otherwise, either the player manually unscoped or cl_autorezoom == 0.
			 * 
			 * We assume that only primary weapons can use zoom, so m_flRezoomTime *should* exist.
			 */
			float flRezoomTime = GetEntPropFloat(primaryWeapon, Prop_Data, "m_flRezoomTime");
			float flNextPrimaryAttack = GetEntPropFloat(primaryWeapon, Prop_Data, "m_flNextPrimaryAttack");
			
			/**
			 * Quick hack:
			 * - if the next attack is shorter than ~0.2s, then put them in third person because they either:
			 *     1. unscoped manually, or
			 *     2. they ran out of ammo
			 * - if the next attack takes ~1s then the player is reloading and we'll check it again later
			 * 
			 * More accurate way to test this is if we know they're using cl_autoreload, then flRezoomTime < GetGameTime() if manual unscope
			 * TODO make sure these timings work regardless of client latency
			 */
			bool bManualUnscope = flNextPrimaryAttack - GetGameTime() < MANUAL_UNSCOPE_TIME_THRESHOLD;
		
			// If unscoped due to firing weapon and currently reloading; 
			if (activeWeapon == primaryWeapon && !bManualUnscope) {
				// Automatic rezoom is earlier than next chance of firing -- use that if available.
				float flCheckTime = flRezoomTime > GetGameTime() ? flRezoomTime : flNextPrimaryAttack;
				
				float flTimerLength = (flCheckTime - GetGameTime()) + (GetTickInterval() * 3);
				CreateTimer(flTimerLength, Timer_CheckPlayerRezoom, GetClientUserId(player.Index), TIMER_FLAG_NO_MAPCHANGE);
				return;
			}
		}
		
		SetVariantInt(bZoomed? 0 : 1);
		player.AcceptInput("SetForcedTauntCam");
	}
}

/**
 * Timer to check if the player has scoped back in after firing.
 * If not, return them to third-person mode if desired.
 */
public Action Timer_CheckPlayerRezoom(Handle timer, any data) {
	int client = GetClientOfUserId(view_as<int>(data));
	
	if (client > 0 && IsClientInGame(client)) {
		PropifyTFPlayer player = g_proppablePlayers[client];
		
		// Check to make sure they want to be in third-person again, just in case they unpropped while reloading
		if (!TF2_IsPlayerInCondition(client, TFCond_Zoomed) && player.ThirdPerson) {
			SetVariantInt(1);
			AcceptEntityInput(client, "SetForcedTauntCam");
		}
	}
	return Plugin_Handled;
}

/* Do fancy prop loading stuff */
public void OnMapStart() {
	LoadPropConfigs();
}

public Action AdminCmd_ReloadPropList(int client, int nArgs) {
	LoadPropConfigs();
	return Plugin_Handled;
}

void LoadPropConfigs() {
	g_PropList.Clear();
	g_PropConfigs.PushString("base");
	
	// TODO add map-specific config
	
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

#include "propify2/natives.sp"
