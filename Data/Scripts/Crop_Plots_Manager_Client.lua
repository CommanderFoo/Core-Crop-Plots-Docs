local YOOTIL = require(script:GetCustomProperty("YOOTIL"))

local crop_lookup = script:GetCustomProperty("crop_lookup"):WaitForObject()
local reticle = script:GetCustomProperty("reticle"):WaitForObject()
local time_tpl = script:GetCustomProperty("time_tpl")
local plots = script:GetCustomProperty("plots"):WaitForObject()
local plant_sound = script:GetCustomProperty("plant_sound"):WaitForObject()
local harvest_sound = script:GetCustomProperty("harvest_sound"):WaitForObject()

local local_player = Game.GetLocalPlayer()
local assigned_zones = {}
local can_raycast = false
local last_crop_bed_selected = nil
local showing_timers = false
local local_received = false

local stage_2_tweens = {}
local stage_3_tweens = {}

local function get_crop_data(id)
	for i, c in ipairs(crop_lookup:GetChildren()) do
		if(c:GetCustomProperty("id") == tonumber(id)) then
			return c
		end
	end

	return nil
end

local function clear_crop_bed(bed)
	local container = bed:FindDescendantByName("Spawned Crop")

	if(Object.IsValid(container)) then
		for i, c in pairs(container:GetChildren()) do
			c:Destroy()
		end
	end
end

local function clear_all_crop_beds(zone)
	local beds = zone.parent:FindDescendantsByName("Crop Plots - Crop Bed")

	for i, b in ipairs(beds) do
		clear_crop_bed(b)
	end
end

local function disable_grown_effect(bed)
	bed:FindDescendantByName("Grown Effect"):Stop()
end

local function enable_grown_effect(bed)
	bed:FindDescendantByName("Grown Effect"):Play()
end

local function plant_crop_from_zone_data(bed_data, b, skip_time)
	local crop_data = get_crop_data(bed_data.c)

	if(crop_data ~= nil and bed_data ~= nil) then
		local item = World.SpawnAsset(crop_data:GetCustomProperty("template"), { parent = b:FindChildByName("Spawned Crop") })
		local remaining = (bed_data.st + bed_data.gt) - os.time()
		local stage_time = bed_data.gt / 2

		if(remaining <= 0) then
			item:SetPosition(crop_data:GetCustomProperty("stage_3_pos"))
			item:SetScale(crop_data:GetCustomProperty("stage_3_scale"))

			enable_grown_effect(b)
		elseif(remaining <= (bed_data.gt - stage_time) and remaining > 0) then
			item:SetPosition(crop_data:GetCustomProperty("stage_2_pos"))
			item:SetScale(crop_data:GetCustomProperty("stage_2_scale"))
		else
			item:SetPosition(crop_data:GetCustomProperty("stage_1_pos"))
			item:SetScale(crop_data:GetCustomProperty("stage_1_scale"))
		end

		item:SetRotation(Rotation.New(0, 0, math.random(360)))
		item.name = "Crop Item"

		if(not skip_time and os.time() < (bed_data.st + bed_data.gt)) then
			local time_item = World.SpawnAsset(time_tpl, { parent = b:FindChildByName("Spawned Crop") })

			time_item.visibility = Visibility.FORCE_ON
			time_item.name = "Crop Time"
			time_item:SetPosition(Vector3.New(0, 0, 40))

			local remaining = (bed_data.st + bed_data.gt) - os.time()
			local plu = ""

			if(remaining ~= 1) then
				plu = "s"
			end

			time_item:FindChildByName("Time").text = string.format("%.0f Sec%s", remaining, plu)
		end
	end
end

