local YOOTIL = require(script:GetCustomProperty("YOOTIL"))

-- This script dynamically adds all the possible crops the player can harvest
-- to the UI on the right side of the screen.

local container = script:GetCustomProperty("container"):WaitForObject()
local item = script:GetCustomProperty("item")
local crops = script:GetCustomProperty("crops"):WaitForObject()
local money_txt = script:GetCustomProperty("money_txt"):WaitForObject()
local seed_container = script:GetCustomProperty("seed_container"):WaitForObject()
local seed_item = script:GetCustomProperty("seed_item")

local offset = 0
local local_player = Game.GetLocalPlayer()

-- Loop through all of the crops available and add them to the UI.

for i, c in ipairs(crops:GetChildren()) do

	-- Handle crops

	local ui_item = World.SpawnAsset(item, { parent = container })
	local icon = c:GetCustomProperty("icon")
	local amount = ui_item:FindDescendantByName("Amount")

	ui_item:FindChildByName("Crop Image"):SetImage(icon)
	ui_item.y = offset

	amount.name = "Resource " .. c:GetCustomProperty("resource_key")
	amount.text = tostring(local_player:GetResource(c:GetCustomProperty("resource_key")))

	-- Handle crop seeds

	local ui_item = World.SpawnAsset(seed_item, { parent = seed_container })
	local icon = c:GetCustomProperty("icon")
	local amount = ui_item:FindDescendantByName("Amount")

	ui_item:FindChildByName("Crop Image"):SetImage(icon)
	ui_item.y = offset

	amount.name = "Resource seed_" .. c:GetCustomProperty("resource_key")
	amount.text = tostring(local_player:GetResource("seed_" .. c:GetCustomProperty("resource_key")))

	offset = offset + 80
end

container.height = 80 * #crops:GetChildren()
seed_container.height = container.height

-- Updates the UI when a resource has changed.

local function update_ui(key, amount)
	local amount_obj = container:FindDescendantByName("Resource " .. key)

	if(amount_obj ~= nil) then
		amount_obj.text = tostring(amount)
	end

	if(string.find(key, "seed_")) then
		local amount_obj = seed_container:FindDescendantByName("Resource " .. key)

		if(amount_obj ~= nil) then
			amount_obj.text = tostring(amount)
		end
	end
end

-- Resource changed event will fire when an item in their resource pool gets updated.

local_player.resourceChangedEvent:Connect(function(p, name, new_amount)
	if(name == "money") then
		money_txt.text = "$" .. YOOTIL.Utils.number_format(new_amount)
	else
		update_ui(name, new_amount)
	end
end)