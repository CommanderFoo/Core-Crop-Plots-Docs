local YOOTIL = require(script:GetCustomProperty("YOOTIL"))

local panel = script:GetCustomProperty("panel"):WaitForObject()
local tpl = script:GetCustomProperty("tpl")
local lookup = script:GetCustomProperty("lookup"):WaitForObject()
local container = script:GetCustomProperty("container"):WaitForObject()
local click_sound = script:GetCustomProperty("click_sound"):WaitForObject()
local trigger = script:GetCustomProperty("trigger"):WaitForObject()
local close = script:GetCustomProperty("close"):WaitForObject()
local buy_sound = script:GetCustomProperty("buy_sound"):WaitForObject()

local showing = false
local local_player = Game.GetLocalPlayer()

local function buy_crop(id, price, quantity)
	if(local_player:GetResource("money") >= price) then
		YOOTIL.Events.broadcast_to_server("buy_crop", id, quantity)
		buy_sound:Play()
	end
end

local function update_buttons()
	for i, c in ipairs(lookup:GetChildren()) do
		local item = container:FindDescendantByName("Resource seed_" .. c:GetCustomProperty("resource_key"))
		
		if(item ~= nil) then
			local buy_1 = item:GetCustomProperty("buy_1"):GetObject()
			local buy_max = item:GetCustomProperty("buy_max"):GetObject()

			if(local_player:GetResource("money") < c:GetCustomProperty("buy_price")) then
				buy_1.isInteractable = false
				buy_max.isInteractable = false
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
		local price = c:GetCustomProperty("buy_price")
		local buy_1 = item:GetCustomProperty("buy_1"):GetObject()
		local buy_max = item:GetCustomProperty("buy_max"):GetObject()

		item.name = "Resource seed_" .. c:GetCustomProperty("resource_key")
		item.parent = container

		item:GetCustomProperty("desc_txt"):GetObject().text = c:GetCustomProperty("description")
		item:GetCustomProperty("icon"):GetObject():SetImage(icon)
		item:GetCustomProperty("price"):GetObject().text = "$" .. tostring(price)

		if(local_player:GetResource("money") >= price) then
			buy_1.isInteractable = true
			buy_max.isInteractable = true

			buy_1.clickedEvent:Connect(function()
				buy_crop(c:GetCustomProperty("id"), price, 1)

				update_buttons()
			end)

			buy_max.clickedEvent:Connect(function()
				buy_crop(c:GetCustomProperty("id"), price, -1)

				update_buttons()
			end)
		else
			buy_1.isInteractable = false
			buy_max.isInteractable = false
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