local World = class()
local Point3 = _radiant.csg.Point3

local ci = 1
local function create_conveyor(x, z, rot, resource, mat)
   local ent = microworld:place_entity('zulser:machinery:conveyor_belt:' .. (mat or 'wood'), x, z, { full_size = true, owner = microworld:get_local_player_id() })
   radiant.entities.turn_to(ent, rot)
   radiant.entities.set_display_name(ent, 'C ' .. ci)
   ci = ci + 1
   
   if resource then
      radiant.events.listen_once(radiant, 'stonehearth:gameloop', function()
         resource = radiant.entities.create_entity(resource)
         ent:get_component('zulser:conveyor'):place_entity(resource)
         radiant.entities.set_player_id(resource, microworld:get_local_player_id())
      end)
   end
   return ent
end

local function poof()
   return microworld:place_entity('stonehearth:resources:wood:oak_log', math.random(-30, 30), math.random(-30, 30), { full_size = false, owner = microworld:get_local_player_id() })
end

local stockpile

function World:start()
   microworld:create_world(64)
   for i = 1, 10 do
      microworld:place_citizen(math.sin(i*math.pi/5)*5, math.cos(i*math.pi/5)*5)
   end
   
   local owner = microworld:get_local_player_id()
   
   microworld:place_entity_cluster('zulser:machinery:conveyor_belt:wood', -4, -4, 3, 3)
   microworld:place_entity_cluster('zulser:machinery:conveyor_belt:wood:mini', 1, 1, 3, 3)
   
   microworld:create_terrain({ base = Point3(0, 0, 64), dimension = Point3(64, 15, 64) }, 'rock_layer_1')
   microworld:create_terrain({ base = Point3(0, 15, 64), dimension = Point3(64, 5, 32) }, 'rock_layer_2')
   
   for i = -28, -8, 4 do
      create_conveyor(0, i, 0, nil, 'stone')
      create_conveyor(0, -i, 180)
      create_conveyor(i, 0, 90)
   end
   
   create_conveyor(0, -5, 0, nil, 'stone:mini')
   create_conveyor(0, 5, 180, nil, 'wood:mini')
   create_conveyor(-5, 0, 90, nil, 'wood:mini')
   
   stockpile = microworld:place_stockpile(-4, -4, 8, 8)
   
   for i = 1, 40 do
      poof()
   end
end

return World