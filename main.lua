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
					spells[spell_counter]["cooldown"] = IniFile_spell:GetValue("Spell", "Cooldown")
					spells[spell_counter]["cast_time"] = IniFile_spell:GetValue("Spell", "Cast_time")
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
	local callback_player = function(player)
		checkifexist(player)
	end
	cRoot:Get():ForEachPlayer(callback_player)

	LOG("Initialized " .. Plugin:GetName() .. " v." .. Plugin:GetVersion())
	return true
end

function OnDisable()
	LOG(PLUGIN:GetName() .. " is shutting down...")
	local callback_player = function(player)
		save_player(player)
	end
	cRoot:Get():ForEachPlayer(callback_player)
end

function MyOnDisconnect(Client, Reason)
	save_player(Client:GetPlayer())
	return true
end

function MyOnPlayerSpawned(Player)
	stats[Player:GetName()]["health"] = Player:GetMaxHealth()
	Player:SetInvulnerableTicks(100) -- somebug caused spawn in air as a workaround for no fall damage
end

function mmo_join(command, player)
	local player_name = player:GetName()
	if stats[player_name]["fraction"] == nil or stats[player_name]["fraction"] == "" then
		if command[3] == "horde" then
			stats[player_name]["fraction"] = "horde"
			player:SendMessage("You joined the Horde")
			return true
		end
		if command[3] == "alliance" then
			stats[player_name]["fraction"] = "alliance"
			player:SendMessage("You joined the Alliance")
			return true
		end
	end
	if stats[player_name]["fraction"] ~= "" then
		player:SendMessage("You already joined a Fraction")
		return true
	end
	player:SendMessage("usage /mmo join horde/alliance")
	return true
end

function save_player(player)
	local player_name = player:GetName()
	g_Storage:ExecuteCommand("save_player",
		{
			player_name = stats[player_name]["name"],
			exp = stats[player_name]["exp"],
			health = stats[player_name]["health"],
			health_before = stats[player_name]["health_before"],
			strength = stats[player_name]["strength"],
			agility = stats[player_name]["agility"],
			luck = stats[player_name]["luck"],
			intelligence = stats[player_name]["intelligence"],
			endurance = stats[player_name]["endurance"],
			skillpoints = stats[player_name]["skillpoints"],
			battlelog = stats[player_name]["battlelog"],
			statusbar = stats[player_name]["statusbar"],
			magic = stats[player_name]["magic"],
			magic_max = stats[player_name]["magic_max"],
			fraction = stats[player_name]["fraction"],
			level = stats[player_name]["level"]
		}
	)
	if stats[player_name]["last_killedx"] ~= nil and stats[player_name]["last_killedy"] ~= nil and stats[player_name]["last_killedz"] ~= nil then
		g_Storage:ExecuteCommand("update_last_killed",
			{
				last_killedx = stats[player_name]["last_killedx"],
				last_killedy = stats[player_name]["last_killedy"],
				last_killedz = stats[player_name]["last_killedz"]
			}
		)
	end
end

function spell(command, player)
 local counter = 1
	if #command == 1 then
		while counter ~= spell_counter do
			player:SendMessage("/" .. spells[counter]["name"] .. " | " .. spells[counter]["description_en"] .. " | Magic: " .. spells[counter]["magic"])
			counter = counter + 1
		end
		return true
	end
	if #command >= 2 then
		counter = spell_counter - 1
		while counter ~= 0 do
			if command[2] == spells[counter]["name"] then
					dospell(command, player, spells[counter]["cooldown"], spells[counter]["cast_time"], counter)
			end
			counter = counter - 1
		end
	end
	return true
end

