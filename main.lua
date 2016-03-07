-- mmo by danny9484
PLUGIN = nil

function Initialize(Plugin)
	Plugin:SetName("mmo")
	Plugin:SetVersion(1)

	-- Hooks
	cPluginManager:AddHook(cPluginManager.HOOK_KILLED, MyOnKilled);
	cPluginManager:AddHook(cPluginManager.HOOK_TAKE_DAMAGE, MyOnTakeDamage);
	cPluginManager:AddHook(cPluginManager.HOOK_PLAYER_JOINED, MyOnPlayerJoined);
	cPluginManager:AddHook(cPluginManager.HOOK_PLAYER_SPAWNED, MyOnPlayerSpawned);
	cPluginManager:AddHook(cPluginManager.HOOK_WORLD_TICK, MyOnWorldTick);
	cPluginManager:AddHook(cPluginManager.HOOK_DISCONNECT, MyOnDisconnect);

	PLUGIN = Plugin -- NOTE: only needed if you want OnDisable() to use GetName() or something like that

	-- Command Bindings
	cPluginManager.BindCommand("/skills", "mmo.skills", skills, " ~ list skills or add skillpoints")
	cPluginManager.BindCommand("/battlelog", "mmo.battlelog", battlelog, " - turn battlelog on / off")
	cPluginManager.BindCommand("/spell", "mmo.spell", spell, " ~ cast a spell")
	cPluginManager.BindCommand("/mmo", "mmo.join", mmo_join, " ~ join a fraction")

	-- Database stuff
	db = cSQLiteHandler("mmo.sqlite")
	create_database()

	-- declare global variables
	spell_counter = 1
	spells = {}
	counter = 0
	stats = {}

	-- read Config

	local IniFile = cIniFile();
	if (IniFile:ReadFile(PLUGIN:GetLocalFolder() .. "/config.ini")) then
		exp_multiplicator = IniFile:GetValue("Settings", "exp_multiplicator")
		battlelog_default = IniFile:GetValue("Settings", "battlelog_default")
		statusbar = IniFile:GetValue("Settings", "statusbar")
		    while IniFile:GetValue("Spells", tostring(spell_counter)) ~= "" do
	      spells[spell_counter] = IniFile:GetValue("Spells", tostring(spell_counter))
				local IniFile_spell = cIniFile();
				if IniFile_spell:ReadFile(PLUGIN:GetLocalFolder() .. "/spells/" .. spells[spell_counter] .. "/Info.ini") then
					local name = spells[spell_counter]
					spells[spell_counter] = {}
					spells[spell_counter]["name"] = name
					spells[spell_counter]["author"] = IniFile_spell:GetValue("Spell", "Author")
					spells[spell_counter]["description_en"] = IniFile_spell:GetValue("Spell", "Description_en")
					spells[spell_counter]["magic"] = IniFile_spell:GetValue("Spell", "Magic")
					spells[spell_counter]["cooldown"] = IniFile_spell:GetValue("Spell", "Cooldown")
					spells[spell_counter]["cast_time"] = IniFile_spell:GetValue("Spell", "Casttime")
	      	LOG(Plugin:GetName() .. ": Spell Initialized: " .. spells[spell_counter]["name"])
				else
					LOG(spells[spell_counter] .. ": Spell Initialization failed")
				end
	      spell_counter = spell_counter + 1
	    end
	else
	  LOG(Plugin:GetName() .. ": can't read config.ini")
	  return false
	end

	-- Use the InfoReg shared library to process the Info.lua file:
	dofile(cPluginManager:GetPluginsPath() .. "/InfoReg.lua")
	--RegisterPluginInfoCommands()
	--RegisterPluginInfoConsoleCommands()

	LOG("Initialized " .. Plugin:GetName() .. " v." .. Plugin:GetVersion())
	return true
end

function OnDisable()
	LOG(PLUGIN:GetName() .. " is shutting down...")
end

function MyOnDisconnect(Client, Reason)
	save_player(Client:GetPlayer())
	return true
end

function MyOnPlayerSpawned(Player)
	set_stats(Player, "health", Player:GetMaxHealth())
	Player:SetInvulnerableTicks(100) -- somebug caused spawn in air as a workaround for no fall damage
end

