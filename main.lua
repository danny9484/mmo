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

	-- Database stuff
	g_Storage = cSQLiteStorage:new()
	create_database()

	-- declare global variables
	spell_counter = 1
	spells = {}
	counter = 0
	stats = {}
	cooldown_player = {}
	cast_time_player = {}

	-- read Config
	local IniFile = cIniFile();
	if (IniFile:ReadFile(PLUGIN:GetLocalFolder() .. "/config.ini")) then
		exp_multiplicator = IniFile:GetValue("Settings", "exp_multiplicator")
		battlelog_default = IniFile:GetValue("Settings", "battlelog_default")
		statusbar_default = IniFile:GetValue("Settings", "statusbar_default")
		exp_multiplicator = tonumber(exp_multiplicator)
		battlelog_default = tonumber(battlelog_default)
		statusbar_default = tonumber(statusbar_default)
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
					spells[spell_counter]["cooldown"] =IniFile_spell:GetValue("Spell", "Cooldown")
					spells[spell_counter]["cast_time"] = IniFile_spell:GetValue("Spell", "Cast_time")
					spells[spell_counter]["magic"] = tonumber(spells[spell_counter]["magic"])
					spells[spell_counter]["cooldown"] =tonumber(spells[spell_counter]["cooldown"])
					spells[spell_counter]["cast_time"] = tonumber(spells[spell_counter]["cast_time"])
	      	LOG(Plugin:GetName() .. ": Spell Initialized: " .. spells[spell_counter]["name"] .. " by " .. spells[spell_counter]["author"])
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
	RegisterPluginInfoCommands()
	--RegisterPluginInfoConsoleCommands() -- not using any currently

	-- initialize online players (for reload)
	local callback_player = function(Player)
		checkifexist(Player)
	end
	cRoot:Get():ForEachPlayer(callback_player)

	LOG("Initialized " .. Plugin:GetName() .. " v." .. Plugin:GetVersion())
	return true
end

function OnDisable()
	LOG(PLUGIN:GetName() .. " is shutting down...")
	local callback_player = function(Player)
		save_player(Player)
	end
	cRoot:Get():ForEachPlayer(callback_player)
end

function MyOnDisconnect(Client, Reason)
	save_player(Client:GetPlayer())
	return true
end

function MyOnPlayerSpawned(Player)
	stats[Player:GetUUID()]["health"] = Player:GetMaxHealth()
	Player:SetInvulnerableTicks(100) -- somebug caused spawn in air as a workaround for no fall damage
end

function mmo_join(command, Player)
	local player_uuid = Player:GetUUID()
	if stats[player_uuid]["fraction"] == nil or stats[player_uuid]["fraction"] == "" then
		if command[3] == "horde" then
			stats[player_uuid]["fraction"] = "horde"
			Player:SendMessage("You joined the Horde")
			return true
		end
		if command[3] == "alliance" then
			stats[player_uuid]["fraction"] = "alliance"
			Player:SendMessage("You joined the Alliance")
			return true
		end
	end
	if stats[player_uuid]["fraction"] ~= "" then
		Player:SendMessage("You already joined a Fraction")
		return true
	end
	Player:SendMessage("usage /mmo join horde/alliance")
	return true
end

function save_player(Player)
	local player_uuid = Player:GetUUID()
	g_Storage:ExecuteCommand("save_player", -- TODO this function is slow use sth own
		{
			player_uuid = stats[player_uuid]["uuid"],
			exp = stats[player_uuid]["exp"],
			health = stats[player_uuid]["health"],
			health_before = stats[player_uuid]["health_before"],
			strength = stats[player_uuid]["strength"],
			agility = stats[player_uuid]["agility"],
			luck = stats[player_uuid]["luck"],
			intelligence = stats[player_uuid]["intelligence"],
			endurance = stats[player_uuid]["endurance"],
			skillpoints = stats[player_uuid]["skillpoints"],
			battlelog = stats[player_uuid]["battlelog"],
			statusbar = stats[player_uuid]["statusbar"],
			magic = stats[player_uuid]["magic"],
			magic_max = stats[player_uuid]["magic_max"],
			fraction = stats[player_uuid]["fraction"],
			level = stats[player_uuid]["level"]
		}
	)
	if stats[player_uuid]["last_killedx"] ~= nil and stats[player_uuid]["last_killedy"] ~= nil and stats[player_uuid]["last_killedz"] ~= nil then
		g_Storage:ExecuteCommand("update_last_killed",
			{
				last_killedx = stats[player_uuid]["last_killedx"],
				last_killedy = stats[player_uuid]["last_killedy"],
				last_killedz = stats[player_uuid]["last_killedz"]
			}
		)
	end
