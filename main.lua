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

	PLUGIN = Plugin -- NOTE: only needed if you want OnDisable() to use GetName() or something like that

	-- Command Bindings
	cPluginManager.BindCommand("/skills", "mmo.skills", skills, " ~ list skills or add skillpoints")
	cPluginManager.BindCommand("/battlelog", "mmo.battlelog", battlelog, " - turn battlelog on / off")
	cPluginManager.BindCommand("/spell", "mmo.spell", spell, " ~ cast a spell")


	-- Database stuff
	db = cSQLiteHandler("mmo.sqlite")
	create_database()

	-- declare global variables
	counter = 0

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

function spell(command, player)
	--TODO add more spells like invisible, antidamage, fireball, summon golem?, summon meat
	if #command == 1 then
		player:SendMessage("/spell heal <player> | 10M | heal a player")
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
		if command[2] == "heal" then
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
		end
	end
	return true
end

function rem_magic(player, amount)
	stats = get_stats(player)
	if tonumber(stats[1]["magic"]) >= amount then
		local updateList = cUpdateList()
		:Update("magic", (stats[1]["magic"] - amount))
		local whereList = cWhereList()
		:Where("name", player:GetName())
		local res = db:Update("mmo", updateList, whereList)
		send_battlelog(player, "Magic: " .. stats[1]["magic"] - amount .. " of " .. stats[1]["magic_max"])
		return true
	else
		send_battlelog(player, "not enough Magic!")
		return false
	end
end

function add_magic_regeneration(player, percentage)
	local stats = get_stats(player)
	if tonumber(stats[1]["magic"]) < tonumber(stats[1]["magic_max"]) then
		local updateList = cUpdateList()
		:Update("magic", (stats[1]["magic"] + (stats[1]["magic_max"] * percentage / 100)))
		local whereList = cWhereList()
		:Where("name", player:GetName())
		local res = db:Update("mmo", updateList, whereList)
		send_battlelog(player, "Magic: " .. stats[1]["magic"] + (stats[1]["magic_max"] * percentage / 100) .. " of " .. stats[1]["magic_max"])
	end
end

function MyOnWorldTick(World, TimeDelta)
	-- add MAGIC regeneration
	local callback = function(player)
		if counter > 50 then
			counter = 0
			add_magic_regeneration(player, 1)
		end
		counter = counter + 1
	end
	World:ForEachPlayer(callback)
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
	 if calc_available_skill_points(Player) ~= 0 then
		 Player:SendMessage("Available Skillpoints: " .. calc_available_skill_points(Player))
	 end
end

function get_stats (Player)
	local whereList = cWhereList()
	:Where("name", Player:GetName())
	local res = db:Select("mmo", "*", whereList)
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
	if (TDI.Attacker ~= nil and TDI.Attacker:IsPlayer()) then
		local exp = 0
		player = tolua.cast(TDI.Attacker, "cPlayer")
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
		if give_exp(exp, player) then
			local lvl = calc_level(get_exp(player))
			send_battlelog(player, "Level UP! you are now Level " .. lvl)
		end
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
		local skill = tonumber(stats[1][skillname[2]]) + 1
		local updateList = cUpdateList()
		:Update(skillname[2], skill)
		local whereList = cWhereList()
		:Where("name", player:GetName())
		local res = db:Update("mmo", updateList, whereList)
		if skillname[2] == "intelligence" then
			local updateList = cUpdateList()
			:Update("magic_max", (stats[1]["magic_max"] + 10))
			local whereList = cWhereList()
			:Where("name", player:GetName())
			local res = db:Update("mmo", updateList, whereList)
		end
	end
	return true
end

function skills(skillname, player)
	if skillname[2] == nil then
		show_stats(player)
		return true
	end
	if skillname[2] == "strength" and add_skill(player, skillname) then
		player:SendMessage("added 1 Point to Strength")
	end
	if skillname[2] == "endurance" and add_skill(player, skillname) then
		player:SendMessage("added 1 Point to Endurance")
	end
	if skillname[2] == "intelligence" and add_skill(player, skillname) then
		player:SendMessage("added 1 Point to Intelligence")
	end
	if skillname[2] == "agility" and add_skill(player, skillname) then
		player:SendMessage("added 1 Point to Agility")
	end
	if skillname[2] == "luck" and add_skill(player, skillname) then
		player:SendMessage("added 1 Point to Luck")
	end
	return true
end

function MyOnTakeDamage(Receiver, TDI)
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
	local whereList = cWhereList()
	:Where("name", player:GetName())
	local res = db:Select("mmo", "exp", whereList)
	return res[1]["exp"]
end

function send_battlelog(player, message)
	-- Get if battlelog is on or off from DB
	local whereList = cWhereList()
	:Where("name", player:GetName())
	local res = db:Select("mmo", "battlelog", whereList)
	if res[1]["battlelog"] == "1" then
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
	local updateList = cUpdateList()
	:Update("exp", exp_after)
	:Update("skillpoints", calc_level(exp_after) - 1)
	local whereList = cWhereList()
	:Where("name", player:GetName())
	local res = db:Update("mmo", updateList, whereList)
	local level_after = calc_level(cexp)
	if level_before < level_after then
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
)
  return true
end
