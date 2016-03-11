g_PluginInfo =
{
	Name = "mmo",
	Date = "2016-03-13",
	Description = "Adds a Level System, Skills and Magic to Minecraft. You earn exp by killing Monsters and other Players. If you raise a level you get a skillpoint which you can use to improve your skills. Cast spells to kill even more enemies but you also need enough magic. For better balance with higher levels the usual damage a player does has been decreased and also the damage a player gets has been increased.",
	Commands = {
	["/skills"] = {
		Handler = skills,
		HelpString = "shows your skills",
		Permission = "mmo.skills",
		ParameterCombinations =
		{
			{
				Params = "skill",
				Help = "give a skillpoint to the given skill",
			},
		},
	},
	["/battlelog"] = {
		Handler = battlelog,
		HelpString = "turns your battlelog on or off",
		Permission = "mmo.battlelog",
	},
	["/mmo"] = {
		HelpString = "options statusbar, battlelog and join",
		Permission = "mmo.help",
		Handler = mmo_join,
		ParameterCombinations =
		{
			{
				Params = "statusbar",
				Handler = statusbar,
				Help = "turns your statusbar on or off",
				Permission = "mmo.statusbar",
			},
			{
				Params = "battlelog",
				Handler = battlelog,
				Help = "turns your battlelog on or off",
				Permissions = "mmo.battlelog",
			},
			{
				Params = "join",
				Handler = mmo_join,
				Help = "Join the Alliance or the Horde",
				Permission = "mmo.join",
				ParameterCombinations = {
					Params = "fraction",
					Handler = mmo_join,
					Help = "Join a Fraction",
					Permission = "mmo.join",
				},
			},
		},
	},
	["/spell"] = {
		Handler = spell,
		HelpString = "shows all spells",
		Permission = "mmo.spell",
		ParameterCombinations =
		{
			{
				Params = "spell",
				Help = "cast the given spell",
			},
		},
	},
},
	ConsoleCommands = {},
	Permissions = {
		["mmo.spell"] =
		{
			Description = "Allows to cast Spells",
			RecommendedGroups = "players",
		},
		["mmo.skills"] =
		{
			Description = "Allows to see and set Skills",
			RecommendedGroups = "players",
		},
		["mmo.battlelog"] =
		{
			Description = "allows to turn battlelog on or off",
			RecommendedGroups = "players",
		},
		["mmo.statusbar"] =
		{
			Description = "allows to turn statusbar on or off",
			RecommendedGroups = "players",
		},
		["mmo.join"] =
		{
			Description = "allows to join a fraction",
			RecommendedGroups = "players",
		},
		["mmo.help"] =
		{
			Description = "allows the use of /mmo",
			RecommendedGroups = "players",
		},
	},
}
