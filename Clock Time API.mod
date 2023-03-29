return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`Clock Time API` mod must be lower than Vermintide Mod Framework in your launcher's load order.")

		new_mod("Clock Time API", {
			mod_script       = "scripts/mods/Clock Time API/Clock Time API",
			mod_data         = "scripts/mods/Clock Time API/Clock Time API_data",
			mod_localization = "scripts/mods/Clock Time API/Clock Time API_localization",
		})
	end,
	packages = {
		"resource_packages/Clock Time API/Clock Time API",
	},
}
