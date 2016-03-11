command, a_Player = ...
	local World = a_Player:GetWorld()

	local Position = a_Player:GetPosition()
	Position.x = math.floor(Position.x)
	Position.z = math.floor(Position.z)

	local MinX, MaxX = Position.x - 5, Position.x + 5
	local MinY, MaxY = Position.y - 1, Position.y + 5
	local MinZ, MaxZ = Position.z - 5, Position.x + 5
	for X = MinX, MaxX do
		for Z = MinZ, MaxZ do
			local Pos = Vector3d(X, Position.y, Z)
			local Distance = (Position - Pos):Length()
			if (math.floor(Distance) == 4) then
				local Ticks = math.random(6)
				for Y = MinY, MaxY do
					World:SetBlock(X, Y, Z, E_BLOCK_PACKED_ICE, 0)
					Ticks = Ticks + 2 + math.random(6)
				end

			elseif (Distance < 4) then
				World:SetBlock(X, MinY, Z, E_BLOCK_PACKED_ICE, 0)
				World:SetBlock(X, MaxY, Z, E_BLOCK_PACKED_ICE, 0)
			end
		end
	end

	World:SetBlock(Position.x, Position.y, Position.z, E_BLOCK_TORCH, 0)
