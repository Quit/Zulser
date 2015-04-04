local Point3 = _radiant.csg.Point3
local Cube3 = _radiant.csg.Cube3
local Point_Zero = Point3(0, 0, 0)

local Conveyor = class()

function Conveyor:initialize(entity, json)
  self._sv = self.__saved_variables:get_data()
  
  if not self._sv.entities then
    self._sv.entities = {}
  end
  
  self._entity = entity
  -- At which point the entity is dropped down or passed onto the next conveyor; relative to the middle. A positive number.
  self.boundary = assert(json.boundary, 'missing json data: boundary')
  -- units/second that we move items forwards.
  self.speed = assert(json.belt_speed, 'missing json data: belt_speed')
  -- Distance from the center that new items start off; technically just used for the height.
  self.entity_offset = Point3(0, assert(json.belt_height, 'missing json data: belt_height'), 0)
  -- To keep track of movement... usually, this means we've been deployed/undeployed.
  self._location_trace = radiant.entities.trace_grid_location(entity, 'adjust conveyor'):on_changed(function(...) self:_on_position_change(...) end)
end

function Conveyor:destroy()
  self:_uninstall_loop()
  
  if self._chain_update_listener then
    self._chain_update_listener:destroy()
  end
  
  if self._run_effect then
    self._run_effect:stop()
    self._run_effect = nil
  end
end

-- Sets the effect; either "on" or "off" right now.
function Conveyor:_set_effect(name)
  if self._run_effect then
    self._run_effect:stop()
    self._run_effect = nil
  end
  
  -- Effects that aren't off are looped. Technically, the JSON defines that
  -- the effect is looped, but it seems like the cleanup is a bit too eager.
  if name ~= 'off' then
    self._run_effect = radiant.effects.run_effect(self._entity, name)
    self._run_effect:set_cleanup_on_finish(false)
  end
end

-- Deals with loops by plopping back into an iconic form.
function Conveyor:_handle_loops()
  -- No way.
  local iconic = self._entity:get_component('stonehearth:entity_forms'):get_iconic_entity()
  local location = radiant.entities.get_world_grid_location(self._entity)
  local parent = radiant.entities.get_parent(self._entity)

  if parent then
    radiant.entities.remove_child(parent, self._entity)
    radiant.entities.move_to(self._entity, Point3.zero)
  end

  self._entity:get_component('mob'):set_ignore_gravity(false)
  radiant.terrain.place_entity(iconic, location)

  -- Don't care for that anymore. Especially because it would, essentially, come back at us. Maybe.
  if self._chain_update_listener then
    self._chain_update_listener:destroy()
  end

  self:_uninstall_loop()
  
  -- Create a new update, but this time on us. This will inform the chain that we're gone.
  radiant.events.trigger(self._entity, 'zulser:conveyor_chain_update', self._entity)
end

-- This callback is a bit... bad-ish
-- It's called whenever something in a chain breaks or requires an update.
-- This is a semi-recursive callback that bubbles back all the way to the first conveyors in the chain.
function Conveyor:_on_chain_update(origin)
  -- If we have no direction (yet), nope out.
  if not self.direction then
    return
  end
  
  -- Do we have an entity in front of us?
  local next_pos = radiant.entities.get_world_location(self._entity) + self.direction * self.boundary
  local _, conveyor = next(radiant.terrain.get_entities_at_point(next_pos, function(ent) return ent ~= self._entity and ent:get_component('zulser:conveyor') ~= nil end))
  
  -- If we do have a conveyor
  if conveyor ~= nil then
    -- If it's a different conveyor than our current next
    if conveyor ~= self._next then
      -- destroy the current listener, if any
      if self._chain_update_listener then
        self._chain_update_listener:destroy()
      end
      
      -- Set up a new listener at that other location
      self._chain_update_listener = radiant.events.listen(conveyor, 'zulser:conveyor_chain_update', self, self._on_chain_update)
    end
    
    -- Update our contact information accordingly
    self._next, self._destination = conveyor, conveyor:get_component('zulser:conveyor')._destination or conveyor
    
    -- If our destination would be our entity, congratulations, we've got a loop.
    if self._destination == self._entity then
      -- Resolve the loop.
      (origin or self._entity):get_component('zulser:conveyor'):_handle_loops()
      -- Not strictly necessary, because _handle_loop will already resolve the loop... but better safe than sorry?
      self._next, self._destination = nil, nil
      return
    end
  -- Whatever we have in front of us is *not* a conveyor.
  else
    self._next, self._destination = nil, nil
  end
  
  -- Trigger it again, but avoid infinite recursion. With the new loop handling, this case shouldn't happen... in theory.
  if self._entity ~= origin then
    radiant.events.trigger(self._entity, 'zulser:conveyor_chain_update', origin or self._entity)
  end
