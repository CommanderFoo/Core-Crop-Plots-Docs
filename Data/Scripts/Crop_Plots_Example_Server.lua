-- For the sake of the example to prevent the player spawning inside the trigger
-- this script moves their spawn position.

-- Just make sure not to spawn the player inside their owned zone, or it will not
-- become active.  They would need to walk out of the zone then back.  This can be solved
-- by checking the overlapping objects of the trigger, but this is a waste of resources
-- when the problem can be solved by making sure the player is outside the zone when
-- they spawn in when joining the game.

Game.playerJoinedEvent:Connect(function(player)
	player:SetWorldPosition(Vector3.New(-337.570, -42.070, player:GetWorldPosition().z))
end)