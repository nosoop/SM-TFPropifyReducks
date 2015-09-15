#if defined __propify2_methodmaps_included
	#endinput
#endif

#define __propify2_methodmaps_included

#define PROP_MAX_NAME_LENGTH		48
#define PROPENTRY_NAME				"m_szName"
#define PROPENTRY_PATH				"m_szPath"

#define PROPIFYFLAG_NONE			(0 << 0)
#define PROPIFYFLAG_NO_WEAPONS		(1 << 0)	/* Disables weapons on player */


char HIDABLE_CLASSES[][] = {
    "tf_wearable",
    "tf_powerup_bottle",
    "tf_wearable_demoshield",
    "tf_weapon_spellbook"
};

/**
 * methodmap PropifyPropEntry
 * Prop entry containing the friendly name of a prop and the location of its model file.
 */
methodmap PropifyPropEntry < StringMap {
	property bool IsValid {
		public get() {
			char buffer[PLATFORM_MAX_PATH];
			return (this.GetString(PROPENTRY_NAME, buffer, sizeof(buffer)) && this.GetString(PROPENTRY_PATH, buffer, sizeof(buffer)));
		}
	}

	public PropifyPropEntry() {
		return view_as<PropifyPropEntry>(new StringMap());
	}
	
	public void SetName(const char[] name) {
		this.SetString(PROPENTRY_NAME, name);
	}
	
	public void GetName(char[] buffer, int maxlength) {
		this.GetString(PROPENTRY_NAME, buffer, maxlength);
	}
	
	public void SetPath(const char[] path) {
		this.SetString(PROPENTRY_PATH, path);
	}
	
	public void GetPath(char[] buffer, int maxlength) {
		this.GetString(PROPENTRY_PATH, buffer, maxlength);
	}
}


/**
 * methodmap PropifyTFPlayer
 * Class that describes a player that is allowed to be turned into a prop.
 */
bool __bClientIsPropped[MAXPLAYERS+1], __bClientIsDisarmed[MAXPLAYERS+1],
	__bClientIsPropLocked[MAXPLAYERS+1];
methodmap PropifyTFPlayer < CTFPlayer {
	property bool IsPropped {
		public get() { return __bClientIsPropped[this.Index]; }
	}
	property bool IsPropLocked {
		public get() { return __bClientIsPropLocked[this.Index]; }
		public set(bool bPropLocked) {
			if (!this.IsPropped) return;
			
			SetVariantInt(bPropLocked ? 0 : 1);
			AcceptEntityInput(this.Index, "SetCustomModelRotates");
			
			if (bPropLocked) {
				SetEntPropFloat(this.Index, Prop_Send, "m_flMaxspeed", 1.0);
			} else {
				TF2_StunPlayer(this.Index, 0.0, 0.0, TF_STUNFLAG_SLOWDOWN);
			}
			
			__bClientIsPropLocked[this.Index] = bPropLocked;
		}
	}
	property bool IsDisarmed {
		public get() { return __bClientIsDisarmed[this.Index]; }
	}
	property bool ThirdPerson {
		public set(bool bThirdPerson) {
			SetVariantInt(bThirdPerson ? 1 : 0);
			AcceptEntityInput(this.Index, "SetForcedTauntCam");
		}
	}
	
	public PropifyTFPlayer(int clientIndex) {
		PropifyTFPlayer player = view_as<PropifyTFPlayer>( new CTFPlayer(clientIndex) );
		__bClientIsPropped[clientIndex] = false;
		__bClientIsPropLocked[clientIndex] = false;
		
		return player;
	}
	
	/**
	 * Sets visibility on the player's cosmetics.
	 */
	public void SetPlayerCosmeticVisibility(bool bVisible) {
		for (int i = 0; i < sizeof(HIDABLE_CLASSES); i++) {
			int iCosmetic = -1;
			while((iCosmetic = FindEntityByClassname(iCosmetic, HIDABLE_CLASSES[i])) != -1) {      
				if (GetEntPropEnt(iCosmetic, Prop_Send, "m_hOwnerEntity") == this.Index) {
					SetCosmeticVisibility(iCosmetic, bVisible);
				}
			}
		}
	}
	
	public void RemoveWeapons() {
		TF2_RemoveAllWeapons(this.Index);
	}
	
	/**
	 * Set the player's prop.
	 */
	public bool SetProp(PropifyPropEntry entry, int flags = PROPIFYFLAG_NONE) {
		char path[PLATFORM_MAX_PATH];
		entry.GetPath(path, sizeof(path));
		this.SetCustomModel(path);
		
		if (flags & PROPIFYFLAG_NO_WEAPONS) {
			__bClientIsDisarmed[this.Index] = true;
			this.RemoveWeapons();
		}
		this.SetPlayerCosmeticVisibility(false);
		
		__bClientIsPropped[this.Index] = true;
		return true;
	}
	
	/**
	 * Reset prop state.
	 */
	public void Reset() {
		__bClientIsPropped[this.Index] = false;
		__bClientIsPropLocked[this.Index] = false;
		__bClientIsDisarmed[this.Index] = false;
	}
	
	public void Unprop() {
		bool wasDisarmed = this.IsDisarmed;
		
		this.Reset();
		
		if (this.Index > 0 && IsClientInGame(this.Index)) {
			this.SetCustomModel("");
			this.ThirdPerson = false;
			
			this.SetPlayerCosmeticVisibility(true);
			
			if (wasDisarmed) {
				int health = this.Health;
				this.Regenerate();
				this.Health = health;
			}
		}
	}
};

