local YOOTIL = require(script:GetCustomProperty("YOOTIL"))

local container = script:GetCustomProperty("container"):WaitForObject()
local tpl = script:GetCustomProperty("tpl")

local queue = YOOTIL.Utils.Queue:new()
local current_item = nil

local tween = nil

function Tick(dt)
	if(queue:length() > 0 and current_item == nil) then
		current_item = queue:pop()

		current_item.notification = World.SpawnAsset(tpl, { parent = container })
		current_item.message = current_item.notification:FindDescendantByName("Message")

		if(current_item.msg ~= nil) then
			current_item.message.text = current_item.msg
		else
			current_item.message.text = "1 " .. current_item.crop .. " is ready for harvesting."
		end

		current_item.notification.x = -current_item.notification.width
		current_item.notification.y = 0

		tween = YOOTIL.Tween:new(.4, { x = current_item.notification.x }, { x = 45 })
			
		tween:set_easing("outBack")
		tween:on_change(function(c)
			current_item.notification.x = c.x
		end)
			
		tween:on_complete(function()
			tween = YOOTIL.Tween:new(.4, { x = current_item.notification.x }, { x = -current_item.notification.width })

			tween:set_easing("inBack")
			tween:on_change(function(c)
				current_item.notification.x = c.x
			end)

			tween:set_delay(10)
			tween:on_complete(function()
				tween = nil
				current_item.notification:Destroy()
				current_item = nil
			end)
		end)

		tween:set_delay(.6)
	end

	if(tween ~= nil) then
		tween:tween(dt)
	end
end

local function add_to_item(item, crop)
	item.total = item.total + 1

	local plu = ""

	if(item.total ~= 1) then
		plu = "s"
	end

	if(item.message ~= nil) then
		item.message.text = tostring(item.total) .. " " .. crop .. plu .. " are ready for harvesting."
	else
		item.msg = tostring(item.total) .. " " .. crop .. plu .. " are ready for harvesting."
	end
end

local function added_to_existing_queue_item(crop)
	local list = queue.list

	for i, item in ipairs(list) do
		if(item.crop == crop) then
			add_to_item(item, crop)

			return true
		end
	end

	return false
end

Events.Connect("add_crop_notification", function(crop)
	if(current_item ~= nil and current_item.crop == crop) then
		add_to_item(current_item, crop)
	elseif(not added_to_existing_queue_item(crop)) then
		queue:push({

			total = 1,
			crop = crop,
			message = nil,
			tween = nil,
			notification = nil,
			msg = nil

		})
	end
end)