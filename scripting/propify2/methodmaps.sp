#if defined __propify2_methodmaps_included
	#endinput
#endif

#define __propify2_methodmaps_included

#include <propify2_constants>

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
	__bClientIsPropLocked[MAXPLAYERS+1], __bClientIsInThirdPerson[MAXPLAYERS+1];
methodmap PropifyTFPlayer < CTFPlayer {
	property bool IsPropped {
		public get() { return __bClientIsPropped[this.Index]; }
	}
	property bool IsPropLocked {
		public get() { return __bClientIsPropLocked[this.Index]; }
		public set(bool bPropLocked) {
			if (!this.IsPropped) return;
			
			SetVariantInt(bPropLocked ? 0 : 1);
			this.AcceptInput("SetCustomModelRotates");
			
			if (bPropLocked) {
				this.SetPropFloat(Prop_Send, "m_flMaxspeed", 1.0);
			} else {
				TF2_StunPlayer(this.Index, 0.0, 0.0, TF_STUNFLAG_SLOWDOWN);
			}
			
			__bClientIsPropLocked[this.Index] = bPropLocked;
		}
	}
	property bool IsDisarmed {
		public get() { return __bClientIsDisarmed[this.Index]; }
	}
	property bool DrawViewModel {
		public set(bool bEnabled) {
			return this.SetProp(Prop_Send, "m_bDrawViewmodel", bEnabled);
		}
	}
	property bool ThirdPerson {
		public get() {
			return __bClientIsInThirdPerson[this.Index];
		}
		public set(bool bEnabled) {
			SetVariantInt(bEnabled ? 1 : 0);
			this.AcceptInput("SetForcedTauntCam");
			
			__bClientIsInThirdPerson[this.Index] = bEnabled;
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
			CBaseEntity cosmetic = null;
			while((cosmetic = CBaseEntity.FindByClassname(cosmetic, HIDABLE_CLASSES[i])) != null) {      
				if (cosmetic.GetPropEnt(Prop_Send, "m_hOwnerEntity").Index == this.Index) {
					SetWearableVisibility(cosmetic, bVisible);
				}
			}
		}
	}
	
	/**
	 * Prevent the player from using their weapons.
	 */
	public void Disarm() {
		// TODO change m_flNextPrimaryAttack instead of removing weapons?
		TF2_RemoveAllWeapons(this.Index);
		this.DrawViewModel = false;
	}
	
	/**
	 * Set the player's prop.  (Changed from SetProp because of transitional helper conflicts.)
	 */
	public bool Propify(PropifyPropEntry entry, int flags = PROPIFYFLAG_NONE) {
		char path[PLATFORM_MAX_PATH];
		entry.GetPath(path, sizeof(path));
		this.SetCustomModel(path);
		
		if (flags & PROPIFYFLAG_NO_WEAPONS) {
			__bClientIsDisarmed[this.Index] = true;
			this.Disarm();
		}
		this.SetPlayerCosmeticVisibility(false);
		
		__bClientIsPropped[this.Index] = true;
		
		this.IsPropLocked = false;
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
	
	public void Unpropify() {
		bool wasDisarmed = this.IsDisarmed;
		
		this.Reset();
		
		if (this.Index > 0 && this.IsInGame) {
			this.SetCustomModel("");
			this.ThirdPerson = false;
			
			this.SetPlayerCosmeticVisibility(true);
			
			// Remove cloak effect 
			// TODO merge player condition changes into fewer methods
			SetEntityAlpha(this, 255);
			
			if (wasDisarmed) {
				int health = this.Health;
				this.Regenerate();
				this.Health = health;
				
				this.DrawViewModel = true;
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

public void SetEntityVisibility(CBaseEntity entity, bool bVisible) {
	entity.RenderMode = RENDER_TRANSCOLOR;
	entity.SetRenderColor(255, 255, 255, bVisible ? 255 : 0);
	
	entity.AcceptInput(bVisible ? "EnableShadow" : "DisableShadow");
}

public void SetEntityAlpha(CBaseEntity entity, int alpha) {
	int r, g, b;
	entity.GetRenderColor(r, g, b);
	
	entity.RenderMode = RENDER_TRANSCOLOR;
	entity.SetRenderColor(r, g, b, alpha);
}

public void SetWearableVisibility(CBaseEntity cosmetic, bool bVisible) {
	SetEntityVisibility(cosmetic, bVisible);

	SetVariantString(bVisible ? "ParticleEffectStart" : "ParticleEffectStop");
	cosmetic.AcceptInput("DispatchEffect");
	
	// Shrink prop to ensure visibility (setting player glow would make this visible otherwise)
	cosmetic.SetPropFloat(Prop_Send, "m_flModelScale", bVisible ? 1.0 : 0.0);
}