end

function spell(command, Player)
 local counter = 1
	if #command == 1 then
		while counter ~= spell_counter do
			Player:SendMessage("/" .. spells[counter]["name"] .. " | " .. spells[counter]["description_en"] .. " | Magic: " .. spells[counter]["magic"])
			counter = counter + 1
		end
		return true
	end
	if #command >= 2 then
		counter = spell_counter - 1
		while counter ~= 0 do
			if command[2] == spells[counter]["name"] then
					dospell(command, Player, spells[counter]["cooldown"], spells[counter]["cast_time"], counter)
			end
			counter = counter - 1
		end
	end
	return true
end

function dospell(command, Player, cooldown, cast_time, counter)
	local player_uuid = Player:GetUUID()
	if cast_time > 0 and check_magic(Player, spells[counter]["magic"]) then
		send_battlelog(Player, "Charging Spell, please wait")
		cast_time_player[player_uuid]["cast_time"] = cast_time
		cast_time_player[player_uuid]["cast_time_max"] = cast_time
		cast_time_player[player_uuid]["command"] = command
		cast_time_player[player_uuid]["player"] = Player
		cast_time_player[player_uuid]["counter"] = counter
		cast_time_player[player_uuid]["cooldown"] = cooldown
		cast_time_player[player_uuid]["positionx"] = Player:GetPosX()
		cast_time_player[player_uuid]["positiony"] = Player:GetPosY()
		cast_time_player[player_uuid]["positionz"] = Player:GetPosZ()
		return true
	end
	if cooldown_player[player_uuid] == nil then
		cooldown_player[player_uuid] = {}
	end
	if check_magic(Player, spells[counter]["magic"]) then
		if cooldown_player[player_uuid][counter][spells[counter]["cooldown"]] == nil then
			cooldown_player[player_uuid][counter][spells[counter]["cooldown"]] = 0
		end
		if cooldown_player[player_uuid][counter][spells[counter]["cooldown"]] > 0 then
			Player:SendMessage("Spell has to cooldown")
		else
			if rem_magic(Player, spells[counter]["magic"]) then
				assert(loadfile(PLUGIN:GetLocalFolder() .. "/spells/" .. spells[counter]["name"] .. "/" .. spells[counter]["name"] .. ".lua"))(command, Player)
			end
		end
		if cooldown_player[player_uuid][counter][spells[counter]["cooldown"]] == 0 then
			cooldown_player[player_uuid][counter][spells[counter]["cooldown"]] = cooldown
		end
	else
		send_battlelog(Player, "not enough Magic!")
	end
end

function check_magic(Player, amount)
	if stats[Player:GetUUID()]["magic"] >= amount then
		local magic_after = stats[Player:GetUUID()]["magic"] - amount
		return true
	else
		return false
	end
end

function rem_magic(Player, amount)
	local player_uuid = Player:GetUUID()
	if stats[player_uuid]["magic"] >= amount then
		local magic_after = stats[player_uuid]["magic"] - amount
		stats[player_uuid]["magic"] = magic_after
		return true
	else
		send_battlelog(Player, "not enough Magic!")
		return false
	end
end

function add_magic_regeneration(Player, percentage, stats) -- TODO sometimes it loads over max, check that
	local player_uuid = Player:GetUUID()
	if stats[player_uuid]["magic"] < stats[player_uuid]["magic_max"] then
		local magic_after = stats[player_uuid]["magic"] + math.floor(stats[player_uuid]["magic_max"] * percentage / 10) / 10
		stats[player_uuid]["magic"] = magic_after
		end
