/**
 * Propify2 natives include file for the main plugin.
 * Mostly boilerplate.
 *
 * For API information, check "include/propify2.inc"
 */
public APLRes AskPluginLoad2(Handle hMySelf, bool bLate, char[] strError, int iMaxErrors) {
	if (GetEngineVersion() != Engine_TF2) {
		strcopy(strError, iMaxErrors, "Plugin only works on Team Fortress 2.");
		return APLRes_Failure;
	}
	
	g_PropList = new PropifyPropList();
	
	RegPluginLibrary("nosoop-propify2");
	
	CreateNative("Propify2_PropPlayer", Native_PropPlayer);
	CreateNative("Propify2_UnpropPlayer", Native_UnpropPlayer);
	CreateNative("Propify2_IsClientProp", Native_IsClientProp);
	
	CreateNative("Propify2_GetClientPropLock", Native_GetClientPropLock);
	CreateNative("Propify2_SetClientPropLock", Native_SetClientPropLock);
	
	CreateNative("Propify2_GetClientThirdPerson", Native_GetClientThirdPerson);
	CreateNative("Propify2_SetClientThirdPerson", Native_SetClientThirdPerson);
	
	CreateNative("Propify2_GetClientDisarmedState", Native_GetClientDisarmedState);
	
	CreateNative("Propify2_GetPropList", Native_GetPropList);
	
	// TODO implement natives for parser callbacks
	
	return APLRes_Success;
}

/* Get / Set client propped state */
public int Native_PropPlayer(Handle plugin, int nArgs) {
	PropifyTFPlayer player = g_proppablePlayers[GetNativeCell(1)];
	PropifyPropEntry entry = GetNativeCell(2);
	int flags = GetNativeCell(3);
	
	return player.Propify(entry, flags);
}
public int Native_UnpropPlayer(Handle plugin, int nArgs) {
	PropifyTFPlayer player = g_proppablePlayers[GetNativeCell(1)];
	player.Unpropify();
}
public int Native_IsClientProp(Handle plugin, int nArgs) {
	return g_proppablePlayers[GetNativeCell(1)].IsPropped;
}

/* Get / Set prop lock */
public int Native_GetClientPropLock(Handle plugin, int nArgs) {
	return g_proppablePlayers[GetNativeCell(1)].IsPropLocked;
}
public int Native_SetClientPropLock(Handle plugin, int nArgs) {
	g_proppablePlayers[GetNativeCell(1)].IsPropLocked = GetNativeCell(2);
}

/* Get / Set third-person mode */
public int Native_GetClientThirdPerson(Handle plugin, int nArgs) {
	return g_proppablePlayers[GetNativeCell(1)].ThirdPerson;
}
public int Native_SetClientThirdPerson(Handle plugin, int nArgs) {
	g_proppablePlayers[GetNativeCell(1)].ThirdPerson = GetNativeCell(2);
}

/* Get disarmed state */
public int Native_GetClientDisarmedState(Handle plugin, int nArgs) {
	return g_proppablePlayers[GetNativeCell(1)].IsDisarmed;
}

/* Gets a duplicate reference of the current prop list */
public int Native_GetPropList(Handle plugin, int nArgs) {
	SetNativeCellRef(1, CloneHandle(g_PropList));
}