command, a_Player = ...
	local World = a_Player:GetWorld()

	for I=1, 30, 2 do
		World:ScheduleTask(I,
			function()
				local EyePos = a_Player:GetEyePosition()
				local EntityID = World:SpawnFallingBlock(EyePos.x, EyePos.y, EyePos.z, E_BLOCK_PACKED_ICE, 0)
				World:DoWithEntityByID(EntityID,
					function(a_Entity)
						a_Entity:SetSpeed(a_Player:GetLookVector() * 50)
					end
				)
				local function CheckOtherEntities(a_EntityID)
					World:ScheduleTask(1,
						function()
							if (World:DoWithEntityByID(a_EntityID,
								function(a_FallingBlock)
									local Pos = a_FallingBlock:GetPosition()
									local Speed = a_FallingBlock:GetSpeed()
									World:ForEachEntityInChunk(a_FallingBlock:GetChunkX(), a_FallingBlock:GetChunkZ(),
										function(a_OtherEntity)
											if (a_OtherEntity:GetEntityType() ~= cEntity.etFallingBlock) then
												if ((a_OtherEntity:GetPosition() - Pos):Length() < 2) then
													a_OtherEntity:TakeDamage(a_Player)
													a_OtherEntity:AddSpeed(Speed * 2)
													a_OtherEntity:AddSpeedY(3)
												end
											end
										end
									)
								end
							)) then
								CheckOtherEntities(a_EntityID)
							end
						end
					)
				end
				CheckOtherEntities(EntityID)
			end
		)
	end