function mmo_join(command, player)
	local stats = get_stats(player)
	if stats[1]["fraction"] == nil or stats[1]["fraction"] == "" then
		if command[3] == "horde" then
			set_stats(player, "fraction", "alliance")
			player:SendMessage("You joined the Horde")
			return true
		end
		if command[3] == "alliance" then
			set_stats(player, "fraction", "alliance")
			player:SendMessage("You joined the Alliance")
			return true
		end
	end
	if stats[1]["fraction"] ~= "" then
		player:SendMessage("You already joined a Fraction")
		return true
	end
	player:SendMessage("usage /mmo join horde/alliance")
	return true
end

function save_player(player)
	local stats = get_stats(player)
	local updateList = cUpdateList()
	:Update("name", stats[1]["name"])
	:Update("exp", stats[1]["exp"])
	:Update("health", stats[1]["health"])
	:Update("health_before", stats[1]["health_before"])
	:Update("strength", stats[1]["strength"])
	:Update("agility", stats[1]["agility"])
	:Update("luck", stats[1]["luck"])
	:Update("intelligence", stats[1]["intelligence"])
	:Update("magic", stats[1]["magic"])
	:Update("magic_max", stats[1]["magic_max"])
	:Update("endurance", stats[1]["endurance"])
	:Update("skillpoints", calc_available_skill_points(player))
	:Update("battlelog", stats[1]["battlelog"])
	:Update("fraction", stats[1]["fraction"])
	local whereList = cWhereList()
	:Where("name", player:GetName())
	local res = db:Update("mmo", updateList, whereList)
	if stats[1]["last_killedx"] ~= nil and stats[1]["last_killedy"] ~= nil and stats[1]["last_killedz"] ~= nil then
		local updateList = cUpdateList()
		:Update("last_killedx", stats[1]["last_killedx"])
		:Update("last_killedy", stats[1]["last_killedy"])
		:Update("last_killedz", stats[1]["last_killedz"])
		local whereList = cWhereList()
		:Where("name", player:GetName())
		local res = db:Update("mmo", updateList, whereList)
	end
end

function spell(command, player)
 local counter = spell_counter - 1
	if #command == 1 then
		while counter ~= 0 do
			player:SendMessage("/" .. spells[counter]["name"] .. " | " .. spells[counter]["description_en"] .. " | Magic: " .. spells[counter]["magic"])
			counter = counter - 1
		end
		return true
	end
	if #command >= 2 then
		counter = spell_counter - 1
		while counter ~= 0 do
			if command[2] == spells[counter]["name"] then
				if rem_magic(player, tonumber(spells[counter]["magic"])) then
					assert(loadfile(PLUGIN:GetLocalFolder() .. "/spells/" .. spells[counter]["name"] .. "/" .. spells[counter]["name"] .. ".lua"))(command, player)
				end
			end
			counter = counter - 1
		end
	end
	return true
end

function rem_magic(player, amount)
	local stats = get_stats(player)

	if tonumber(stats[1]["magic"]) >= amount then
		local magic_after = tonumber(stats[1]["magic"]) - amount
		-- LOG(magic_after)
		set_stats(player, "magic", magic_after)
		return true
	else
		send_battlelog(player, "not enough Magic!")
		return false
	end
end

function add_magic_regeneration(player, percentage, stats)
	if tonumber(stats[1]["magic"]) < tonumber(stats[1]["magic_max"]) then
		local magic_after = stats[1]["magic"] + math.floor(stats[1]["magic_max"] * percentage / 10) / 10
		set_stats(player, "magic", magic_after)
		end
end

function add_health_regeneration(player, stats)
	if tonumber(stats[1]["health_before"]) < player:GetHealth() and tonumber(stats[1]["health"]) < player:GetMaxHealth() then
		set_stats(player, "health", stats[1]["health"] + 1)
	end
	player:SetHealth(tonumber(stats[1]["health"]) / (player:GetMaxHealth() / 20))
	set_stats(player, "health_before", player:GetHealth())
end