end

-- Adds an entity onto this conveyor.
function Conveyor:place_entity(entity)
  -- Is it already packaged?
  if entity:get_uri() ~= 'zulser:machinery:conveyor:vessel' then
    -- It isn't. Package it with bubblewrap.
    local vessel = radiant.entities.create_entity('zulser:machinery:conveyor:vessel', { owner = radiant.entities.get_player_id(self._entity) })
    radiant.terrain.place_entity(vessel, Point_Zero)
    local pos = radiant.entities.world_to_local(radiant.entities.get_world_location(entity), self._entity)
    vessel:get_component('mob'):move_to(radiant.entities.get_world_grid_location(self._entity) + self.entity_offset + self.direction_abs * pos:dot(self.direction))
    
    -- Tell the AI to ignore this item.
    if not stonehearth.ai:can_acquire_ai_lease(entity, vessel) then
      radiant.entities.destroy_entity(vessel)
      error('cannot acquire lease for entity!')
      return
    end
  
    assert(stonehearth.ai:acquire_ai_lease(entity, vessel), 'cannot acquire AI lease (although check said we could)')
    radiant.entities.add_child(vessel, entity, Point_Zero)
    entity = vessel
  end
  
  -- Insert the entity into the list of our entities.
  table.insert(self._sv.entities, entity)
  self.__saved_variables:mark_changed()
  
  self:_install_loop()
end

-- The final destination of our conveyor chain. If this returns nil, this conveyor is the final destination.
function Conveyor:get_destination()
  return self._destination
end

