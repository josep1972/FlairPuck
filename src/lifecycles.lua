local command_handler = require('commands')
local log             = require('log')

local lifecycle_handler = {}
function lifecycle_handler.init(driver, device)

   log.info("[" .. device.id .. "] Initializing Flair Puck")

  -- Refresh every 2 minutes schedule
  device.thread:call_on_schedule(
    30,
    function ()
      return command_handler.refresh(nil, device)
    end,
    'Refresh schedule'
   )
end

function lifecycle_handler.added(driver, device)
  command_handler.refresh(nil, device)
  log.info("[" .. device.id .. "] Flair Puck")
end

function lifecycle_handler.removed(_, device)
  log.info("[" .. device.id .. "] Removing Flair Puck")
end

function lifecycle_handler.device_info_changed(driver, device, event, args)
  log.info("[" .. device.id .. "] Updating Settings to Flair Puck")
  command_handler.refresh(nil, device)
end

return lifecycle_handler
