local Path = _radiant.sim.Path
local Entity = _radiant.om.Entity
local DropCarryingInStockpile = class()
DropCarryingInStockpile.name = 'drop carrying in stockpile (zulser)'
DropCarryingInStockpile.does = 'stonehearth:drop_carrying_in_stockpile'
DropCarryingInStockpile.args = {
  stockpile = Entity
}

DropCarryingInStockpile.version = 2
DropCarryingInStockpile.priority = 10

function DropCarryingInStockpile:start_thinking(ai, entity, args)
  self._description = 'drop carrying in stockpile (zulser)'
  self._log = ai:get_log()
  local solved = function(path)
    local destination = path:get_destination()
    self:_destroy_pathfinder('solution is' .. tostring(destination))
    
    -- If we have found the stockpile instead; abort
    if not destination:get_component('zulser:conveyor') then
      return
    end
    
    self._conveyor = destination
    self._path = path
    ai:set_think_output()
  end

  self._location = ai.CURRENT.location
  self._stockpile = args.stockpile
  self._ai = ai
  self._log:info('creating bfs pathfinder for %s @ %s', self._description, self._location)
  self._pathfinder = entity:add_component 'stonehearth:pathfinder':find_path_to_entity_type(ai.CURRENT.location, function(ent) return self:_filter_fn(ent) end, self._description, solved)
end

function DropCarryingInStockpile:run(ai, entity, args)
  local carrying = radiant.entities.get_carrying(entity)
  ai:execute('stonehearth:follow_path', { path = self._path })
  
  -- Ugly like hell, but we haven't got a real choice: It's possible that the conveyor has been undeployed.
  -- I am not aware of any real callback for this situation; so we merely check whether its world position is set.
  -- alternatively, we could check for the parent I guess.
  local point = radiant.entities.get_world_grid_location(self._conveyor)
  if not point then
    ai:abort('conveyor is no longer accessible')
  end
  
  -- TODO: This isn't executed sometimes (or at all). Figure out why.
  -- turn_to_face_entity didn't work either.
  ai:execute('stonehearth:turn_to_face_point', { point =  point }) -- Why is this ignored?
  ai:execute('stonehearth:drop_carrying_now')
  stonehearth.ai:release_ai_lease(carrying, entity)
  
  -- TODO: Figure out a better check... For realsies.
  if radiant.entities.get_world_grid_location(self._conveyor) then
    self._conveyor:get_component('zulser:conveyor'):place_entity(carrying)
  end
--~   print('we are so done here')
end

-- Finds either a convenient conveyor or 
function DropCarryingInStockpile:_filter_fn(entity)
  local conveyor = entity:get_component('zulser:conveyor')
  local final_conveyor = conveyor and conveyor:get_destination()
--~   print('filter_fn', entity, conveyor, conveyor and (conveyor:get_destination() or entity), self._stockpile, self._ai.CURRENT.location)
  if entity == self._stockpile then
--~     print(self, 'found stockpile', entity)
    return true
  elseif final_conveyor then
    -- We're doing this weird thing because it's possible that we find a conveyor that was just recently undeployed
    -- In that case, the world location is nil, which causes distance_between to error out. Catch those errors.
    local pos = radiant.entities.get_world_grid_location(entity)
    local final_pos = radiant.entities.get_world_grid_location(final_conveyor)
    
    if not pos or not final_pos then
      return
    end
    
    local final_walk_distance = radiant.entities.distance_between(final_pos, self._stockpile)
    local first_walk_distance = radiant.entities.distance_between(pos, self._stockpile)
    
    -- If this conveyor is heading a different direction, nope it.
    if final_walk_distance > first_walk_distance then
      return
    end
    
      -- TODO: Think about config'ing these values.
    if pos and radiant.entities.distance_between(pos, final_pos)*0.5 + final_walk_distance < radiant.entities.distance_between(self._ai.CURRENT.location, self._stockpile) then
      return true
    end
  end
end

function DropCarryingInStockpile:stop_thinking(ai, entity, args)
  self:_destroy_pathfinder 'stop_thinking'
end

function DropCarryingInStockpile:_destroy_pathfinder(reason)
  if self._pathfinder then
    local count = self._pathfinder:destroy()
    self._pathfinder = nil
    self._log:info('destroying bfs pathfinder for %s @ %s (%d remaining, reason:%s)', self._description, self._location, count, reason)
  end
end

return DropCarryingInStockpile
