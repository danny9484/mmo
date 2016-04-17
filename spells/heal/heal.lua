--	command[2] in this case is heal and command[3] should be a player
-- player is the playerobject

command, player = ...
	if #command == 2 then
		if command[2] == "heal" then
			if tonumber(stats[player:GetUUID()]["health"]) + 5 > player:GetMaxHealth() then
  			stats[player:GetUUID()]["health"] = player:GetMaxHealth()
			else
				stats[player:GetUUID()]["health"] = tonumber(stats[player:GetUUID()]["health"] + 5)
			end
			send_battlelog(player, "you have been healed")
		end
		return true
	end
	if #command == 3 then
		if command[2] == "heal" then -- start heal
			local heal_player = function(player)
				if tonumber(stats[player:GetUUID()]["health"]) + 5 > player:GetMaxHealth() then
					stats[player:GetUUID()]["health"] = player:GetMaxHealth()
				else
					stats[player:GetUUID()]["health"] = tonumber(stats[1]["health"] + 5)
				end
				send_battlelog(player, "you have been healed")
			end
				if cRoot:Get():FindAndDoWithPlayer(command[3], heal_player) then
					send_battlelog(player, "you healed " .. command[3])
				else
					send_battlelog(player, "can't heal " .. command[3] .. ", Player not found.")
				end
			return true
		end	-- end Heal
	end
