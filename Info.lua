g_PluginInfo =
{
	Name = "mmo",
	Date = "2015-10-13",
	Description = "a Plugin to gain exp and set skillpoints",
	Commands = {
	["/skills"] = {

	}
	,
	["/battlelog"] = {

	}
	,
	["/spell"] = {

	}
},
	ConsoleCommands = {},
	Permissions =
	{
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
	}
}
