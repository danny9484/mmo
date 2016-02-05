-- mmo by danny9484
PLUGIN = nil

function Initialize(Plugin)
	Plugin:SetName("mmo")
	Plugin:SetVersion(1)

	-- Hooks
	cPluginManager:AddHook(cPluginManager.HOOK_KILLED, MyOnKilled);
	cPluginManager:AddHook(cPluginManager.HOOK_TAKE_DAMAGE, MyOnTakeDamage);
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
	counter = 0
	stats = {}

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

function mmo_join(command, player)
	local stats = get_stats(player)
	if stats[1]["fraction"] ~= nil then
		player:SendMessage("You already joined a Fraction")
		return true
	end
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
	player:SendMessage("usage /mmo join horde/alliance")
	return true
end

function save_player(player)
	local stats = get_stats(player)
	local updateList = cUpdateList()
	:Update("name", stats[1]["name"])
	:Update("exp", stats[1]["exp"])
	:Update("strength", stats[1]["strength"])
	:Update("agility", stats[1]["agility"])
	:Update("luck", stats[1]["luck"])
	:Update("intelligence", stats[1]["intelligence"])
	:Update("magic", stats[1]["magic"])
	:Update("magic_max", stats[1]["magic_max"])
	:Update("endurance", stats[1]["endurance"])
	:Update("skillpoints", calc_level(stats[1]["exp"]))
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
	--TODO add more spells like invisible, shield, fireball, summon golem?, summon meat, freeze, teleportation(fast but near(1 magic per block), 20s wait but wherever you want), summon taimed wolf
	if #command == 1 then
		player:SendMessage("/spell heal <player> | 10M | heal a player")
		player:SendMessage("/spell revive <player> | 50M | teleport a died player back")
		return true
	end
	if #command == 2 then
		if command[2] == "heal" and rem_magic(player, 10) then
			player:Heal(5)
			send_battlelog(player, "you have been healed")
		end
		return true
	end
	if #command == 3 then
		if command[2] == "heal" then -- start heal
			local heal_player = function(player)
				player:Heal(5)
				send_battlelog(player, "you have been healed")
			end
			if rem_magic(player, 10) then
				if cRoot:Get():FindAndDoWithPlayer(command[3], heal_player) then
					send_battlelog(player, "you healed " .. command[3])
				else
					send_battlelog(player, "can't heal " .. command[3] .. ", Player not found.")
				end
			end
			return true
		end	-- end Heal
		if command[2] == "revive" then -- start revive TODO ask for revive and add casting time
			local revive_player = function(player)
				local stats = get_stats(player)
				player:SetPosX(stats[1]["last_killedx"])
				player:SetPosY(stats[1]["last_killedy"])
				player:SetPosZ(stats[1]["last_killedz"])
				send_battlelog(player, "you have been revived")
			end
			if rem_magic(player, 50) then
				if cRoot:Get():FindAndDoWithPlayer(command[3], revive_player) then
					send_battlelog(player, "you revived " .. command[3])
				else
					send_battlelog(player, "can't revive " .. command[3] .. ", Player not found.")
				end
			end
		end	-- end revive
	end
	return true
end

function rem_magic(player, amount)
	local stats = get_stats(player)

	if (tonumber(stats[1]["magic"]) >= amount) then
		local magic_after = tonumber(stats[1]["magic"]) - amount
		-- LOG(magic_after)
		set_stats(player, "magic", magic_after)
		send_battlelog(player, "Magic: " .. stats[1]["magic"] .. " of " .. stats[1]["magic_max"])
		return true
	else
		send_battlelog(player, "not enough Magic!")
		return false
	end
end

function add_magic_regeneration(player, percentage)
	local stats = get_stats(player)
	if tonumber(stats[1]["magic"]) < tonumber(stats[1]["magic_max"]) then-- - (tonumber(stats[1]["magic_max"]) * percentage / 100) then -- this Workaround doesn't really make sense
		local magic_after = stats[1]["magic"] + math.floor(stats[1]["magic_max"] * percentage / 10) / 10
		set_stats(player, "magic", magic_after)
		send_battlelog(player, "Magic: " .. stats[1]["magic"] .. " of " .. stats[1]["magic_max"])
		end
end