function dospell(command, player, cooldown, cast_time, counter)
	local player_name = player:GetName()
	if cast_time > 0 and check_magic(player, spells[counter]["magic"]) then
		send_battlelog(player, "Charging Spell, please wait")
		cast_time_player[player_name]["cast_time"] = cast_time
		cast_time_player[player_name]["cast_time_max"] = cast_time
		cast_time_player[player_name]["command"] = command
		cast_time_player[player_name]["player"] = player
		cast_time_player[player_name]["counter"] = counter
		cast_time_player[player_name]["cooldown"] = cooldown
		cast_time_player[player_name]["positionx"] = player:GetPosX()
		cast_time_player[player_name]["positiony"] = player:GetPosY()
		cast_time_player[player_name]["positionz"] = player:GetPosZ()
		return true
	end
	if cooldown_player[player_name] == nil then
		cooldown_player[player_name] = {}
	end
	if check_magic(player, spells[counter]["magic"]) then
		if cooldown_player[player_name][counter][spells[counter]["cooldown"]] == nil then
			cooldown_player[player_name][counter][spells[counter]["cooldown"]] = 0
		end
		if cooldown_player[player_name][counter][spells[counter]["cooldown"]] > 0 then
			player:SendMessage("Spell has to cooldown")
		else
			if rem_magic(player, spells[counter]["magic"]) then
				assert(loadfile(PLUGIN:GetLocalFolder() .. "/spells/" .. spells[counter]["name"] .. "/" .. spells[counter]["name"] .. ".lua"))(command, player)
			end
		end
		if cooldown_player[player_name][counter][spells[counter]["cooldown"]] == 0 then
			cooldown_player[player_name][counter][spells[counter]["cooldown"]] = cooldown
		end
	else
		send_battlelog(player, "not enough Magic!")
	end
end

function check_magic(player, amount)
	if stats[player:GetName()]["magic"] >= amount then
		local magic_after = stats[player:GetName()]["magic"] - amount
		return true
	else
		return false
	end
end

function rem_magic(player, amount)
	local player_name = player:GetName()
	if stats[player_name]["magic"] >= amount then
		local magic_after = stats[player_name]["magic"] - amount
		stats[player_name]["magic"] = magic_after
		return true
	else
		send_battlelog(player, "not enough Magic!")
		return false
	end
end

function add_magic_regeneration(player, percentage, stats)
	local player_name = player:GetName()
	if stats[player_name]["magic"] < stats[player_name]["magic_max"] then
		local magic_after = stats[player_name]["magic"] + math.floor(stats[player_name]["magic_max"] * percentage / 10) / 10
		stats[player_name]["magic"] = magic_after
		end
end

function add_health_regeneration(player, stats)
	local player_name = player:GetName()
	if stats[player_name]["health_before"] < player:GetHealth() and stats[player_name]["health"] < player:GetMaxHealth() then
		stats[player_name]["health"] = stats[player_name]["health"] + 1
	end
	player:SetHealth(stats[player_name]["health"] / (player:GetMaxHealth() / 20))
	stats[player_name]["health_before"] = player:GetHealth()
end

function MyOnWorldTick(World, TimeDelta)
	-- add MAGIC regeneration
	local callback = function(player)
		local player_name = player:GetName()
		add_magic_regeneration(player, 1, stats)
		add_health_regeneration(player, stats)
		if cast_time_player[player_name] == nil then
			cast_time_player[player_name] = {}
		end
		if cast_time_player[player_name]["cast_time"] == nil then
			cast_time_player[player_name]["cast_time"] = 0
		end
		if cast_time_player[player_name]["cast_time"] > 0 then
			cast_time_player[player_name]["cast_time"] = cast_time_player[player_name]["cast_time"] - 1
			if cast_time_player[player_name]["positionx"] ~= player:GetPosX() or cast_time_player[player_name]["positiony"] ~= player:GetPosY() or cast_time_player[player_name]["positionz"] ~= player:GetPosZ() then
				send_battlelog(player, "Casting aborted!")
				cast_time_player[player_name]["cast_time"] = 0
				return true
			end
			if cast_time_player[player_name]["cast_time"] == 0 then
				send_battlelog(player, "Casting!")
				dospell(cast_time_player[player_name]["command"], cast_time_player[player_name]["player"], cast_time_player[player_name]["cooldown"], 0, cast_time_player[player_name]["counter"])
			end
		end
		local i = spell_counter - 1
		while i > 0 do
			if cooldown_player[player_name] == nil then
				cooldown_player[player_name] = {}
			end
			if cooldown_player[player_name][i] == nil then
				cooldown_player[player_name][i] = {}
				cooldown_player[player_name][i][spells[i]["cooldown"]] = 0
			end
			if cooldown_player[player_name][i]["cooldown_before"] == 1 then
				send_battlelog(player, spells[i]["name"] .. ": cooled down")
				cooldown_player[player_name][i]["cooldown_before"] = 0
			end
			if cooldown_player[player_name][i][spells[i]["cooldown"]] > 0 then
				cooldown_player[player_name][i][spells[i]["cooldown"]] = cooldown_player[player_name][i][spells[i]["cooldown"]] - 1
				if cooldown_player[player_name][i][spells[i]["cooldown"]] == 0 then
				end
				if cooldown_player[player_name][i][spells[i]["cooldown"]] == 0 then
					cooldown_player[player_name][i]["cooldown_before"] = 1
				end
			end
			i = i - 1
		end
		counter = 75
		if stats[player:GetName()]["statusbar"] == 1 and cast_time_player[player_name]["cast_time"] ~= 0 then
			local bar_range = 40
			local load = bar_range / (cast_time_player[player_name]["cast_time_max"] / cast_time_player[player_name]["cast_time"])
			local load_message = ""
			local load_a = bar_range - load
			while load_a > 0 do
				load_message = "#" .. load_message
				load_a = load_a - 1
			end
			while load > 0 do
				load_message = load_message .. "-"
				load = load - 1
			end
			player:SendAboveActionBarMessage("[" .. load_message .. "]")
		end
		if stats[player_name]["statusbar"] == 1 and cast_time_player[player_name]["cast_time"] == 0 then
			player:SendAboveActionBarMessage("Health: " .. stats[player_name]["health"] .. " / " .. player:GetMaxHealth() .. " | Magic: " .. stats[player_name]["magic"] .. " / " .. stats[player_name]["magic_max"] .. " | lvl: " .. stats[player_name]["level"] .. " | exp: " .. stats[player_name]["exp"] .. " / " .. calc_exp_to_level(stats[player_name]["level"] + 1))
		end
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
	if stats[player:GetName()]["battlelog"] == 0 then
		stats[player:GetName()]["battlelog"] = 1
		player:SendMessage("turned Battlelog on")
		return true
	end
	if stats[player:GetName()]["battlelog"] == 1 then
		stats[player:GetName()]["battlelog"] = 0
		player:SendMessage("turned Battlelog off")
		return true
	end