end

function add_health_regeneration(Player, stats)
	local player_uuid = Player:GetUUID()
	if stats[player_uuid]["health_before"] < Player:GetHealth() and stats[player_uuid]["health"] < Player:GetMaxHealth() then
		stats[player_uuid]["health"] = stats[player_uuid]["health"] + 1
	end
	Player:SetHealth(stats[player_uuid]["health"] / (Player:GetMaxHealth() / 20))
	stats[player_uuid]["health_before"] = Player:GetHealth()
end

function MyOnWorldTick(World, TimeDelta)
	-- add MAGIC regeneration
	local callback = function(Player)
		local player_uuid = Player:GetUUID()
		add_magic_regeneration(Player, 1, stats)
		add_health_regeneration(Player, stats)
		if cast_time_player[player_uuid] == nil then
			cast_time_player[player_uuid] = {}
		end
		if cast_time_player[player_uuid]["cast_time"] == nil then
			cast_time_player[player_uuid]["cast_time"] = 0
		end
		if cast_time_player[player_uuid]["cast_time"] > 0 then
			cast_time_player[player_uuid]["cast_time"] = cast_time_player[player_uuid]["cast_time"] - 1
			if cast_time_player[player_uuid]["positionx"] ~= Player:GetPosX() or cast_time_player[player_uuid]["positiony"] ~= Player:GetPosY() or cast_time_player[player_uuid]["positionz"] ~= Player:GetPosZ() then
				send_battlelog(Player, "Casting aborted!")
				cast_time_player[player_uuid]["cast_time"] = 0
				return true
			end
			if cast_time_player[player_uuid]["cast_time"] == 0 then
				send_battlelog(Player, "Casting!")
				dospell(cast_time_player[player_uuid]["command"], cast_time_player[player_uuid]["player"], cast_time_player[player_uuid]["cooldown"], 0, cast_time_player[player_uuid]["counter"])
			end
		end
		local i = spell_counter - 1
		while i > 0 do
			if cooldown_player[player_uuid] == nil then
				cooldown_player[player_uuid] = {}
			end
			if cooldown_player[player_uuid][i] == nil then
				cooldown_player[player_uuid][i] = {}
				cooldown_player[player_uuid][i][spells[i]["cooldown"]] = 0
			end
			if cooldown_player[player_uuid][i]["cooldown_before"] == 1 then
				send_battlelog(Player, spells[i]["name"] .. ": cooled down")
				cooldown_player[player_uuid][i]["cooldown_before"] = 0
			end
			if cooldown_player[player_uuid][i][spells[i]["cooldown"]] > 0 then
				cooldown_player[player_uuid][i][spells[i]["cooldown"]] = cooldown_player[player_uuid][i][spells[i]["cooldown"]] - 1
				if cooldown_player[player_uuid][i][spells[i]["cooldown"]] == 0 then
				end
				if cooldown_player[player_uuid][i][spells[i]["cooldown"]] == 0 then
					cooldown_player[player_uuid][i]["cooldown_before"] = 1
				end
			end
			i = i - 1
		end
		counter = 75
		if stats[Player:GetUUID()]["statusbar"] == 1 and cast_time_player[player_uuid]["cast_time"] ~= 0 then
			local bar_range = 40
			local load = bar_range / (cast_time_player[player_uuid]["cast_time_max"] / cast_time_player[player_uuid]["cast_time"])
			local load_message = ""
			local load_a = bar_range - load
			while load_a > 0 do	-- TODO check this function, bar length increases with load but it should always be the same
				load_message = "#" .. load_message
				load_a = load_a - 1
			end
			while load > 0 do
				load_message = load_message .. "-"
				load = load - 1
			end
			Player:SendAboveActionBarMessage("[" .. load_message .. "]")
		end
		if stats[player_uuid]["statusbar"] == 1 and cast_time_player[player_uuid]["cast_time"] == 0 then
			Player:SendAboveActionBarMessage("Health: " .. stats[player_uuid]["health"] .. " / " .. Player:GetMaxHealth() .. " | Magic: " .. stats[player_uuid]["magic"] .. " / " .. stats[player_uuid]["magic_max"] .. " | lvl: " .. stats[player_uuid]["level"] .. " | exp: " .. stats[player_uuid]["exp"] .. " / " .. math.floor(calc_exp_to_level(stats[player_uuid]["level"] + 1)))
		end
	end
	counter = counter + 1
	if counter > 50 then	-- TODO think of sth better than that, this will break at some playercount
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
	if stats[Player:GetUUID()]["battlelog"] == 0 then
		stats[Player:GetUUID()]["battlelog"] = 1
		Player:SendMessage("turned Battlelog on")
		return true
	end
	if stats[Player:GetUUID()]["battlelog"] == 1 then
		stats[Player:GetUUID()]["battlelog"] = 0
		Player:SendMessage("turned Battlelog off")
		return true
	end
