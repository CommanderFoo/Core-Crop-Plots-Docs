local YOOTIL = require(script:GetCustomProperty("YOOTIL"))

local plots = script:GetCustomProperty("plots"):WaitForObject()
local crop_lookup = script:GetCustomProperty("crop_lookup"):WaitForObject()

local assigned_zones = {}

-- Players who join are added to this table, and removed on leaving.

local players = {}

local function get_free_zone()
	for i, c in ipairs(plots:GetChildren()) do
		local zone = c:FindChildByName("Zone")

		if(zone ~= nil and zone.name == "Zone") then
			return zone
		end
	end
end

Game.playerJoinedEvent:Connect(function(player)
	if(not players[player.id]) then
		players[player.id] = {

			movement = player.movementControlMode,
			look = player.lookControlMode,
			jump = player.maxJumpCount,
			crouch = player.isCrouchEnabled,
			mount = player.canMount

		}
	end

	local zone = get_free_zone()

	if(zone == nil) then
		return
	end

	zone.name = player.id

	assigned_zones[player.id] = {

		zone = zone,
		crops = {}

	}

	Task.Wait()

	Events.Broadcast("crop_plots_load_data", player, assigned_zones[player.id])

	zone:SetNetworkedCustomProperty("data", YOOTIL.JSON.encode(assigned_zones[player.id].crops))
end)

Game.playerLeftEvent:Connect(function(player)
	if(players[player.id] ~= nil) then
		players[player.id] = nil
	end

	if(assigned_zones[player.id] ~= nil) then
		Events.Broadcast("crop_plots_save_data", player, assigned_zones[player.id])

		assigned_zones[player.id].zone:SetNetworkedCustomProperty("data", "[]")
		assigned_zones[player.id].zone.name = "Zone"
		assigned_zones[player.id] = nil
	end
end)

local function get_crop_data(id)
	for i, c in ipairs(crop_lookup:GetChildren()) do
		if(c:GetCustomProperty("id") == tonumber(id)) then
			return c
		end
	end

	return nil
end

local function get_growth_time(id)
	local data = get_crop_data(id)

	return data:GetCustomProperty("growth_time")
end

local function add_crop(player_id, crop_id, crop_bed_id)
	if(assigned_zones[player_id] ~= nil and assigned_zones[player_id].crops["cb_" .. tostring(crop_bed_id)] == nil) then
		assigned_zones[player_id].crops["cb_" .. tostring(crop_bed_id)] = {

			c = crop_id,
			cb = crop_bed_id,
			st = os.time(),
			gt = get_growth_time(crop_id)
		}

		assigned_zones[player_id].zone:SetNetworkedCustomProperty("data", YOOTIL.JSON.encode(assigned_zones[player_id].crops))
	end
end

local function harvest_crop(player, crop_bed_id)
	if(assigned_zones[player.id] ~= nil and assigned_zones[player.id].crops["cb_" .. tostring(crop_bed_id)] ~= nil) then
		local bed_data = assigned_zones[player.id].crops["cb_" .. tostring(crop_bed_id)]

		if(os.time() >= (bed_data.st + bed_data.gt)) then
			local data = get_crop_data(bed_data.c)

			assigned_zones[player.id].crops["cb_" .. tostring(crop_bed_id)] = nil

			if(data:GetCustomProperty("resource_key")) then
				player:AddResource(data:GetCustomProperty("resource_key"), data:GetCustomProperty("harvest_amount"))
			end

			-- Broadcast to the owner client right away

			YOOTIL.Events.broadcast_to_player(player, "harvested_crop", crop_bed_id)

			-- Update networked property so all other clients know what is happening

			assigned_zones[player.id].zone:SetNetworkedCustomProperty("data", YOOTIL.JSON.encode(assigned_zones[player.id].crops))
		end
	end
end

Events.ConnectForPlayer("try_plant_crop", function(player, crop_id, crop_bed_id)
	local crop_data = get_crop_data(crop_id)

	if(crop_data ~= nil and string.len(crop_data:GetCustomProperty("resource_key")) > 0) then
		if(player:GetResource("seed_" .. crop_data:GetCustomProperty("resource_key")) > 0) then
			player:RemoveResource("seed_" .. crop_data:GetCustomProperty("resource_key"), 1)
			
			YOOTIL.Events.broadcast_to_player(player, "plant_crop", crop_id, crop_bed_id)
		
			add_crop(player.id, crop_id, crop_bed_id)
		end
	end
end)

Events.ConnectForPlayer("crop_plots_ready", function(player)
	if(assigned_zones[player.id] ~= nil and assigned_zones[player.id].zone ~= nil) then
		YOOTIL.Events.broadcast_to_all_players("zone_assigned", assigned_zones[player.id].zone:GetReference())
	end
end)

Events.ConnectForPlayer("harvest_crop", harvest_crop)

Events.ConnectForPlayer("disable_player", function(player)
	player.movementControlMode = MovementControlMode.NONE
	player.lookControlMode = LookControlMode.NONE
	player.maxJumpCount = 0
	player.isCrouchEnabled = false
	player.canMount = false
end)

Events.ConnectForPlayer("enable_player", function(player)
	if(players[player.id] ~= nil) then
		player.movementControlMode = players[player.id].movement
		player.lookControlMode = players[player.id].look
		player.maxJumpCount = players[player.id].jump
		player.isCrouchEnabled = players[player.id].crouch
		player.canMount = players[player.id].mount
	end
end)