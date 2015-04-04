local ProfessionLab = class()

function ProfessionLab:start()
  local player_id = microworld:get_local_player_id()
  local pop = stonehearth.population:get_population(player_id)
  
  -- Create the world
  microworld:create_world(32)
  
  -- Stockpiles!
  microworld:place_stockpile(-5, -5, 10, 10)
  
  -- Add some wood
  microworld:place_entity_cluster('stonehearth:resources:wood:oak_log', -5, -5, 3, 3)
  
  -- Carpenter
  local carpenter = microworld:place_citizen(0, 0, 'stonehearth:jobs:carpenter')
  microworld:create_workbench(carpenter, 5, 5)
end

return ProfessionLab