-- Called whenever our position/rotation changed; used to recalculate neighbors and directions.
-- Due to... unknown reasons, this callback is called AFTER the gameloop/calendar update, which makes
-- a lot of things annoying (as there's one frame where we have no location anymore, but are still looped)
function Conveyor:_on_position_change()
  -- We were taken from the world... for stockpiles, or sugar and giggles.
  if radiant.entities.get_parent(self._entity) == nil then
    -- Inform others that we are of irrelevant now
    radiant.events.trigger(self._entity, 'zulser:conveyor_chain_update', self._entity)
    
    -- Drop entities that we were still transporting
    for _, entity in pairs(self._sv.entities) do
      self:_drop_entity(entity, radiant.entities.get_world_location(entity)) -- TODO: test this. If you read this while looking for the issue of this bug, hi
    end
    
    -- Burn all bridges.
    self._next, self._destination = nil, nil
    self.direction, self.direction_abs = nil, nil
    self._sv.entities = {} -- normally, we remove the entities at the same time. Right now, we assume that we've dropped all off anyway.
    
    self:_uninstall_loop()
    if self._chain_update_listener then
      self._chain_update_listener:destroy()
    end
    
    self.__saved_variables:mark_changed()
  else -- We were just placed, or moved.
    local rot = self._entity:get_component('mob'):get_rotation()
    
    -- I really wish there was a Quaternion.yaw.
    local q0, q1, q2, q3 = rot.w, rot.x, rot.z, rot.y
    
    local deg = math.atan2(2*(q0*q3 + q1*q2), 1-2*(q2*q2 + q3*q3))
    
    self.direction = Point3(math.sin(deg) * self.speed, 0, math.cos(deg) * self.speed)
    self.direction:normalize()
    self.direction_abs = Point3(math.abs(self.direction.x), math.abs(self.direction.y), math.abs(self.direction.z))
    
    -- Update any possible chain.
    local pos = radiant.entities.get_world_location(self._entity)
   
    -- Prioritise us. Trigger the event, but only this time (nil as origin will be replaced)
    self:_on_chain_update(nil)
    
    for _, conveyor in pairs(radiant.terrain.get_entities_in_cube(Cube3(pos - Point3(2, 1, 3), pos + Point3(2, 1, 3)), function(ent) return ent ~= self._entity and ent:get_component('zulser:conveyor') ~= nil end)) do
      conveyor:get_component('zulser:conveyor'):_on_chain_update(self._entity)
    end
  end
end

-- installs the gameloop/starts it and the animation.
function Conveyor:_install_loop()
  if self._loop then
    return
  end
  
  self._last_update = radiant.gamestate.now()
  if #self._sv.entities then
    self._loop = stonehearth.calendar:set_interval(1, function() self:_on_gameloop() end)
    self:_set_effect('on')
  end
end

-- uninstalls the gameloop/stops the animation.
function Conveyor:_uninstall_loop()
  if self._loop then
    self._loop:destroy()
    self._loop = nil
    
    self:_set_effect('off')
  end
end

-- On each gameloop (or rather, calendar tick).
-- Moves the items forward.
function Conveyor:_on_gameloop()
  local now, diff = radiant.gamestate.now()
  diff, self._last_update = (now - self._last_update) / 1000, now
  
  -- Ugly, but currently possible: If the conveyor is undeployed, the gameloop runs one additional time because the callback hasn't fired yet.
  local local_pos = radiant.entities.get_world_grid_location(self._entity)
  if not local_pos then
    return
  end
  
  local dir = self.direction
  
  -- Because dropped-off entities are immediately removed, we're using a while instead of for
  -- (plus, technically, this is kind of faster)
  local i = 1
  while i <= #self._sv.entities do
    local entity = self._sv.entities[i]
    local mob = entity:get_component('mob')
    local new_pos = mob:get_location() + dir * diff
    mob:move_to(new_pos)

    -- If the item would be dropped off
    if (new_pos - local_pos):dot(dir) >= self.boundary then
      -- Remove it from our list of tracked entities
      table.remove(self._sv.entities, i)
      -- and get rid of it enitrely
      self:_drop_entity(entity, new_pos)
    else
      -- Otherwise, it's still being transported - move on to the next entity.
      i = i + 1
    end
  end
  
  -- If there's no entity around anymore, uninstall the loop
  -- (similar to #self._sv.entities, but without the unnecessary counting)
  if not self._sv.entities[1] then
    self:_uninstall_loop()
  end
end

-- Drops an entity; either on the floor or onto the next conveyor
function Conveyor:_drop_entity(vessel, location)
  if self._next then
    -- Pass it on. May the legacy live!
    self._next:get_component('zulser:conveyor'):place_entity(vessel)
  else
    -- Drop the item on the ground.
    local next_pos = (radiant.entities.get_world_location(self._entity) or radiant.entities.get_world_location(self._entity:get_component('stonehearth:entity_forms'):get_iconic_entity())) + self.direction * self.boundary
    radiant.entities.for_all_children(vessel, function(entity)
      if entity and entity:is_valid() then
        radiant.entities.remove_child(vessel, entity)
        stonehearth.ai:release_ai_lease(entity, vessel)
        radiant.terrain.place_entity_at_exact_location(entity, next_pos) -- "exact" is still aligned to the grid. lies EVERYWHERE!
        local mob = entity:get_component('mob')
        -- Gravity Fails
        mob:move_to(location) -- TODO: Check if next_pos + self.entity_offset or location is more convenient
        mob:set_ignore_gravity(false)
      end
    end)
    
    -- Destroy the vessel
    radiant.entities.destroy_entity(vessel)
  end
end

return Conveyor