/**
 * methodmap PropifyPropList
 * An ArrayList containing a list of props.
 */
methodmap PropifyPropList < ArrayList {
	public PropifyPropList() {
		return view_as<PropifyPropList>( new ArrayList() );
	}
	
	public bool AddPropToList(const char[] name, const char[] modelPath) {
		// TODO determine where to do the precaching (here or onmapstart?)
		if (FileExists(modelPath, true)) {
			PropifyPropEntry entry = new PropifyPropEntry();
			entry.SetName(name);
			entry.SetPath(modelPath);
			
			this.Push(entry);
			return true;
		}
		return false;
	}
	
	/**
	 * Returns a clone of the PropifyPropEntry at the given index.
	 * Arguably, it's better to have a memory leak than to think you need to delete things.
	 */
	public PropifyPropEntry Get(int index) {
		PropifyPropEntry result = this.Get(index);
		return view_as<PropifyPropEntry>(CloneHandle(result));
	}
	
	/**
	 * Remove prop entries that are being truncated due to array resize.
	 */
	public void Resize(int newsize) {
		for (int i = newsize; i < this.Length; i++) {
			delete this.Get(i);
		}
		this.Resize(newsize);
	}
	
	/**
	 * Clean up prop entries.
	 */
	public void Clear() {
		for (int i = 0; i < this.Length; i++) {
			delete this.Get(i);
		}
		this.Clear();
	}
};

public void SetCosmeticVisibility(int iCosmetic, bool bVisible) {
	SetEntityRenderMode(iCosmetic, RENDER_TRANSCOLOR);
	SetEntityRenderColor(iCosmetic, 255, 255, 255, bVisible ? 255 : 0);
	
	AcceptEntityInput(iCosmetic, bVisible ? "EnableShadow" : "DisableShadow");
	
	SetVariantString(bVisible ? "ParticleEffectStart" : "ParticleEffectStop");
	AcceptEntityInput(iCosmetic, "DispatchEffect");
	
	// Shrink prop to ensure visibility (setting player glow would make this visible otherwise)
	SetEntPropFloat(iCosmetic, Prop_Send, "m_flModelScale", bVisible ? 1.0 : 0.0);
}
