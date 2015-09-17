#include <sourcemod>

#define GAME_TF2
#include <thelpers/thelpers>

#pragma semicolon 1
#pragma newdecls required

#include <propify2>

#define PLUGIN_VERSION "0.1.0"
public Plugin myinfo = {
    name = "[TF2] Propify End-Round",
    author = "nosoop",
    description = "Camouflage yourself as the winning team hunts you down, you loser!",
    version = PLUGIN_VERSION,
    url = "https://github.com/nosoop"
};

PropifyPropList g_PropList = null;

public void OnPluginStart() {
	Propify2_GetPropList(g_PropList);

	HookEvent("teamplay_round_win", Event_RoundWin);
}

public void Event_RoundWin(Handle event, char[] name, bool dontBroadcast) {
	TFTeam winningTeam = view_as<TFTeam>(GetEventInt(event, "team"));
	
	for (int i = MaxClients; i > 0; --i) {
		PropifyTFPlayer player = Propify2_GetPlayer(i);
		
		if (player == null) {
			continue;
		}
		
		// Don't prop existing players that are not part of the losing team.
		bool bInvalidPlayers = !player.IsInGame;
		bool bNonPlayingTeams = player.Team == TFTeam_Spectator || player.Team == TFTeam_Unassigned;
		bool bWinners = player.Team == winningTeam;
		if (bInvalidPlayers || bNonPlayingTeams || bWinners) { continue; }
		
		// _Never_ prop players that may become ghosts.  That causes crashes, or at least they did.
		bool bAreGhosts = TF2_IsPlayerInCondition(i, TFCond_HalloweenInHell)
				|| TF2_IsPlayerInCondition(i, TFCond_HalloweenGhostMode);
		if (bAreGhosts) { continue; }
		
		// Don't bother if they're propped already.
		if (player.IsPropped) { continue; }
		
		if (!player.IsAlive) {
			TF2_RespawnPlayer(player.Index);
		}
		
		if (player.IsAlive) {
			CBaseEntity ragdoll = player.GetPropEnt(Prop_Send, "m_hRagdoll");
			if (ragdoll.IsValid) {
				ragdoll.AcceptInput("Kill");
			}
			
			PropifyPropEntry entry = g_PropList.Get(GetRandomInt(0, g_PropList.Length - 1));
			player.SetProp(entry, PROPIFYFLAG_NO_WEAPONS);
			
			// TODO expose name / path of prop to notify the player, also show center text for win / lose / stalemate
			
			delete entry;
			
			player.ThirdPerson = true;
		}
	}
}