function MyOnWorldTick(World, TimeDelta)
	-- add MAGIC regeneration
	local callback = function(player)
		local stats = get_stats(player)
		add_magic_regeneration(player, 1, stats)
		add_health_regeneration(player, stats)
		counter = 75
		player:SendAboveActionBarMessage("Health: " .. stats[1]["health"] .. " / " .. player:GetMaxHealth() .. " | Magic: " .. stats[1]["magic"] .. " / " .. stats[1]["magic_max"] .. " | lvl: " .. calc_level(stats[1]["exp"]) .. " | exp: " .. stats[1]["exp"] .. " / " .. calc_exp_to_level(calc_level(stats[1]["exp"]) + 1))
	end
	counter = counter + 1
	if counter > 50 then
		World:ForEachPlayer(callback)
		if counter == 75 then
			counter = 0
		end
	end
	if counter > 100 then
		counter = 0
	end
end

function battlelog(command, player)
	local stats = get_stats(player)
	if stats[1]["battlelog"] == "0" then
		set_stats(player, "battlelog", "1")
		player:SendMessage("turned Battlelog on")
		return true
	end
	if stats[1]["battlelog"] == "1" then
		set_stats(player, "battlelog", "0")
		player:SendMessage("turned Battlelog off")
		return true
	end
end

function MyOnPlayerJoined(Player)
	if checkifexist(Player) then
		Player:SendMessage("Welcome back")
	else
		Player:SendMessage("Welcome new Player")
		register_new_player(Player)
	end
	show_stats(Player)
	local stats = get_stats(Player)
	Player:SetMaxHealth(20 * (stats[1]["endurance"]))
end

function show_stats (Player)
	 local stats = get_stats(Player)
	 Player:SendMessage("exp: " .. stats[1]["exp"])
	 Player:SendMessage("Strength: " .. stats[1]["strength"])
	 Player:SendMessage("Agility: " .. stats[1]["agility"])
	 Player:SendMessage("Luck: " .. stats[1]["luck"])
	 Player:SendMessage("Intelligence: " .. stats[1]["intelligence"])
	 Player:SendMessage("Endurance: " .. stats[1]["endurance"])
	 Player:SendMessage("Level: " .. calc_level(stats[1]["exp"]))
	 Player:SendMessage("Magic: " .. stats[1]["magic"] .. " of " .. stats[1]["magic_max"])
	 if stats[1]["fraction"] == nil  or stats[1]["fraction"] == "" then
	 	Player:SendMessage("Use /mmo join horde/alliance to join a fraction")
	 else
		Player:SendMessage("Fraction: " .. stats[1]["fraction"])
	 end
	 if calc_available_skill_points(Player) ~= 0 then
		 Player:SendMessage("Available Skillpoints: " .. calc_available_skill_points(Player))
	 end
end

function get_stats_initialize(Player)
	local whereList = cWhereList()
	:Where("name", Player:GetName())
	local res = db:Select("mmo", "*", whereList)
	return res
end

function set_stats(player, stat, amount)
	stats[player:GetName()][1][stat] = amount
end

function get_stats(player)
	if stats == nil then
		stats[player:GetName()] = get_stats_initialize(player)
	end
	if stats[player:GetName()] == nil then
		stats[player:GetName()] = get_stats_initialize(player)
	end
	res = stats[player:GetName()]
	return res
end

function checkifexist(Player)
	-- return true if player exists in db otherwise false
	res = get_stats(Player)
	if res[1] == nil then
		return false
	end
	if res[1]["name"] == Player:GetName() then
		return true
	end
	return false
end

function register_new_player(Player)
	-- register new player in database
	local insertList = cInsertList()
	:Insert("name", Player:GetName())
	:Insert("exp", 0)
	:Insert("health", 20)
	:Insert("health_before", 20)
	:Insert("strength", 1)
	:Insert("agility", 1)
	:Insert("luck", 1)
	:Insert("intelligence", 1)
	:Insert("magic", 10)
	:Insert("magic_max", 10)
	:Insert("endurance", 1)
	:Insert("skillpoints", 0)
	:Insert("battlelog", 1)
	local res = db:Insert("mmo", insertList)
	stats[Player:GetName()][1] = {}
	set_stats(Player, "name", Player:GetName())
	set_stats(Player, "exp", 0)
	set_stats(Player, "health", 20)
	set_stats(Player, "health_before", 20)
	set_stats(Player, "strength", 1)
	set_stats(Player, "agility", 1)
	set_stats(Player, "luck", 1)
	set_stats(Player, "intelligence", 1)
	set_stats(Player, "endurance", 1)
	set_stats(Player, "skillpoints", 0)
	set_stats(Player, "battlelog", "1")
	set_stats(Player, "magic", 100)
	set_stats(Player, "magic_max", 100)
