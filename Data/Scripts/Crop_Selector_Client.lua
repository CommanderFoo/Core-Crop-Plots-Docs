local YOOTIL = require(script:GetCustomProperty("YOOTIL"))

local crop_panel = script:GetCustomProperty("crop_panel"):WaitForObject()
local close_button = script:GetCustomProperty("close_button"):WaitForObject()
local crop_list = script:GetCustomProperty("crop_list"):WaitForObject()
local crop_lookup = script:GetCustomProperty("crop_lookup"):WaitForObject()
local crop_item = script:GetCustomProperty("crop_item")
local click_sound = script:GetCustomProperty("click_sound"):WaitForObject()

local showing = false
local local_player = Game.GetLocalPlayer()

local function close_crop_menu()
	if(showing) then
		click_sound:Play()
		crop_panel.visibility = Visibility.FORCE_OFF
		UI.SetCanCursorInteractWithUI(false)
		UI.SetCursorVisible(false)
		showing = false

		Events.Broadcast("turn_on_zone_reticle")
	end
end

local function build_ui()
	for i, c in pairs(crop_list:GetChildren()) do
		c:Destroy()
	end

	local offset = 0

	for i, c in ipairs(crop_lookup:GetChildren()) do
		local item = World.SpawnAsset(crop_item, { parent = crop_list })
		local icon = c:GetCustomProperty("icon")
		local button = item:GetCustomProperty("button"):GetObject()
		local resource_key = c:GetCustomProperty("resource_key")

		item:GetCustomProperty("desc_txt"):GetObject().text = c:GetCustomProperty("description")
		item:GetCustomProperty("icon"):GetObject():SetImage(icon)
		item:GetCustomProperty("time_txt"):GetObject().text = tostring(c:GetCustomProperty("growth_time")) .. " secs"

		button.clickedEvent:Connect(function()
			click_sound:Play()
			Events.Broadcast("try_plant_crop", c:GetCustomProperty("id"))
			close_crop_menu()
		end)

		if(string.len(resource_key) > 0) then
			if(local_player:GetResource("seed_" .. resource_key) == 0) then
				button.isInteractable = false
			end
		else
			button.isInteractable = false
		end
	
		item.y = offset
		offset = offset + 120
	end
end

local function open_crop_menu()
	if(not showing) then
		
		-- We rebuild the UI each time because things are a little dynamic

		build_ui()

		crop_panel.visibility = Visibility.FORCE_ON
		UI.SetCanCursorInteractWithUI(true)
		UI.SetCursorVisible(true)
		showing = true

		Events.Broadcast("turn_off_zone_reticle")
	end
end

close_button.clickedEvent:Connect(close_crop_menu)

Events.Connect("open_crop_menu", open_crop_menu)
Events.Connect("close_crop_menu", close_crop_menu)