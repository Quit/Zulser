local World = class()
local Point3 = _radiant.csg.Point3

local ci = 1
local function create_conveyor(x, z, rot, resource)
   local ent = microworld:place_entity('zulser:machinery:conveyor_belt', x, z, { full_size = true, owner = microworld:get_local_player_id() })
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
   
   microworld:place_entity_cluster('zulser:machinery:conveyor_belt', -4, -4, 3, 3)
   microworld:create_terrain({ base = Point3(0, 0, 64), dimension = Point3(64, 18, 64) }, 'rock_layer_6')

   for i = -28, -8, 4 do
      create_conveyor(0, i, 0)
      create_conveyor(0, -i, 180)
      create_conveyor(i, 0, 90)
   end
   
   stockpile = microworld:place_stockpile(-4, -4, 8, 8)
   
   for i = 1, 40 do
      poof()
   end
end

return World