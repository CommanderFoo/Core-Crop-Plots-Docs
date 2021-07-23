local YOOTIL = require(script:GetCustomProperty("YOOTIL"))

local panel = script:GetCustomProperty("panel"):WaitForObject()
local tpl = script:GetCustomProperty("tpl")
local lookup = script:GetCustomProperty("lookup"):WaitForObject()
local container = script:GetCustomProperty("container"):WaitForObject()
local click_sound = script:GetCustomProperty("click_sound"):WaitForObject()
local trigger = script:GetCustomProperty("trigger"):WaitForObject()
local close = script:GetCustomProperty("close"):WaitForObject()
local sell_sound = script:GetCustomProperty("sell_sound"):WaitForObject()

local showing = false
local local_player = Game.GetLocalPlayer()

local function update_buttons()
	for i, c in ipairs(lookup:GetChildren()) do
		local item = container:FindDescendantByName("Resource " .. c:GetCustomProperty("resource_key"))
		
		if(item ~= nil) then
			local sell_1 = item:GetCustomProperty("sell_1"):GetObject()
			local sell_max = item:GetCustomProperty("sell_max"):GetObject()

			if(local_player:GetResource(c:GetCustomProperty("resource_key")) == 0) then
				sell_1.isInteractable = false
				sell_max.isInteractable = false
			end
		end
	end
end

local function build_ui()
	for i, c in pairs(container:GetChildren()) do
		c:Destroy()
	end

	local offset = 0

	for i, c in ipairs(lookup:GetChildren()) do
		local item = World.SpawnAsset(tpl)
		local icon = c:GetCustomProperty("icon")
		local price = c:GetCustomProperty("sell_price")
		local sell_1 = item:GetCustomProperty("sell_1"):GetObject()
		local sell_max = item:GetCustomProperty("sell_max"):GetObject()

		item.name = "Resource " .. c:GetCustomProperty("resource_key")
		item.parent = container

		item:GetCustomProperty("desc_txt"):GetObject().text = c:GetCustomProperty("description")
		item:GetCustomProperty("icon"):GetObject():SetImage(icon)
		item:GetCustomProperty("price"):GetObject().text = "$" .. tostring(price)

		if(local_player:GetResource(c:GetCustomProperty("resource_key")) >= 1) then
			sell_1.isInteractable = true
			sell_max.isInteractable = true

			sell_1.clickedEvent:Connect(function()
				YOOTIL.Events.broadcast_to_server("sell_crop", c:GetCustomProperty("id"), 1)
				sell_sound:Play()
				update_buttons()
			end)

			sell_max.clickedEvent:Connect(function()
				YOOTIL.Events.broadcast_to_server("sell_crop", c:GetCustomProperty("id"), -1)
				sell_sound:Play()
				update_buttons()
			end)
		else
			sell_1.isInteractable = false
			sell_max.isInteractable = false
		end

		item.y = offset

		offset = offset + 120
	end
end

local function show_panel()
	if(not showing) then

		-- We rebuild the UI each time because things are a little dynamic

		build_ui()

		panel.visibility = Visibility.FORCE_ON
		UI.SetCanCursorInteractWithUI(true)
		UI.SetCursorVisible(true)
		showing = true
		trigger.isInteractable = false

		YOOTIL.Events.broadcast_to_server("disable_player")
	end
end

local function close_panel()
	if(showing) then
		click_sound:Play()
		panel.visibility = Visibility.FORCE_OFF
		UI.SetCanCursorInteractWithUI(false)
		UI.SetCursorVisible(false)
		showing = false
		trigger.isInteractable = true

		YOOTIL.Events.broadcast_to_server("enable_player")
	end
end

trigger.interactedEvent:Connect(function(t, obj)
	if(obj:IsA("Player") and obj.id == local_player.id) then
		show_panel()
	end
end)

close.clickedEvent:Connect(close_panel)