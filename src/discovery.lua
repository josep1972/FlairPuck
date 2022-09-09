local log = require('log')
--local config = require('config')
-- XML modules
--local xml2lua = require "xml2lua"
--local xml_handler = require "xmlhandler.tree"

local discovery = {}

function discovery.handle_discovery(driver, _should_continue)
  log.info("Starting Flair Puck Discovery")
  local id = math.floor(math.random(1000))

  local metadata = {
    type = "LAN",
    device_network_id = "flair"..id,
    label = "Flair Puck",
    profile = "flaiPuck.v1",
    manufacturer = "josep",
    model = "v1",
    vendor_provided_label = nil
  }

  driver:try_create_device(metadata)
end

return discovery