end

function statusbar(command, player)
	if stats[Player:GetUUID()]["statusbar"] == 0 then
		stats[Player:GetUUID()]["statusbar"] = 1
		Player:SendMessage("turned Statusbar on")
		return true
	end
	if stats[Player:GetUUID()]["statusbar"] == 1 then
		stats[Player:GetUUID()]["statusbar"] = 0
		Player:SendMessage("turned Statusbar off")
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
	Player:SetMaxHealth(20 * (stats[Player:GetUUID()]["endurance"]))
end

function show_stats (Player)
	 Player:SendMessage("exp: " .. stats[Player:GetUUID()]["exp"])
	 Player:SendMessage("Strength: " .. stats[Player:GetUUID()]["strength"])
	 Player:SendMessage("Agility: " .. stats[Player:GetUUID()]["agility"])
	 Player:SendMessage("Luck: " .. stats[Player:GetUUID()]["luck"])
	 Player:SendMessage("Intelligence: " .. stats[Player:GetUUID()]["intelligence"])
	 Player:SendMessage("Endurance: " .. stats[Player:GetUUID()]["endurance"])
	 Player:SendMessage("Level: " .. stats[Player:GetUUID()]["level"])
	 Player:SendMessage("Magic: " .. stats[Player:GetUUID()]["magic"] .. " of " .. stats[Player:GetUUID()]["magic_max"])
	 if stats[Player:GetUUID()]["fraction"] == nil  or stats[Player:GetUUID()]["fraction"] == "" then
	 	Player:SendMessage("Use /mmo join horde/alliance to join a fraction")
	 else
		Player:SendMessage("Fraction: " .. stats[Player:GetUUID()]["fraction"])
	 end
	 if calc_available_skill_points(Player) ~= 0 then
		 Player:SendMessage("Available Skillpoints: " .. calc_available_skill_points(Player))
	 end
end

function get_stats_initialize(Player)
	g_Storage:ExecuteCommand("initialize_player",
	{
		player_uuid = Player:GetUUID();
	},
	function(stats_sql)
		stats[Player:GetUUID()] = stats_sql
	end
	)
	return stats
end

function checkifexist(Player)
	-- return true if player exists in db otherwise false
	if stats == nil or stats[Player:GetUUID()] == nil then
		stats = get_stats_initialize(Player)
	end
	if stats[Player:GetUUID()] == nil then
		return false
	end
	if stats[Player:GetUUID()]["uuid"] == Player:GetUUID() then
		return true
	end
	return false
end

function register_new_player(Player)
	-- register new player in database
	player_uuid = Player:GetUUID()
	g_Storage:ExecuteCommand("register_new_player",
		{
			player_uuid = player_uuid,
		  exp = 0,
		  health = 20,
		  health_before = 20,
		  strength = 1,
		  agility = 1,
		  luck = 1,
		  intelligence = 1,
		  magic = 100,
		  magic_max = 100,
			endurance = 1,
		  skillpoints = 0,
		  battlelog = battlelog_default,
		  statusbar = statusbar_default,
			level = 1
		}
	)
	stats[player_uuid] = {}
	stats[player_uuid]["uuid"] = player_uuid
	stats[player_uuid]["exp"] = 0
	stats[player_uuid]["health"] = 20
	stats[player_uuid]["health_before"] = 20
	stats[player_uuid]["strength"] = 1
	stats[player_uuid]["agility"] = 1
	stats[player_uuid]["luck"] = 1
	stats[player_uuid]["intelligence"] = 1
	stats[player_uuid]["endurance"] = 1
	stats[player_uuid]["skillpoints"] = 0
	stats[player_uuid]["battlelog"] = battlelog_default
	stats[player_uuid]["statusbar"] = statusbar_default
	stats[player_uuid]["magic"] = 100
	stats[player_uuid]["magic_max"] = 100
	stats[player_uuid]["level"] = 1
