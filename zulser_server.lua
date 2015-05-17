zulser = {}

-- Shamelessly copied (and adapted) from SH
local function create_service(name)
  local path = string.format('services.server.%s.%s_service', name, name)
  local service = require(path)()
  local saved_variables = zulser._sv[name]

  if not saved_variables then
    saved_variables = radiant.create_datastore()
    zulser._sv[name] = saved_variables
  end

  service.__saved_variables = saved_variables
  service._sv = saved_variables:get_data()
  saved_variables:set_controller(service)
  service:initialize()
  zulser[name] = service
end

radiant.events.listen(zulser, 'radiant:init', function()
  -- Dump the version into our logfile... or something.
  local success, json = pcall(radiant.resources.load_json, 'zulser/smodify.json')
  local version_string
  if success then
    version_string = string.format('%s/%s; release %q based on commit %s (%q) on %s', json.user, json.repository, json.release_name, json.sha, json.release_tag, json.commit_date_utc)
  else
    version_string = 'unknown version, probably git/dev'
  end
  
  radiant.log.write('zulser', 0, 'Using %s', version_string)
  
  zulser._sv = zulser.__saved_variables:get_data()
  create_service('automation')
end)

return zulser