local ProfessionLab = class()

function ProfessionLab:start()
  local player_id = microworld:get_local_player_id()
  local pop = stonehearth.population:get_population(player_id)
  
  -- Create the world
  microworld:create_world(32)
  
  -- Stockpiles!
  microworld:place_stockpile(-5, -5, 10, 10)
  
  -- Add some wood
  microworld:place_entity_cluster('stonehearth:resources:wood:oak_log', -5, -5, 5, 5)
  microworld:place_entity_cluster('stonehearth:resources:stone:hunk_of_stone', 0, -5, 5, 5)
  
  
  -- Carpenter
  local carpenter = microworld:place_citizen(0, 0, 'stonehearth:jobs:carpenter')
  microworld:create_workbench(carpenter, 5, 5)
  local carpenter_job = carpenter:get_component('stonehearth:job')
  for i = 1, 6 do
    carpenter_job:_level_up()
  end
  
  -- Mason
  local mason = microworld:place_citizen(0, 0, 'stonehearth:jobs:mason')
  microworld:create_workbench(mason, -5, 5)
  local mason_job = mason:get_component('stonehearth:job')
  for i = 1, 6 do
    mason_job:_level_up()
  end
end

return ProfessionLab