end

function MyOnKilled(Victim, TDI)
	if Victim:IsPlayer() then
		set_stats(Victim, "last_killedx", Victim:GetPosX())
		set_stats(Victim, "last_killedy", Victim:GetPosY())
		set_stats(Victim, "last_killedz", Victim:GetPosZ())
	end
	local exp = 0
	if TDI.Attacker ~= nil and TDI.Attacker:IsPlayer() then
		local player = tolua.cast(TDI.Attacker, "cPlayer")
		if TDI.Attacker ~= nil and Victim:IsPlayer() and TDI.Attacker:IsPlayer() then
			local stats = get_stats(Victim)
			exp = 25 * calc_level(stats[1]["exp"])
			send_battlelog(player, "You killed a Player")
		end
		if (TDI.Attacker ~= nil and TDI.Attacker:IsPlayer() and Victim:IsMob()) then
			-- TODO extend monsterlist
			if Victim:GetMobFamily() == 0 then
				send_battlelog(player, "You killed a Monster")
				exp = 5
			end
			if Victim:GetMobFamily() == 1 then
				send_battlelog(player, "You killed a Animal")
				exp = 1
			end
			if Victim:GetMobFamily() == 3 then
				send_battlelog(player, "You killed a Water Animal")
				exp = 1
			end
			if Victim:GetMobFamily() == 2 then
				send_battlelog(player, "You killed Something Mysterious")
				exp = 5
			end
		end
		if TDI.Attacker ~= nil and TDI.Attacker:IsPlayer() and give_exp(exp, player) then
			local lvl = calc_level(get_exp(player))
			send_battlelog(player, "Level UP! you are now Level " .. lvl)
		end
	end
end

function calc_available_skill_points(player)
	-- calculate not given skill points
	local stats = get_stats(player)
	local available_points = calc_level(tonumber(stats[1]["exp"])) + 4 - (tonumber(stats[1]["strength"]) + tonumber(stats[1]["endurance"]) + tonumber(stats[1]["intelligence"]) + tonumber(stats[1]["agility"]) + tonumber(stats[1]["luck"]))
	return available_points
end

function add_skill(player, skillname)
	-- add skill point to the given skill if skillpoints available
	if calc_available_skill_points(player) > 0 then
		local stats = get_stats(player)
		set_stats(player, skillname[2], tonumber(stats[1][skillname[2]]) + 1)
		if skillname[2] == "endurance" then
			player:SetMaxHealth(player:GetMaxHealth() + 20)
		end
		if skillname[2] == "intelligence" then
			set_stats(player, "magic_max", stats[1]["magic_max"] + 100)
		end
		return true
	end
	return false
end

function skills(skillname, player)
	if skillname[2] == nil then
		show_stats(player)
		return true
	end
	if skillname[2] == "strength" and add_skill(player, skillname) then
		player:SendMessage("added 1 Point to Strength")
		return true
	end
	if skillname[2] == "endurance" and add_skill(player, skillname) then
		player:SendMessage("added 1 Point to Endurance")
		return true
	end
	if skillname[2] == "intelligence" and add_skill(player, skillname) then
		player:SendMessage("added 1 Point to Intelligence")
		return true
	end
	if skillname[2] == "agility" and add_skill(player, skillname) then
		player:SendMessage("added 1 Point to Agility")
		return true
	end
	if skillname[2] == "luck" and add_skill(player, skillname) then
		player:SendMessage("added 1 Point to Luck")
		return true
	end
	player:SendMessage("You have not enough Available Skill Points")
	return true
end

