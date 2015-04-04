-- Pretty straight-forward copy of the original stonehearth:carry_block,
-- with some minor modifications to make it work for machinery.
local Point3 = _radiant.csg.Point3
local TraceCategories = _radiant.dm.TraceCategories
local log = radiant.log.create_logger 'carry_block'
local CarryBlock = class()

function CarryBlock:initialize(entity, json)
  self._sv = self.__saved_variables:get_data()
  self._entity = entity

  if self._sv._carried_item then
    self:_create_carried_item_trace()
    
    radiant.events.listen_once(radiant, 'radiant:game_loaded', function()
      -- This might look odd, but we have to make sure that this function is called AFTER the lease component was loaded on the entity.
      -- Which we kind of can't do earlier, because there's a chance it's done *after* this function here (first layer) was executed.
      radiant.events.listen_once(radiant, 'radiant:game_loaded', function()
        assert(stonehearth.ai:acquire_ai_lease(self:get_carrying(), self._entity), 'cannot re-acquire lease!')
      end)
    end)
  end
end

function CarryBlock:get_carrying()
  if self._sv._carried_item and self._sv._carried_item:is_valid() then
    return self._sv._carried_item
  end

  return nil
end

function CarryBlock:is_carrying()
  return self:get_carrying() ~= nil
end

function CarryBlock:set_carrying(new_item)
  if not new_item or not new_item:is_valid() then
    log:info('%s set_carrying to nil or invalid item', self._entity)
    self:_remove_carrying()
    return
  end

  if new_item == self._sv._carried_item then
    return
  end

  if self._sv._carried_item then
    self:_destroy_carried_item_trace()
  end

  self._sv._carried_item = new_item
  self.__saved_variables:mark_changed()
  log:info('%s adding %s to carry bone', self._entity, new_item)
  self._entity:add_component 'entity_container':add_child_to_bone(new_item, 'carry')
  radiant.entities.move_to(new_item, Point3.zero)
  
  -- Adjust our ownership to that of the entity
  radiant.entities.set_player_id(self._entity, new_item)
  
  -- Create an AI lease
  assert(stonehearth.ai:acquire_ai_lease(new_item, self._entity), 'cannot acquire AI lease!')
  
  self:_create_carried_item_trace()
end

function CarryBlock:_remove_carrying()
  if self._sv._carried_item then
    self:_destroy_carried_item_trace()
    if self._sv._carried_item:is_valid() then
      log:info('%s removing %s from carry bone', self._entity, self._sv._carried_item)
      self._entity:add_component 'entity_container':remove_child(self._sv._carried_item:get_id())
    end

    -- Release the lease (and the hounds, if necessary)
    stonehearth.ai:release_ai_lease(self._sv.carried_item, self._entity)
    
    self._sv._carried_item = nil
    self.__saved_variables:mark_changed()
  end
end

function CarryBlock:_create_carried_item_trace()
  self._carried_item_trace = self._sv._carried_item:trace_object 'trace carried item':on_destroyed(function()
      self:_remove_carrying()
    end)
  local mob = self._sv._carried_item:get_component 'mob'

  if mob then
    self._mob_parent_trace = mob:trace_parent('trace carried item', TraceCategories.SYNC_TRACE):on_changed(function(parent)
        if parent ~= self._entity then
          self:_remove_carrying()
        end
      end)
  end
end

function CarryBlock:_destroy_carried_item_trace()
  if self._carried_item_trace then
    self._carried_item_trace:destroy()
    self._carried_item_trace = nil
  end

  if self._mob_parent_trace then
    self._mob_parent_trace:destroy()
    self._mob_parent_trace = nil
  end
end

function CarryBlock:destroy()
  self:_destroy_carried_item_trace()
end

return CarryBlock
