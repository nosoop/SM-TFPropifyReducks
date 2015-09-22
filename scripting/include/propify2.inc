#if defined _propify2_included
  #endinput
#endif
#define _propify2_included

#include <propify2_constants>

#define GAME_TF2
#include <thelpers/thelpers>

public SharedPlugin __pl_propify = {
    name = "nosoop-propify2",
    file = "propify_reducks.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

public void __pl_propify_SetNTVOptional() {
	MarkNativeAsOptional("Propify2_PropPlayer");
	MarkNativeAsOptional("Propify2_UnpropPlayer");
	MarkNativeAsOptional("Propify2_IsClientProp");

	MarkNativeAsOptional("Propify2_GetClientPropLock");
	MarkNativeAsOptional("Propify2_SetClientPropLock");
	
	MarkNativeAsOptional("Propify2_GetClientThirdPerson");
	MarkNativeAsOptional("Propify2_SetClientThirdPerson");
	
	MarkNativeAsOptional("Propify2_GetClientDisarmedState");
	
	MarkNativeAsOptional("Propify2_GetPropList");
}

native bool Propify2_PropPlayer(int client, PropifyPropEntry entry, int flags);
native void Propify2_UnpropPlayer(int client);
native bool Propify2_IsClientProp(int client);

native bool Propify2_GetClientPropLock(int client);
native void Propify2_SetClientPropLock(int client, bool bLocked);

native bool Propify2_GetClientThirdPerson(int client);
native void Propify2_SetClientThirdPerson(int client, bool bEnabled);

native bool Propify2_GetClientDisarmedState(int client);

methodmap PropifyPropEntry < StringMap {
	/* No exposed methods in library just yet. */
}

methodmap PropifyTFPlayer < CTFPlayer {
	property bool IsPropped {
		public get() { return Propify2_IsClientProp(this.Index); }
	}
	property bool IsPropLocked {
		public get() { return Propify2_GetClientPropLock(this.Index); }
		public set(bool bPropLocked) {
			Propify2_SetClientPropLock(this.Index, bPropLocked);
		}
	}
	property bool IsDisarmed {
		public get() {
			return Propify2_GetClientDisarmedState(this.Index);
		}
	}
	property bool ThirdPerson {
		public get() {
			return Propify2_GetClientThirdPerson(this.Index);
		}
		public set(bool bThirdPerson) {
			Propify2_SetClientThirdPerson(this.Index, bThirdPerson);
		}
	}
	
	/**
	 * Set the player's prop.
	 */
	public bool SetPropModel(PropifyPropEntry entry, int flags = PROPIFYFLAG_NONE) {
		return Propify2_PropPlayer(this.Index, entry, flags);
	}
	
	/**
	 * Unsets the player's prop.
	 */
	public void Unprop() {
		return Propify2_UnpropPlayer(this.Index);
	}
};

methodmap PropifyPropList < ArrayList {
	public PropifyPropEntry Get(int index) {
		PropifyPropEntry result = this.Get(index);
		return view_as<PropifyPropEntry>(CloneHandle(result));
	}
}

/**
 * Retrieves an existing PropifyTFPlayer "instance".
 * (For semantics purposes; don't want plugin authors to create a "new" instance.)
 */
public PropifyTFPlayer Propify2_GetPlayer(int iClient) {
	return view_as<PropifyTFPlayer>( new CTFPlayer(iClient) );
}

/**
 * Retrieves the main plugin's list of usable props.
 * This creates a reference to the prop list will be used for the lifetime of the main plugin.
 */
native void Propify2_GetPropList(PropifyPropList &propList);