function MyOnTakeDamage(Receiver, TDI)
	if TDI.Attacker ~= nil and Receiver:IsPlayer() and TDI.Attacker:IsPlayer() then
		local player = tolua.cast(TDI.Attacker, "cPlayer")
		local stats_receiver = get_stats(Receiver)
		local stats_attacker = get_stats(player)
		if stats_receiver[1]["fraction"] == stats_attacker[1]["fraction"] then
			TDI.FinalDamage = 0
			player:SendMessage("this Player is in the same Fraction")
			return true
		end
	end
	if TDI.Attacker ~= nil and TDI.Attacker:IsPlayer() then
		local player = tolua.cast(TDI.Attacker, "cPlayer")
		local stats = get_stats(player)
		TDI.FinalDamage = TDI.FinalDamage / 5 * stats[1]["strength"]; -- lower damage to make better balance
		if math.random(0,100) <= tonumber(stats[1]["luck"]) then
			TDI.FinalDamage = TDI.FinalDamage * 2
			send_battlelog(player, "You did a Critical Hit!")
		end
		if TDI.FinalDamage == 0 then
			TDI.FinalDamage = 1	-- we won't have damage = 0 :)
		end
		send_battlelog(player, "you did " .. TDI.FinalDamage .. " Damage")
	end
	if Receiver:IsPlayer() then
		local player = tolua.cast(Receiver, "cPlayer")
		local stats = get_stats(player)
		if TDI.DamageType ~= 3 then
			-- add dodge with LUCK and AGILITY
			if math.random(0,100) < (tonumber(stats[1]["luck"]) + tonumber(stats[1]["agility"])) then
				TDI.FinalDamage = 0
				send_battlelog(player, "you dodged the Attack")
			else
				TDI.FinalDamage = TDI.FinalDamage * 2 -- add damage for better balance
				send_battlelog(player, "you got " .. TDI.FinalDamage .. " Damage")
			end
		end
		-- Fall Damage somewhat with agility
		if TDI.DamageType == 3 then
			TDI.FinalDamage = TDI.FinalDamage / (stats[1]["agility"] / 5)
			send_battlelog(player, "you got " .. TDI.FinalDamage .. " Fall Damage")
		end
		if tonumber(stats[1]["health"]) > TDI.FinalDamage then
			set_stats(Receiver, "health", stats[1]["health"] - TDI.FinalDamage)
			TDI.FinalDamage = 1
		end
	end
end

function get_exp(player)
	-- Get current exp from DB
	local stats = get_stats(player)
	return stats[1]["exp"]
end

function send_battlelog(player, message)
	-- Get if battlelog is on or off from DB
	local stats = get_stats(player)
	if stats[1]["battlelog"] == "1" then
		player:SendMessage(message)
	end
end

function give_exp(exp, player)
	-- add given exp in database return true if level up otherwise false
	send_battlelog(player, "you earned " .. exp .. " exp")
	local cexp = get_exp(player)
	local level_before = calc_level(cexp)
	-- add exp in database
	local exp_after = cexp + exp
	set_stats(player, "exp", exp_after)
	local level_after = calc_level(cexp)
	if level_before < level_after then
		local stats = get_stats(player)
		stats[1]["skillpoints"] = stats[1]["skillpoints"] + 1
		return true
	end
	return false
end

function calc_exp_to_level(level)
	local exp_needed = 200
	local count = 2
	while count < tonumber(level) do
		exp_needed = exp_needed + (exp_needed / 2)
		count = count + 1
	end
	return exp_needed
end

function calc_level(exp)
	-- create some function to  calc levels
	exp = tonumber(exp)
	local level = 1
	local exp_needed = 200
	while exp > exp_needed do
		exp_needed = exp_needed + (exp_needed / 2)
		level = level + 1
	end
	return level
end

function create_database()
-- Create DB if not exists
local db = cSQLiteHandler("mmo.sqlite",
	cTable("mmo")
	:Field("ID", "INTEGER", "PRIMARY KEY AUTOINCREMENT")
	:Field("name", "TEXT")
	:Field("exp","INTEGER")
	:Field("health", "INTEGER")
	:Field("health_before", "INTEGER")
	:Field("strength","INTEGER")
	:Field("agility","INTEGER")
	:Field("luck","INTEGER")
	:Field("intelligence","INTEGER")
	:Field("magic","INTEGER")
	:Field("magic_max","INTEGER")
	:Field("endurance","INTEGER")
	:Field("skillpoints","INTEGER")
	:Field("battlelog","INTEGER")
	:Field("fraction","TEXT")
	:Field("last_killedx", "INTEGER")
	:Field("last_killedy", "INTEGER")
	:Field("last_killedz", "INTEGER")
)
  return true
end
