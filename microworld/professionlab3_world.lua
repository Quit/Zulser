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

  -- Add Upsie

  microworld:place_entity('zulser:machinery:conveyor_belt_upsie', 10, 5, {full_size = true})
  
  -- Carpenter
  local carpenter = microworld:place_citizen(0, 0, 'stonehearth:jobs:carpenter')
  microworld:create_workbench(carpenter, 5, 5)
  local carpenter_job = carpenter:get_component('stonehearth:job')
  for i = 1, 6 do
    carpenter_job:_level_up()
  end
end

return ProfessionLab