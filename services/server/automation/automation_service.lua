local Automation = class()

function Automation:initialize()
end

-- Attempts to place `entity` at `pt`. If this location is occupied by a machine, the entity is passed on.
-- Returns true if the entity was placed on a machine, false if it was dropped into the world.
function Automation.place_entity(entity, pt)
  local machine, is_conveyor = Automation.get_machine_at(pt)
  
  -- Is there a machine at that location?
  if machine then
    -- Is it a conveyor?
    if is_conveyor then
      machine:get_component('zulser:conveyor'):place_entity(entity)
      return true
    end
  end
  
  -- No machine found that would handle inventory things.
  radiant.terrain.place_entity_at_exact_location(entity, pt)
  return false
end

local function filter_machines(ent, exception)
  return ent ~= exception and ent:get_component('zulser:conveyor') ~= nil
end

-- Returns the first machine entity occuping `pt`. If `exception` is set, said entity is ignored.
function Automation.get_machine_at(pt, exception)
  local _, machine = next(radiant.terrain.get_entities_at_point(pt, function(ent) return filter_machines(ent, exception) end))
  return machine, machine and machine:get_component('zulser:conveyor')
end

return Automation