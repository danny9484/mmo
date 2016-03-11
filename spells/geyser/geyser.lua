local E_DIRECTION_NORTH1 = 0
local E_DIRECTION_NORTH2 = 4
local E_DIRECTION_EAST = 1
local E_DIRECTION_SOUTH = 2
local E_DIRECTION_WEST = 3
local function Round(a_Number)
	assert(type(a_Number) == 'number')

	local Number, Decimal = math.modf(a_Number)
	if Decimal >= 0.5 then
		return Number + 1
	else
		return Number
	end
end
command, a_Player = ...
	local World = a_Player:GetWorld()
	local LookVector = a_Player:GetLookVector()
	LookVector:Normalize()
	LookVector.y = 0
	local Pos = a_Player:GetPosition() + (LookVector * 1.5)

	local Position = Vector3d(Pos)
	local LookVector2 = Vector3d(LookVector.x, LookVector.y, LookVector.z)
	local Direction = Round(a_Player:GetYaw() / 90)
	local UseZ = true
	if ((Direction == E_DIRECTION_NORTH1) or (Direction == E_DIRECTION_NORTH2) or (Direction == E_DIRECTION_SOUTH)) then
		UseZ = false
	end

	for i = -0.05, 0.05, 0.05 do
		Pos = Vector3d(Position)
		if (UseZ) then
			LookVector2.z = LookVector.z + i
		else
			LookVector2.x = LookVector.x + i
		end

		for I=Pos.y, Pos.y + 12, 0.5 do
			Pos = Pos + LookVector2
			local ChunkX, ChunkZ = math.floor(Pos.x / 16), math.floor(Pos.z / 16)
			World:ForEachEntityInChunk(ChunkX, ChunkZ,
				function(a_Entity)
					local Distance = (Pos - a_Entity:GetPosition()):Length()
					if (Distance < 1) then
						if ((a_Entity:IsPlayer()) and (a_Entity:GetUniqueID() ~= a_Player:GetUniqueID())) then
							local Speed = a_Enity:GetSpeed()
							Speed.y = Speed.y + 30
							a_Entity:ForceSetSpeed(Speed)
						else
							a_Entity:SetSpeedY(30)
						end
					end
				end
			)

			local function FindLowestBlock()
				for Y = Pos.y, 0, -1 do
					if (World:GetBlock(Pos.x, Y, Pos.z) ~= E_BLOCK_AIR) then
						return Y + 1
					end
				end
				return 0
			end

			for Y = I, FindLowestBlock(), -1 do
				local VectorPos = Vector3i(Pos)
				World:SetBlock(VectorPos.x, Y, VectorPos.z, E_BLOCK_PACKED_ICE, 0)
				World:ScheduleTask(36,
					function()
						World:SetBlock(VectorPos.x, Y, VectorPos.z, E_BLOCK_AIR, 0)
						local EntityID = World:SpawnFallingBlock(VectorPos.x, Y, VectorPos.z, E_BLOCK_PACKED_ICE, 0)
						World:DoWithEntityByID(EntityID,
							function(a_Entity)
								a_Entity:SetSpeed(math.random(-4, 4), math.random(1, 4), math.random(-4, 4))
							end
						)
					end
				)
			end
		end
	end
