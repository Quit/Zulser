local Automation = class()
local Point3 = _radiant.csg.Point3
local Cube3 = _radiant.csg.Cube3

local log
function Automation:initialize()
  log = radiant.log.create_logger('automation_service')
end

-- Attempts to place `entity` at `pt`. If this location is occupied by a machine, the entity is passed on.
-- Returns true if the entity was placed on a machine, false if it was dropped into the world.
function Automation.place_entity(entity, pt)
  local machine, is_conveyor = Automation.get_machine_at(pt)
  
  -- Is there a machine at that location?
  if machine then
    -- Is it a conveyor?
    if is_conveyor then
      log:spam('attempt to place %s at %s resulted in finding the conveyor %s', entity, pt, machine)
      machine:get_component('zulser:conveyor'):place_entity(entity)
      return true
    end
  end
  
  log:spam('could not find machine for %s at %s; placing it on terrain', entity, pt)
  
  -- No machine found that would handle inventory things.
  radiant.terrain.place_entity(entity, pt)
  entity:get_component('mob'):move_to(pt)
  return false
end

local function filter_machines(ent, exception)
  return ent ~= exception and ent:get_component('zulser:conveyor') ~= nil
end

-- Returns the first machine entity occuping `pt`. If `exception` is set, said entity is ignored.
function Automation.get_machine_at(pt, exception)
  local cube = Cube3(pt - Point3(0, 1, 0), pt + Point3(1, 2, 1))
  local _, machine = next(radiant.terrain.get_entities_in_cube(cube, function(ent) return filter_machines(ent, exception) end))
  return machine, machine and machine:get_component('zulser:conveyor')
end

return Automation