end

function MyOnKilled(Victim, TDI)
	if Victim:IsPlayer() then
		local victim_name = Victim:GetName()
		stats[victim_name]["last_killedx"] = Victim:GetPosX()
		stats[victim_name]["last_killedy"] = Victim:GetPosY()
		stats[victim_name]["last_killedz"] = Victim:GetPosZ()
	end
	local exp = 0
	if TDI.Attacker ~= nil and TDI.Attacker:IsPlayer() then
		local Player = tolua.cast(TDI.Attacker, "cPlayer")
		if TDI.Attacker ~= nil and Victim:IsPlayer() and TDI.Attacker:IsPlayer() then
			exp = 25 * calc_level(stats[Player:GetUUID()]["exp"])
			send_battlelog(Player, "You killed a Player")
		end
		if (TDI.Attacker ~= nil and TDI.Attacker:IsPlayer() and Victim:IsMob()) then
			-- TODO extend monsterlist
			if Victim:GetMobFamily() == 0 then
				send_battlelog(Player, "You killed a Monster")
				exp = 5
			end
			if Victim:GetMobFamily() == 1 then
				send_battlelog(Player, "You killed a Animal")
				exp = 1
			end
			if Victim:GetMobFamily() == 3 then
				send_battlelog(Player, "You killed a Water Animal")
				exp = 1
			end
			if Victim:GetMobFamily() == 2 then
				send_battlelog(Player, "You killed Something Mysterious")
				exp = 5
			end
		end
		if TDI.Attacker ~= nil and TDI.Attacker:IsPlayer() and give_exp(exp, Player) then
			stats[Player:GetUUID()]["level"] = calc_level(stats[Player:GetUUID()]["exp"])
			send_battlelog(Player, "Level UP! you are now Level " .. stats[Player:GetUUID()]["level"])
		end
	end
end

function calc_available_skill_points(Player)
	-- calculate not given skill points
	local available_points = stats[Player:GetUUID()]["level"] + 4 - (stats[Player:GetUUID()]["strength"] + stats[Player:GetUUID()]["endurance"] + stats[Player:GetUUID()]["intelligence"] + stats[Player:GetUUID()]["agility"] + stats[Player:GetUUID()]["luck"])
	return available_points
end

function add_skill(Player, skillname)
	-- add skill point to the given skill if skillpoints available
	if calc_available_skill_points(Player) > 0 then
		stats[Player:GetUUID()][skillname[2]] = stats[Player:GetUUID()][skillname[2]] + 1
		if skillname[2] == "endurance" then
			Player:SetMaxHealth(Player:GetMaxHealth() + 20)
		end
		if skillname[2] == "intelligence" then
			stats[Player:GetUUID()]["magic_max"] = stats[Player:GetUUID()]["magic_max"] + 100
		end
		return true
	end
	return false
end

function skills(skillname, Player)
	if skillname[2] == nil then
		show_stats(Player)
		return true
	end
	if skillname[2] == "strength" and add_skill(Player, skillname) then
		Player:SendMessage("added 1 Point to Strength")
		return true
	end
	if skillname[2] == "endurance" and add_skill(Player, skillname) then
		Player:SendMessage("added 1 Point to Endurance")
		return true
	end
	if skillname[2] == "intelligence" and add_skill(Player, skillname) then
		Player:SendMessage("added 1 Point to Intelligence")
		return true
	end
	if skillname[2] == "agility" and add_skill(Player, skillname) then
		Player:SendMessage("added 1 Point to Agility")
		return true
	end
	if skillname[2] == "luck" and add_skill(Player, skillname) then
		Player:SendMessage("added 1 Point to Luck")
		return true
	end
	Player:SendMessage("You have not enough Available Skill Points")
	Player:SendMessage("or you wrote the spell wrong") -- TODO handle mistakes in writing
	return true
