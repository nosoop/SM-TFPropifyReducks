#include <sourcemod>

#define GAME_TF2
#include <thelpers/thelpers>

#pragma semicolon 1
#pragma newdecls required

#include <propify2>

#define PLUGIN_VERSION "0.3.0"
public Plugin myinfo = {
    name = "[TF2] Propify End-Round",
    author = "nosoop",
    description = "Camouflage yourself as the winning team hunts you down, you loser!",
    version = PLUGIN_VERSION,
    url = "https://github.com/nosoop"
};

bool g_bPropify2Loaded;
PropifyPropList g_PropList = null;

public void OnPluginStart() {
	LoadTranslations("propify2_endround.phrases");
}

public void Event_RoundWin(Handle event, char[] name, bool dontBroadcast) {
	if (!g_bPropify2Loaded) {
		return;
	}

	TFTeam winningTeam = view_as<TFTeam>(GetEventInt(event, "team"));
	
	for (int i = MaxClients; i > 0; --i) {
		PropifyTFPlayer player = Propify2_GetPlayer(i);
		
		if (player == null) {
			continue;
		}
		
		// Ignore players that...
		if (!player.IsInGame // are not in game,
				|| player.Team == TFTeam_Spectator // are not on a playing team,
				|| player.Team == TFTeam_Unassigned) {
			continue;
		} else if (player.Team == winningTeam) { // are not on the winning team,
			PrintToChat(i, "%T", "Chat Winner Prop Hunt", i);
			continue;
		} else if (TF2_IsPlayerInCondition(i, TFCond_HalloweenInHell) // may become ghosts or already are
				|| TF2_IsPlayerInCondition(i, TFCond_HalloweenGhostMode) // (that causes crashes, or at least they did),
				|| player.IsPropped) { // have already been turned into props
			continue;
		}
		
		if (!player.IsAlive) {
			TF2_RespawnPlayer(player.Index);
		}
		
		if (player.IsAlive) {
			PropifyPropEntry entry = g_PropList.Get(GetRandomInt(0, g_PropList.Length - 1));
			player.SetPropModel(entry, PROPIFYFLAG_NO_WEAPONS);
			
			// TODO show center text for win / lose / stalemate?
			char propName[PROP_MAX_NAME_LENGTH + 2];
			entry.GetName(propName, sizeof(propName));
			
			// TODO colorize text?
			
			if (winningTeam != TFTeam_Unassigned) {
				PrintToChat(i, "%T", "Chat Loser Prop Transformation", i, propName);
			} else {
				PrintToChat(i, "%T", "Chat Stalemate Prop Transformation", i, propName);
			}
			
			delete entry;
			
			player.ThirdPerson = true;
		}
	}
	
	// Disable all built sentries.
	CBaseEntity sentry = null;
	while ((sentry = CBaseEntity.FindByClassname(sentry, "obj_sentrygun")) != null) {
		sentry.AcceptInput("Disable");
	}
}

/**
 * Disable all redeployed sentries during humiliation.
 */
public void Event_BuiltObject(Handle event, char[] name, bool dontBroadcast) {
	if (GameRules_GetRoundState() == RoundState_TeamWin) {
		CBaseEntity sentry = view_as<CBaseEntity>(GetEventInt(event, "index"));
		
		if (sentry.IsValid) {
			sentry.AcceptInput("Disable");
		}
	}
}

/**
 * Checks for the existence of the nosoop-propify2 library.
 */
public void OnAllPluginsLoaded() {
	bool bLastState = g_bPropify2Loaded;
	Propify2LibraryCheck((g_bPropify2Loaded = LibraryExists("nosoop-propify2")) != bLastState);
}

public void OnLibraryRemoved(const char[] name) {
	bool bLastState = g_bPropify2Loaded;
	Propify2LibraryCheck((g_bPropify2Loaded &= !StrEqual(name, "nosoop-propify2")) != bLastState);
}

public void OnLibraryAdded(const char[] name) {
	bool bLastState = g_bPropify2Loaded;
	Propify2LibraryCheck((g_bPropify2Loaded |= StrEqual(name, "nosoop-propify2")) != bLastState);
}

public void Propify2LibraryCheck(bool bHasChanged) {
	if (bHasChanged) {
		if (g_bPropify2Loaded) {
			Propify2_GetPropList(g_PropList);
			
			HookEvent("teamplay_round_win", Event_RoundWin);
			HookEvent("player_builtobject", Event_BuiltObject);
		} else {
			delete g_PropList;
			UnhookEvent("teamplay_round_win", Event_RoundWin);
			UnhookEvent("player_builtobject", Event_BuiltObject);
		}
	}
}
