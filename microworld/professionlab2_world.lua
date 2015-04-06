local ProfessionLab2 = class()

function ProfessionLab2:start()
  local player_id = microworld:get_local_player_id()
  local pop = stonehearth.population:get_population(player_id)
  
  -- Create the world
  microworld:create_world(32)
  
  -- Stockpiles!
  microworld:place_stockpile(-5, -5, 10, 10)
  
  -- Add some stone
  microworld:place_entity_cluster('stonehearth:resources:stone:hunk_of_stone', -5, -5, 3, 3)

  -- Add some wood
  microworld:place_entity_cluster('stonehearth:resources:wood:oak_log', 0, -5, 3, 3)
  
  -- Mason
  local mason = microworld:place_citizen(0, 0, 'stonehearth:jobs:mason')
  microworld:create_workbench(mason, 5, 5)
  local mason_job = mason:get_component('stonehearth:job')
  for i = 1, 6 do
    mason_job:_level_up()
  end
end

return ProfessionLab2