function MyOnWorldTick(World, TimeDelta)
	-- add MAGIC regeneration
	local callback = function(player)
		add_magic_regeneration(player, 1)
		counter = 75
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
		local updateList = cUpdateList()
		:Update("battlelog", 1)
		local whereList = cWhereList()
		:Where("name", player:GetName())
		local res = db:Update("mmo", updateList, whereList)
		player:SendMessage("turned Battlelog on")
		return true
	end
	if stats[1]["battlelog"] == "1" then
		local updateList = cUpdateList()
		:Update("battlelog", 0)
		local whereList = cWhereList()
		:Where("name", player:GetName())
		local res = db:Update("mmo", updateList, whereList)
		player:SendMessage("turned Battlelog off")
		return true
	end
end

function MyOnPlayerSpawned(Player)
	if checkifexist(Player) then
		Player:SendMessage("Welcome back")
	else
		Player:SendMessage("Welcome new Player")
		register_new_player(Player)
	end
	show_stats(Player)
	stats = get_stats(Player)
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
	 if stats[1]["fraction"] == nil then
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
	if stats[player:GetName()] == nil then
		stats[player:GetName()] = get_stats_initialize(player)
	end
	res = stats[player:GetName()]
	return res
end

function checkifexist(Player)
	-- return true if player exists in db otherwise false
	local player_name = Player:GetName()
	local whereList = cWhereList()
	:Where("name", player_name)
	local res = db:Select("mmo", "name", whereList)
	if res[1] == nil then
		return false
	end
	if res[1]["name"] == player_name then
		return true
	end
	return false
end

function register_new_player(Player)
	-- register new player in database
	local insertList = cInsertList()
	:Insert("name", Player:GetName())
	:Insert("exp", 0)
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
end

function MyOnKilled(Victim, TDI)
	if Victim:IsPlayer() then
		local updateList = cUpdateList()
		:Update("last_killedx", Victim:GetPosX())
		:Update("last_killedy", Victim:GetPosY())
		:Update("last_killedz", Victim:GetPosZ())
		local whereList = cWhereList()
		:Where("name", Victim:GetName())
		local res = db:Update("mmo", updateList, whereList)
	end
	local exp = 0
	if TDI.Attacker ~= nil and Victim:IsPlayer() and TDI.Attacker:IsPlayer() then
		local player = tolua.cast(TDI.Attacker, "cPlayer")
		local stats = get_stats(Victim)
		exp = 25 * calc_level(stats[1]["exp"])
		send_battlelog(player, "You killed a Player")
	end
	if (TDI.Attacker ~= nil and TDI.Attacker:IsPlayer() and Victim:IsMob()) then
		local player = tolua.cast(TDI.Attacker, "cPlayer")
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
	if TDI.Attacker:IsPlayer() and give_exp(exp, player) then
		local lvl = calc_level(get_exp(player))
		send_battlelog(player, "Level UP! you are now Level " .. lvl)
	end
end

function calc_available_skill_points(player)
	-- calculate not given skill points
	local stats = get_stats(player)
	local available_points = tonumber(stats[1]["skillpoints"]) + 5 - (tonumber(stats[1]["strength"]) + tonumber(stats[1]["endurance"]) + tonumber(stats[1]["intelligence"]) + tonumber(stats[1]["agility"]) + tonumber(stats[1]["luck"]))
	return available_points
end

function add_skill(player, skillname)
	-- add skill point to the given skill if skillpoints available
	if calc_available_skill_points(player) > 0 then
		local stats = get_stats(player)
		set_stats(player, skillname[2], tonumber(stats[1][skillname[2]]) + 1)
		if skillname[2] == "intelligence" then
			set_stats(player, "magic_max", stats[1]["magic_max"] + 10)
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
		if math.random(0,100) < tonumber(stats[1]["luck"]) then
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
			TDI.FinalDamage = TDI.FinalDamage * 5 / stats[1]["endurance"] -- add damage for better balance
			send_battlelog(player, "you got " .. TDI.FinalDamage .. " Damage")
			-- add dodge with LUCK and AGILITY
			if math.random(0,100) < (tonumber(stats[1]["luck"]) + tonumber(stats[1]["agility"])) then
				TDI.FinalDamage = 0
				send_battlelog(player, "you got dodged the Attack")
			end
		end

		-- Fall Damage somewhat with agility
		if TDI.DamageType == 3 then
			TDI.FinalDamage = TDI.FinalDamage / (stats[1]["agility"] / 5)
			send_battlelog(player, "you got " .. TDI.FinalDamage .. " Fall Damage")
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

function calc_level(exp)
	-- create some function to  calc levels
	exp = tonumber(exp)
	local level = 1
	while exp > 200 * level do
		exp = exp / (2 * level + 1)
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