end

function statusbar(command, player)
	if stats[player:GetName()]["statusbar"] == 0 then
		stats[player:GetName()]["statusbar"] = 1
		player:SendMessage("turned Statusbar on")
		return true
	end
	if stats[player:GetName()]["statusbar"] == 1 then
		stats[player:GetName()]["statusbar"] = 0
		player:SendMessage("turned Statusbar off")
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
	Player:SetMaxHealth(20 * (stats[Player:GetName()]["endurance"]))
end

function show_stats (Player)
	 Player:SendMessage("exp: " .. stats[Player:GetName()]["exp"])
	 Player:SendMessage("Strength: " .. stats[Player:GetName()]["strength"])
	 Player:SendMessage("Agility: " .. stats[Player:GetName()]["agility"])
	 Player:SendMessage("Luck: " .. stats[Player:GetName()]["luck"])
	 Player:SendMessage("Intelligence: " .. stats[Player:GetName()]["intelligence"])
	 Player:SendMessage("Endurance: " .. stats[Player:GetName()]["endurance"])
	 Player:SendMessage("Level: " .. stats[Player:GetName()]["level"])
	 Player:SendMessage("Magic: " .. stats[Player:GetName()]["magic"] .. " of " .. stats[Player:GetName()]["magic_max"])
	 if stats[Player:GetName()]["fraction"] == nil  or stats[Player:GetName()]["fraction"] == "" then
	 	Player:SendMessage("Use /mmo join horde/alliance to join a fraction")
	 else
		Player:SendMessage("Fraction: " .. stats[Player:GetName()]["fraction"])
	 end
	 if calc_available_skill_points(Player) ~= 0 then
		 Player:SendMessage("Available Skillpoints: " .. calc_available_skill_points(Player))
	 end
end

function get_stats_initialize(Player)
	g_Storage:ExecuteCommand("initialize_player",
	{
		player_name = Player:GetName();
	},
	function(stats_sql)
		stats[Player:GetName()] = stats_sql
	end
	)
	return stats
end

function checkifexist(Player)
	-- return true if player exists in db otherwise false
	if stats == nil or stats[Player:GetName()] == nil then
		stats = get_stats_initialize(Player)
	end
	if stats[Player:GetName()] == nil then
		return false
	end
	if stats[Player:GetName()]["name"] == Player:GetName() then
		return true
	end
	return false
end

