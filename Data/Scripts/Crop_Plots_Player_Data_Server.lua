local YOOTIL = require(script:GetCustomProperty("YOOTIL"))

local crop_lookup = script:GetCustomProperty("crop_lookup"):WaitForObject()

local function load_player_data(player, zone_data)

	-- Set player crop resources

	local data = Storage.GetPlayerData(player) or {}

	for i, c in ipairs(crop_lookup:GetChildren()) do
		local key = c:GetCustomProperty("resource_key")

		if(key ~= nil and string.len(key) > 0) then
			if(data[key] ~= nil) then
				player:SetResource(key, data[key])
			end

			-- For the example we setup some starting seeds.  It's advised to remove this
			-- for your own game.

			if(data["seed_" .. key] == nil) then
				data["seed_" .. key] = 5	
			end

			player:SetResource("seed_" .. key, data["seed_" .. key])
		end
	end

	if(data.money ~= nil) then

		-- For the example we will give the player 250 from the start if their
		-- amount is 0.  This should be removed on live if money is used as a
		-- form of currency, otherwise the player will never have less than 250.

		if(data.money == 0) then
			data.money = 250
		end

		player:SetResource("money", data.money or 0)
	end

	-- Handle crop plot data

	if(data.crops ~= nil) then
		zone_data.crops = data.crops

		-- Send it to the client.
		
		player:SetPrivateNetworkedData("crop_data", data.crops)
	end
end

-- Handles saving the player resources and crop plot data for each bed.

local function save_player_data(player, zone_data)
	local data = Storage.GetPlayerData(player) or {}

	-- Handle resources by looking over the crops to see if they have a resource key

	for i, c in ipairs(crop_lookup:GetChildren()) do
		local key = c:GetCustomProperty("resource_key")

		if(key ~= nil and string.len(key) > 0) then
			data[key] = player:GetResource(key)
			data["seed_" .. key] = player:GetResource("seed_" .. key)
		end
	end

	-- Set the zone data.  Contains everything about all the plot crops.

	data.crops = zone_data.crops

	data.money = player:GetResource("money")
	
	Storage.SetPlayerData(player, data)
end

Events.Connect("crop_plots_save_data", save_player_data)
Events.Connect("crop_plots_load_data", load_player_data)