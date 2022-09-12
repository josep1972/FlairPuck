local Driver = require('st.driver')
local caps = require('st.capabilities')
local log = require('log')

-- local imports
local discovery  = require('discovery')
local lifecycles = require('lifecycles')
local commands   = require('commands')

--------------------
-- Driver definition
local driver =
  Driver(
    'Flair-Puck-Driver',
    {
      discovery          = discovery.handle_discovery,
      lifecycle_handlers = lifecycles,
      supported_capabilities = {
        caps.temperatureMeasurement,
        caps.relativeHumidityMeasurement,
        caps.thermostatCoolingSetpoint,
        caps.thermostatHeatingSetpoint,
        caps.thermostatMode,
        caps.battery,
        caps.refresh
      },
      capability_handlers = {
        -- Setpoints
        [caps.thermostatCoolingSetpoint.ID] = {
           [caps.thermostatCoolingSetpoint.commands.setCoolingSetpoint.NAME]  = commands.setThermostatSetpoint
        },
        [caps.thermostatHeatingSetpoint.ID] = {
           [caps.thermostatHeatingSetpoint.commands.setHeatingSetpoint.NAME]  = commands.setThermostatSetpoint
        },
        -- Mode
        [caps.thermostatMode.ID] = {
           [caps.thermostatMode.commands.setThermostatMode.NAME]  = commands.setThermostatMode
        },
        
        -- Refresh command handler
        [caps.refresh.ID] = {
           [caps.refresh.commands.refresh.NAME] = commands.refresh
        }
      }
    }
  )

--------------------
-- Initialize Driver
driver:run()