local function update_zone(zone)
	if(zone.name == local_player.id or zone.name == "Zone") then
		return
	end

	local data = YOOTIL.JSON.decode(zone:GetCustomProperty("data"))

	if(data ~= nil) then
		local beds = zone.parent:FindDescendantsByName("Crop Plots - Crop Bed")

		for i, b in ipairs(beds) do
			local bed_data = data["cb_" .. tostring(b:GetCustomProperty("id"))]

			if(bed_data == nil) then
				clear_crop_bed(b)
			elseif(#b:FindDescendantByName("Spawned Crop"):GetChildren() == 0) then
				plant_crop_from_zone_data(bed_data, b, true)
			end
		end
	else
		clear_all_crop_beds(zone)
	end
end

local function update_all_zones()
	for i, p in ipairs(plots:GetChildren()) do
		local zone = p:FindChildByType("Trigger")

		if(zone.name ~= local_player.id and zone.name ~= "Zone") then
			zone.networkedPropertyChangedEvent:Connect(function(_, prop)
				if(prop == "data") then
					update_zone(zone)
				end
			end)

			update_zone(zone)
		end
	end
end

local function get_plot_zone(player_id)
	if(assigned_zones[player_id] ~= nil) then
		return assigned_zones[player_id].zone
	end

	return nil
end

local function get_plot_data(player_id)
	return YOOTIL.JSON.decode(assigned_zones[player_id].zone:GetCustomProperty("data"))
end

local function crop_bed_has_crop(crop_bed_id)
	local data = get_plot_data(local_player.id)

	for k, c in pairs(data) do
		if(tonumber(c.cb) == crop_bed_id and c.c ~= nil and tonumber(c.c) > 0) then
			return true
		end
	end

	return false
end

local function crop_bed_has_grown_crop(crop_bed_id)
	local data = get_plot_data(local_player.id)

	for k, c in pairs(data) do
		if(tonumber(c.cb) == crop_bed_id and c.c ~= nil and tonumber(c.c) > 0 and os.time() >= (c.st + c.gt)) then
			return true
		end
	end

	return false
end

local function harvest_crop(crop_bed_id)
	YOOTIL.Events.broadcast_to_server("harvest_crop", crop_bed_id)
end

local function set_raycast_binding()
	local_player.bindingPressedEvent:Connect(function(_, binding)
		if(binding == YOOTIL.Input.left_button and can_raycast) then
			local cam_player_dist = local_player:GetViewWorldPosition() - local_player:GetWorldPosition()
			local forward = local_player:GetViewWorldRotation() * Vector3.FORWARD
			local ray_start = local_player:GetViewWorldPosition() + forward * cam_player_dist.size
			local ray_end = ray_start + forward * 500

			--CoreDebug.DrawLine(ray_start, ray_end, { duration = 2, thickness = 1 })

			local hit = World.Raycast(ray_start, ray_end, { ignorePlayers = true })

			if(hit ~= nil and Object.IsValid(hit.other) and hit.other.name == "Crop Bed Collider") then
				local crop_bed_id = hit.other.parent:GetCustomProperty("id")

				if(not crop_bed_has_crop(crop_bed_id)) then
					last_crop_bed_selected = hit.other
					Events.Broadcast("open_crop_menu")
				elseif(crop_bed_has_grown_crop(crop_bed_id)) then
					harvest_crop(crop_bed_id)
				end
			end
		end
	end)
end

local function turn_on_crop_outlines(zone)
	local outlines = zone.parent:FindDescendantsByName("Outline Object")

	for i, o in ipairs(outlines) do
		o:SetSmartProperty("Enabled", true)
	end
end

local function turn_off_crop_outlines(zone)
	local outlines = zone.parent:FindDescendantsByName("Outline Object")

	for i, o in ipairs(outlines) do
		o:SetSmartProperty("Enabled", false)
	end
end

local function turn_on_reticle()
	reticle.visibility = Visibility.FORCE_ON
end

local function turn_off_reticle()
	reticle.visibility = Visibility.FORCE_OFF
end

local function hide_timers()
	showing_timers = false

	local local_data = assigned_zones[local_player.id]

	if(local_data ~= nil and local_data.zone ~= nil) then
		local data = YOOTIL.JSON.decode(local_data.zone:GetCustomProperty("data"))

		if(data ~= nil) then
			local pivots = local_data.zone.parent:FindDescendantsByName("Crop Time")

			for i, p in ipairs(pivots) do
				p.visibility = Visibility.FORCE_OFF
			end
		end
	end
end

local function show_timers()
	showing_timers = true

	local local_data = assigned_zones[local_player.id]

	if(local_data ~= nil and local_data.zone ~= nil) then
		local data = YOOTIL.JSON.decode(local_data.zone:GetCustomProperty("data"))

		if(data ~= nil) then
			local pivots = local_data.zone.parent:FindDescendantsByName("Crop Time")

			for i, p in ipairs(pivots) do
				p.visibility = Visibility.FORCE_ON
			end
		end
	end
end

local function set_highlight_handlers(zone)
	local area_triggers = zone.parent:FindDescendantsByName("Area Trigger")

	for i, t in ipairs(area_triggers) do
		t.beginOverlapEvent:Connect(function(t, obj)
			if(Object.IsValid(obj) and obj:IsA("Player") and obj.id == local_player.id) then
				t.parent:FindChildByName("Highlight").visibility = Visibility.FORCE_ON
			end
		end)

		t.endOverlapEvent:Connect(function(t, obj)
			if(Object.IsValid(obj) and obj:IsA("Player") and obj.id == local_player.id) then
				t.parent:FindChildByName("Highlight").visibility = Visibility.FORCE_OFF
			end
		end)
	end
end

local function set_zone_handlers()
	local zone = assigned_zones[local_player.id].zone

	if(zone ~= nil) then
		zone.beginOverlapEvent:Connect(function(t, obj)
			if(Object.IsValid(obj) and obj:IsA("Player") and obj.id == local_player.id) then
				can_raycast = true

				show_timers()
				turn_on_crop_outlines(zone)
				turn_on_reticle()
			end
		end)

		zone.endOverlapEvent:Connect(function(t, obj)
			if(Object.IsValid(obj) and obj:IsA("Player") and obj.id == local_player.id) then
				can_raycast = false

				hide_timers()
				turn_off_crop_outlines(zone)
				turn_off_reticle()
			end
		end)

		set_highlight_handlers(zone)
	end
end

local function plant_crop(id)
	local crop_data = get_crop_data(id)

	if(crop_data ~= nil) then
		local item = World.SpawnAsset(crop_data:GetCustomProperty("template"), { parent = last_crop_bed_selected.parent:FindChildByName("Spawned Crop") })

		item:SetPosition(crop_data:GetCustomProperty("stage_1_pos"))
		item:SetScale(crop_data:GetCustomProperty("stage_1_scale"))
		item:SetRotation(Rotation.New(0, 0, math.random(360)))
		item.name = "Crop Item"

		local time_item = World.SpawnAsset(time_tpl, { parent = last_crop_bed_selected.parent:FindChildByName("Spawned Crop") })

		time_item:FindChildByName("Time").text = tostring(crop_data:GetCustomProperty("growth_time")) .. " Secs"
		time_item.visibility = Visibility.FORCE_ON
		time_item.name = "Crop Time"
		time_item:SetPosition(Vector3.New(0, 0, 40))

		last_crop_bed_selected = nil

		Task.Wait(.1)
		plant_sound:Play()
	end
end

local function change(obj, v)
	if(Object.IsValid(obj)) then
		obj:SetScale(Vector3.New(v.sx, v.sy, v.sz))
		obj:SetPosition(Vector3.New(v.px, v.py, v.pz))
	end
end

local function tick_growth_time()
	for pid, az in pairs(assigned_zones) do
		if(az.zone ~= nil) then
			local is_local = pid == local_player.id
			local data = YOOTIL.JSON.decode(az.zone:GetCustomProperty("data"))

			if(data ~= nil) then
				local beds = az.zone.parent:FindDescendantsByName("Crop Plots - Crop Bed")

				for i, b in ipairs(beds) do
					if(data["cb_" .. tostring(b:GetCustomProperty("id"))] ~= nil) then
						local bed_data = data["cb_" .. tostring(b:GetCustomProperty("id"))]
						local ctx_obj = b:FindChildByName("Spawned Crop")
						local crop_obj = ctx_obj:FindChildByName("Crop Item")
						local time_obj = ctx_obj:FindChildByName("Crop Time")

						if(Object.IsValid(crop_obj) and bed_data ~= nil and bed_data.st ~= nil and bed_data.gt ~= nil) then
							local remaining = (bed_data.st + bed_data.gt) - os.time()
							local stage_time = bed_data.gt / 2

							if(is_local and showing_timers and Object.IsValid(time_obj)) then
								local time_txt = time_obj:FindChildByName("Time")

								if(time_txt ~= nil) then
									if((os.time() >= (bed_data.st + bed_data.gt))) then
										time_obj.visibility = Visibility.FORCE_OFF
									else
										local remaining = (bed_data.st + bed_data.gt) - os.time()

										if(remaining >= 0) then
											local plu = ""

											if(remaining ~= 1) then
												plu = "s"
											end

											time_txt.text = string.format("%.0f Sec%s", remaining, plu)
										end
									end
								end
							end

							local cur_scale = crop_obj:GetScale()
							local cur_pos = crop_obj:GetPosition()
							local crop_data = get_crop_data(bed_data.c)
							local stage_2_pos = crop_data:GetCustomProperty("stage_2_pos")
							local stage_2_scale = crop_data:GetCustomProperty("stage_2_scale")
							local stage_3_pos = crop_data:GetCustomProperty("stage_3_pos")
							local stage_3_scale = crop_data:GetCustomProperty("stage_3_scale")

							if(remaining <= 0 and remaining >= -1) then
								if(not stage_3_tweens["cb_" .. tostring(b:GetCustomProperty("id"))]) then
									if(cur_scale ~= stage_3_scale) then
										local tween = YOOTIL.Tween:new(1, {

											sx = cur_scale.x,
											sy = cur_scale.y,
											sz = cur_scale.z,

											px = cur_pos.x,
											py = cur_pos.y,
											pz = cur_pos.z

										}, {

											sx = stage_3_scale.x,
											sy = stage_3_scale.y,
											sz = stage_3_scale.z,

											px = stage_3_pos.x,
											py = stage_3_pos.y,
											pz = stage_3_pos.z

										})

										tween:on_change(function(v)
											change(crop_obj, v)
										end)

										tween:on_complete(function()
											stage_3_tweens["cb_" .. tostring(b:GetCustomProperty("id"))] = nil

											if(is_local) then
												enable_grown_effect(b)
												Events.Broadcast("add_crop_notification", crop_data:GetCustomProperty("name"))
											end
										end)

										tween:set_easing("outElastic")

										stage_3_tweens["cb_" .. tostring(b:GetCustomProperty("id"))] = tween
									end
								end
							elseif(remaining <= (bed_data.gt - stage_time) and remaining > 0) then
								if(not stage_2_tweens["cb_" .. tostring(b:GetCustomProperty("id"))]) then
									local tween = YOOTIL.Tween:new(1, {

										sx = cur_scale.x,
										sy = cur_scale.y,
										sz = cur_scale.z,

										px = cur_pos.x,
										py = cur_pos.y,
										pz = cur_pos.z

									}, {

										sx = stage_2_scale.x,
										sy = stage_2_scale.y,
										sz = stage_2_scale.z,

										px = stage_2_pos.x,
										py = stage_2_pos.y,
										pz = stage_2_pos.z

									})

									tween:on_change(function(v)
										change(crop_obj, v)
									end)

									tween:on_complete(function()
										stage_2_tweens["cb_" .. tostring(b:GetCustomProperty("id"))] = nil
									end)

									tween:set_easing("outElastic")

									stage_2_tweens["cb_" .. tostring(b:GetCustomProperty("id"))] = tween
								end
							end
						end
					end
				end
			end
		end
	end
end

local function crop_has_been_harvested(crop_bed_id)
	local zone = get_plot_zone(local_player.id)

	if(zone ~= nil) then
		local crop_beds = zone.parent:FindDescendantsByName("Crop Plots - Crop Bed")

		for i, c in ipairs(crop_beds) do
			if(c:GetCustomProperty("id") == crop_bed_id) then
				local crop_item = c:FindDescendantByName("Crop Item")
				local crop_time = c:FindDescendantByName("Crop Time")

				if(Object.IsValid(crop_item)) then
					crop_item:Destroy()
					harvest_sound:Play()
					disable_grown_effect(c)
				end

				if(Object.IsValid(crop_time)) then
					crop_time:Destroy()
				end
			end
		end
	end
end

local function add_assigned_zones()
	for i, p in ipairs(plots:GetChildren()) do
		local zone = p:FindChildByType("Trigger")

		if(zone.name ~= local_player.id) then
			assigned_zones[zone.name] = {

				zone = zone

			}
		end
	end
end

local function update_from_saved_crop_data(player, key, zone)
	if(key == "crop_data") then
		local_received = true

		local data = local_player:GetPrivateNetworkedData(key)

		if(data ~= nil and zone ~= nil) then
			local beds = zone.parent:FindDescendantsByName("Crop Plots - Crop Bed")

			for i, b in ipairs(beds) do
				local bed_data = data["cb_" .. tostring(b:GetCustomProperty("id"))]

				if(bed_data ~= nil) then
					plant_crop_from_zone_data(bed_data, b)
				end
			end
		end
	end
end

function Tick(dt)
	local local_data = assigned_zones[local_player.id]

	if(local_data ~= nil and local_data.zone ~= nil) then
		local time_obj = local_data.zone.parent:FindDescendantsByName("Crop Time")

		for i, c in ipairs(time_obj) do
			local quat = Quaternion.New(local_player:GetViewWorldRotation())

			quat = quat * Quaternion.New(Vector3.UP, 180.0)
			c:SetWorldRotation(Rotation.New(quat))
		end
	end

	tick_growth_time()

	for i, t in pairs(stage_2_tweens) do
		if(t ~= nil) then
			t:tween(dt)
		end
	end

	for i, t in pairs(stage_3_tweens) do
		if(t ~= nil) then
			t:tween(dt)
		end
	end
end

Game.playerLeftEvent:Connect(function(player)
	if(assigned_zones[player.id] ~= nil) then
		assigned_zones[player.id] = nil
	end
end)

Events.Connect("zone_assigned", function(the_zone)
	local obj = the_zone:GetObject()
	local id = obj.name

	assigned_zones[id] = {

		zone = obj

	}

	set_raycast_binding()

	if(id == local_player.id) then
		set_zone_handlers()
	
		local_player.privateNetworkedDataChangedEvent:Connect(update_from_saved_crop_data)

		for i, key in ipairs(local_player:GetPrivateNetworkedDataKeys()) do
			update_from_saved_crop_data(local_player, key, obj)
		end
	end

	update_all_zones()
end)

Events.Connect("try_plant_crop", function(id)
	if(last_crop_bed_selected ~= nil) then
		YOOTIL.Events.broadcast_to_server("try_plant_crop", id, last_crop_bed_selected.parent:GetCustomProperty("id"))
	end
end)

Events.Connect("plant_crop", plant_crop)

Events.Connect("turn_on_zone_reticle", turn_on_reticle)
Events.Connect("turn_off_zone_reticle", turn_off_reticle)

Events.Connect("harvested_crop", crop_has_been_harvested)

Task.Wait()
YOOTIL.Events.broadcast_to_server("crop_plots_ready")

add_assigned_zones()