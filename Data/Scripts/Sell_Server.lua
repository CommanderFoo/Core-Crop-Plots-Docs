local YOOTIL = require(script:GetCustomProperty("YOOTIL"))

local crop_lookup = script:GetCustomProperty("crop_lookup"):WaitForObject()

local function get_crop_data(id)
	for i, c in ipairs(crop_lookup:GetChildren()) do
		if(c:GetCustomProperty("id") == tonumber(id)) then
			return c
		end
	end

	return nil
end

Events.ConnectForPlayer("sell_crop", function(player, id, quantity)
	local data = get_crop_data(id)

	if(data ~= nil and string.len(data:GetCustomProperty("resource_key")) > 0) then
		if(player:GetResource(data:GetCustomProperty("resource_key")) >= 1) then
			local total = 1
			local total_price = data:GetCustomProperty("sell_price")

			if(quantity == -1) then
				total = player:GetResource(data:GetCustomProperty("resource_key"))
				total_price = total * total_price
			end

			player:RemoveResource(data:GetCustomProperty("resource_key"), total)
			player:AddResource("money", total_price)
		end
	end
end)