end

function MyOnTakeDamage(Receiver, TDI)
	if TDI.Attacker ~= nil and Receiver:IsPlayer() and TDI.Attacker:IsPlayer() then
		local Player = tolua.cast(TDI.Attacker, "cPlayer")
		local attacker_name = Player:GetUUID()
		if stats[attacker_name]["fraction"] != "" and stats[receiver_name]["fraction"] != "" and stats[receiver_name]["fraction"] == stats[attacker_name]["fraction"] then
			TDI.FinalDamage = 0
			Player:SendMessage("this Player is in the same Fraction")
			return true
		end
	end
	if TDI.Attacker ~= nil and TDI.Attacker:IsPlayer() then
		local Player = tolua.cast(TDI.Attacker, "cPlayer")
		local attacker_name = Player:GetUUID()
		TDI.FinalDamage = TDI.FinalDamage / 5 * stats[attacker_name]["strength"]; -- lower damage to make better balance
		if math.random(0,100) <= stats[attacker_name]["luck"] then
			TDI.FinalDamage = TDI.FinalDamage * 2
			send_battlelog(Player, "You did a Critical Hit!")
		end
		if TDI.FinalDamage == 0 then
			TDI.FinalDamage = 1	-- we won't have damage = 0 :)
		end
		send_battlelog(Player, "you did " .. TDI.FinalDamage .. " Damage")
	end
	if Receiver:IsPlayer() then
		local Player = tolua.cast(Receiver, "cPlayer")
		local receiver_name = Player:GetUUID()
		if TDI.DamageType ~= 3 then
			-- add dodge with LUCK and AGILITY
			if math.random(0,100) < (stats[receiver_name]["luck"] + stats[receiver_name]["agility"]) then
				TDI.FinalDamage = 0
				send_battlelog(Player, "you dodged the Attack")
			else
				TDI.FinalDamage = TDI.FinalDamage * 2 -- add damage for better balance
				send_battlelog(Player, "you got " .. TDI.FinalDamage .. " Damage")
			end
		end
		-- Fall Damage somewhat with agility
		if TDI.DamageType == 3 then
			TDI.FinalDamage = TDI.FinalDamage / (stats[receiver_name]["agility"] / 5)
			send_battlelog(Player, "you got " .. TDI.FinalDamage .. " Fall Damage")
		end
		if stats[receiver_name]["health"] > TDI.FinalDamage then
			stats[receiver_name]["health"] = stats[receiver_name]["health"] - TDI.FinalDamage
			TDI.FinalDamage = 1
		end
		if stats[receiver_name]["health"] == 0 then
			TDI.FinalDamage = 25 -- lets be sure to kill him
		end
	end
end

function get_exp(Player)
	return stats[Player:GetUUID()]["exp"]
end

function send_battlelog(Player, message)
	-- Get if battlelog is on or off from DB
	if stats[Player:GetUUID()]["battlelog"] == 1 then
		Player:SendMessage(message)
	end
end

function give_exp(exp, Player)
	-- add given exp in database return true if level up otherwise false
	exp = exp * exp_multiplicator
	send_battlelog(Player, "you earned " .. exp .. " exp")
	local cexp = get_exp(Player)
	local level_before = calc_level(cexp)
	-- add exp in database
	local exp_after = cexp + exp
	stats[Player:GetUUID()]["exp"] = exp_after
	local level_after = calc_level(exp_after)
	if level_before < level_after then
		stats[Player:GetUUID()]["skillpoints"] = stats[Player:GetUUID()]["skillpoints"] + 1
		return true
	end
	return false
end

function calc_exp_to_level(level)
	local exp_needed = 200
	local count = 2
	while count < level do
		exp_needed = exp_needed + (exp_needed / 2)
		count = count + 1
	end
	return exp_needed
end

function calc_level(exp)
	-- create some function to  calc levels
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
	cSQLiteStorage:new()
  return true
end
