command, player = ...
if command[2] == "revive" then -- TODO ask for revive
  if command[2] == player:GetName() then
    player:SendMessage("you can't revive yourself")
  end
  local revive_player = function(player)
    local stats = get_stats(player)
    player:SetInvulnerableTicks(500)
    player:SetPosX(stats["last_killedx"])
    player:SetPosY(stats["last_killedy"])
    player:SetPosZ(stats["last_killedz"])
    send_battlelog(player, "you have been revived")
  end
  if cRoot:Get():FindAndDoWithPlayer(command[3], revive_player) then
    send_battlelog(player, "you revived " .. command[3])
  else
    send_battlelog(player, "can't revive " .. command[3] .. ", Player not found.")
  end
end