function register_new_player(Player)
	-- register new player in database
	player_name = Player:GetName()
	g_Storage:ExecuteCommand("register_new_player",
		{
			player_name = player_name,
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
	stats[player_name] = {}
	stats[player_name]["name"] = player_name
	stats[player_name]["exp"] = 0
	stats[player_name]["health"] = 20
	stats[player_name]["health_before"] = 20
	stats[player_name]["strength"] = 1
	stats[player_name]["agility"] = 1
	stats[player_name]["luck"] = 1
	stats[player_name]["intelligence"] = 1
	stats[player_name]["endurance"] = 1
	stats[player_name]["skillpoints"] = 0
	stats[player_name]["battlelog"] = battlelog_default
	stats[player_name]["statusbar"] = statusbar_default
	stats[player_name]["magic"] = 100
	stats[player_name]["magic_max"] = 100
	stats[player_name]["level"] = 1
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
		local player = tolua.cast(TDI.Attacker, "cPlayer")
		if TDI.Attacker ~= nil and Victim:IsPlayer() and TDI.Attacker:IsPlayer() then
			exp = 25 * calc_level(stats[player:GetName()]["exp"])
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
			stats[player:GetName()]["level"] = calc_level(stats[player:GetName()]["exp"])
			send_battlelog(player, "Level UP! you are now Level " .. stats[player:GetName()]["level"])
		end
	end
end

function calc_available_skill_points(player)
	-- calculate not given skill points
	local available_points = stats[player:GetName()]["level"] + 4 - (stats[player:GetName()]["strength"] + stats[player:GetName()]["endurance"] + stats[player:GetName()]["intelligence"] + stats[player:GetName()]["agility"] + stats[player:GetName()]["luck"])
	return available_points
end

function add_skill(player, skillname)
	-- add skill point to the given skill if skillpoints available
	if calc_available_skill_points(player) > 0 then
		stats[player:GetName()][skillname[2]] = stats[player:GetName()][skillname[2]] + 1
		if skillname[2] == "endurance" then
			player:SetMaxHealth(player:GetMaxHealth() + 20)
		end
		if skillname[2] == "intelligence" then
			stats[player:GetName()]["magic_max"] = stats[player:GetName()]["magic_max"] + 100
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
		local attacker_name = player:GetName()
		if stats[receiver_name]["fraction"] == stats[attacker_name]["fraction"] then
			TDI.FinalDamage = 0
			player:SendMessage("this Player is in the same Fraction")
			return true
		end
	end
	if TDI.Attacker ~= nil and TDI.Attacker:IsPlayer() then
		local player = tolua.cast(TDI.Attacker, "cPlayer")
		local attacker_name = player:GetName()
		TDI.FinalDamage = TDI.FinalDamage / 5 * stats[attacker_name]["strength"]; -- lower damage to make better balance
		if math.random(0,100) <= stats[attacker_name]["luck"] then
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
		local receiver_name = player:GetName()
		if TDI.DamageType ~= 3 then
			-- add dodge with LUCK and AGILITY
			if math.random(0,100) < (stats[receiver_name]["luck"] + stats[receiver_name]["agility"]) then
				TDI.FinalDamage = 0
				send_battlelog(player, "you dodged the Attack")
			else
				TDI.FinalDamage = TDI.FinalDamage * 2 -- add damage for better balance
				send_battlelog(player, "you got " .. TDI.FinalDamage .. " Damage")
			end
		end
		-- Fall Damage somewhat with agility
		if TDI.DamageType == 3 then
			TDI.FinalDamage = TDI.FinalDamage / (stats[receiver_name]["agility"] / 5)
			send_battlelog(player, "you got " .. TDI.FinalDamage .. " Fall Damage")
		end
		if stats[receiver_name]["health"] > TDI.FinalDamage then
			stats[receiver_name]["health"] = stats[receiver_name]["health"] - TDI.FinalDamage
			TDI.FinalDamage = 1
		end
		if stats[receiver_name] == 0 then
			TDI.FinalDamage = 20 -- lets be sure to kill him
		end
	end
end

function get_exp(player)
	return stats[player:GetName()]["exp"]
end

function send_battlelog(player, message)
	-- Get if battlelog is on or off from DB
	if stats[player:GetName()]["battlelog"] == 1 then
		player:SendMessage(message)
	end
end

function give_exp(exp, player)
	-- add given exp in database return true if level up otherwise false
	exp = exp * exp_multiplicator
	send_battlelog(player, "you earned " .. exp .. " exp")
	local cexp = get_exp(player)
	local level_before = calc_level(cexp)
	-- add exp in database
	local exp_after = cexp + exp
	stats[player:GetName()]["exp"] = exp_after
	local level_after = calc_level(exp_after)
	if level_before < level_after then
		stats[player:GetName()]["skillpoints"] = stats[player:GetName()]["skillpoints"] + 1
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
