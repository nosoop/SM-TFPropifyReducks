#if defined __propify2_dirtykvparser_included
	#endinput
#endif

#define __propify2_dirtykvparser_included

/**
 * Parses one named single-level section of a KeyValues file.
 *
 * Is this a terrible abuse of 1.7's transitional syntax?  Yeah.  It probably is.
 */
typedef KeyValueSectionCallback = function void(const char[] key, const char[] value);
methodmap KeyValueSectionParser < StringMap {
	
	public KeyValueSectionParser() {
		return view_as<KeyValueSectionParser>( new StringMap() );
	}
	
	/**
	 * Adds a function to a list that, when passing over a given section, will be called once for every key-value pair.
	 */
	public void AddCallbackFunction(const char[] section, Handle plugin, KeyValueSectionCallback callback) {
		Handle privateForward = null;
		
		if (!this.GetValue(section, privateForward)) {
			privateForward = CreateForward(ET_Ignore, Param_String, Param_String);
			this.SetValue(section, privateForward, true);
		}
		AddToForward(privateForward, plugin, callback);
	}
	
	/**
	 * Reads the given KeyValues instance, passing key/value pairs from any valid subsections.
	 */
	public void Parse(KeyValues kv) {
		char key[96], value[PLATFORM_MAX_PATH];
		
		StringMapSnapshot sections = this.Snapshot();
		char section[PLATFORM_MAX_PATH];
		
		// Just search for sections that we know we need to check.
		Handle privateForward = null;
		for (int i = 0; i < sections.Length; i++) {
			sections.GetKey(i, section, sizeof(section));
			
			if (kv.JumpToKey(section, false) && this.GetValue(section, privateForward)) {
				if (kv.GotoFirstSubKey(false)) {
					do {
						kv.GetSectionName(key, sizeof(key));
						kv.GetString(NULL_STRING, value, sizeof(value));
						
						Call_StartForward(privateForward);
						Call_PushString(key);
						Call_PushString(value);
						Call_Finish();
					} while (kv.GotoNextKey(false));
					kv.GoBack();
				}
				kv.GoBack();
			}
		}
		
		delete sections;
	}
}
