#pragma semicolon 1

#include <sourcemod>
#include <propify2>
#include <sdktools>

#pragma newdecls required

#define PLUGIN_VERSION "0.1.2"
public Plugin myinfo = {
    name = "[TF2] Propify Standard Controls",
    author = "nosoop",
    description = "Provides a standard control scheme for props.",
    version = PLUGIN_VERSION,
    url = "https://github.com/nosoop"
};

bool g_bPropLockLocked[MAXPLAYERS+1], g_bThirdPersonLocked[MAXPLAYERS+1];

/**
 * Test if a propped client wants to toggle proplock or third-person mode.
 *
 * +jump removes proplock if necessary instead of blocking the jump, which plays hell with client-side
 * +attack toggles prop locking (i.e., player is locked into position and angle).
 * +attack2 toggles third-person state if possible (not allowed during humiliation).
 */
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon) {
	PropifyTFPlayer player = Propify2_GetPlayer(client);
	if (player.IsPropped && player.IsDisarmed) {
		if (buttons & IN_JUMP && player.IsPropLocked) {
			player.IsPropLocked = false;
		} else if (buttons & IN_ATTACK && !g_bPropLockLocked[client]) {
			player.IsPropLocked = !player.IsPropLocked;

			PrintHintText(client, "%s prop lock.", player.IsPropLocked ? "Enabled" : "Disabled");

			// Lock in the proplock settings for one second.
			g_bPropLockLocked[client] = true;
			CreateTimer(1.0, Timer_UnsetPropLockLock, client);
		}
		if (buttons & IN_ATTACK2 && !g_bThirdPersonLocked[client]) {
			// Toggling third-person mode during end-round is tricky, so let's not bother with that.
			if (GameRules_GetRoundState() != RoundState_Bonus && GameRules_GetRoundState() != RoundState_TeamWin) {
				player.ThirdPerson = !player.ThirdPerson;
				PrintHintText(client, "%s third person mode.", player.ThirdPerson ? "Enabled" : "Disabled");

				// Lock in the third-person settings for a second.
				g_bThirdPersonLocked[client] = true;
				CreateTimer(1.0, Timer_UnsetThirdPersonLock, client);
			}
		}
	}
	return Plugin_Continue;
}

public Action Timer_UnsetPropLockLock(Handle timer, any client) {
	g_bPropLockLocked[client] = false;
}

public Action Timer_UnsetThirdPersonLock(Handle timer, any client) {
	g_bThirdPersonLocked[client] = false;
}