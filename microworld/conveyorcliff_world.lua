local World = class()
local Point3 = _radiant.csg.Point3

local ci = 1
local function create_conveyor(x, z, rot, resource, mini)
   local ent = microworld:place_entity(('zulser:machinery:conveyor_belt:wood' .. (mini and ':mini' or '')), x, z, { full_size = true, owner = microworld:get_local_player_id() })
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

local function create_conveyor_y(x, y, z, ...)
  local conv = create_conveyor(x, z, ...)
  radiant.entities.move_to(conv, Point3(x, y, z))
  return conv
end

local function poof()
   return microworld:place_entity('stonehearth:resources:wood:oak_log', math.random(-30, 30), math.random(-30, 30), { full_size = false, owner = microworld:get_local_player_id() })
end

function World:start()
   microworld:create_world(64)
   for i = 1, 10 do
      microworld:place_citizen(math.sin(i*math.pi/5)*5, math.cos(i*math.pi/5)*5 - 20)
   end
   
   microworld:create_terrain({ base = Point3(16, 10, 16), dimension = Point3(32, 1, 32) }, 'rock_layer_1')
   microworld:create_terrain({ base = Point3(16, 11, 17), dimension = Point3(32, 1, 30) }, 'rock_layer_2')
   microworld:create_terrain({ base = Point3(16, 12, 18), dimension = Point3(32, 1, 28) }, 'rock_layer_3')
   microworld:create_terrain({ base = Point3(16, 13, 19), dimension = Point3(32, 1, 26) }, 'rock_layer_4')
   
   local owner = microworld:get_local_player_id()

   microworld:place_stockpile(-4, -24, 8, 8)
   microworld:place_entity_cluster('zulser:machinery:conveyor_belt:wood', -4, -24, 3, 3, { owner = owner })
   microworld:place_entity_cluster('zulser:machinery:conveyor_belt:wood:mini', -4, -19, 3, 3, { owner = owner })
end

return World