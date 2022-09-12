local caps   = require('st.capabilities')
local utils  = require('st.utils')
local base64  = require('st.base64')
local neturl = require('net.url')
local log    = require('log')
local json   = require('dkjson')
local cosock = require "cosock"
local http   = cosock.asyncify "socket.http"
--local https   = cosock.asyncify "ssl.https"
--local https   = require("ssl.https")

local ltn12  = require('ltn12')
local xml2lua = require("xml2lua")
local xml_handler = require "xmlhandler.tree"

local command_handler = {}

------------------
-- Init
function command_handler.init(_, device)
   
   -- set up thermostat
   device:emit_event(caps.thermostatMode.supportedThermostatModes({"cool","heat"}) )
   
   -- Set initial display values
   command_handler.refresh(nil,device)
   
end

------------------
-- Refresh command
function command_handler.refresh(_, device)
   command_handler.getStatus(device)
end

------------------------
-- Get Status
function command_handler.getStatus(device)

   log.debug("Get Status")

   -- Hopefully the token can be used more than once?
   local token = command_handler.getToken(device)
   
   if token ~= "0" then
      command_handler.puckStatus(device,token)
      command_handler.thermostatSetpointStatus(device,token)
      command_handler.thermostatModeStatus(device,token)
   else 
      log.debug("Bad Token: "..token)
   end
   
end

-------------------
-- Set Setpoint
function command_handler.setThermostatSetpoint(_, device, command)

   local roomId = device:get_field("roomId")
   local setpoint = command.args.setpoint
   
   -- Convert to celcius
   local setpointC = (setpoint - 32 ) * 5 / 9 
   
   log.debug("Set Thermostat Setpoint: "..setpoint)
      
   if roomId ~= nil then
      local token = command_handler.getToken(device)
      local apiEndpoint = device:get_field("apiEndpoint")      
      local url = apiEndpoint .. "/flairSetThermostatSetpoint.php?token="..token.."&roomId="..roomId.."&setpoint="..setpointC

      local response = {}
      local _, code = http.request({
         url=url,
         sink=ltn12.sink.table(response)
      })
      if code == 200 then
      
         log.debug("200: Set Setpoint")
         
         device:emit_event(caps.thermostatCoolingSetpoint.coolingSetpoint({value = setpoint, unit="F"}) )
         device:emit_event(caps.thermostatHeatingSetpoint.heatingSetpoint({value = setpoint, unit="F"}) )
         
         command_handler.thermostatSetpointStatus(device,token)
      end
   else 
      log.debug("Bad Room Id")   
   end

end 

-------------------
-- Set Mode
function command_handler.setThermostatMode(_, device, command)

   local mode = command.args.mode
   log.debug("Set Thermostat Mode: "..mode)
   
   local structureId = device:get_field("structureId")
   if structureId ~= nil then
      local token = command_handler.getToken(device) 
      local apiEndpoint = device:get_field("apiEndpoint") 
      local url = apiEndpoint .. "/flairSetThermostatMode.php?token="..token.."&structureId="..structureId.."&mode="..mode
      local response = {}
      local _, code = http.request({
         url=url,
         sink=ltn12.sink.table(response)
      })
      
      if code == 200 then
         log.debug("200: Set Mode")
      
         -- bug...last bracket missing from ltn12 lib sink
         response = table.concat(response).."}"
         log.debug("Response: "..response)
         
         device:emit_event(caps.thermostatMode.thermostatMode(mode) )
         command_handler.thermostatModeStatus(device,token) 
      end 
   else 
      log.debug("Bad Structure Id")   
   end

end 

-----------------
-- Get Auth Token
function command_handler.getToken(device)
   log.debug("Token Cmd")
   
   local token = "0"
   local response = {}
   --local scope    = "scope=pucks.view+pucks.edit+structures.view+structures.edit"
   --local clientId = "client_id="..device.preferences.clientId
   --local secret   = "client_secret="..device.preferences.secret
   -- local url      = device.preferences.apiEndpoint.."/oauth/token?"
   -- local data     = clientId.."&"..secret.."&"..scope.."&grant_type=client_credentials"
   -- url = url..data
   local apiEndpoint = device:get_field("apiEndpoint")
   local url = apiEndpoint.."/flairToken.php"
   
   log.debug("URL: "..url)
  
   local _, code = http.request({
      url=url,
      sink=ltn12.sink.table(response)
   })
   
   --log.debug("BODY: "..table.concat(body))
   --log.debug("CODE: "..code)
   --log.debug("HEADERS: "..table.concat(headers))
   --log.debug("STATUS: "..status)
   
   -- got the access token
   if code == 200 then
      log.debug("200: Token")
      
      -- bug...last bracket missing from ltn12 lib sink
      response = table.concat(response).."}"
      log.debug("Response: "..response)

      local jsonData = json.decode(response)
      token = jsonData["access_token"]
      
      log.debug("TOKEN: "..token)
   end
   
   return token
end

-------------- 
-- Puck Status
function command_handler.puckStatus(device, token)

   local response = {}
   local puckId = device:get_field("puckId")
   local apiEndpoint = device:get_field("apiEndpoint")
   local url = apiEndpoint .. "/flairPuckStatus.php?token="..token.."&puckId="..puckId
   
   log.debug("URL: "..url)
  
   local _, code = http.request({
      url=url,
      sink=ltn12.sink.table(response)
   })
   
   -- log.debug("CODE: "..code)
   
   if code == 200 then
      log.debug("200: Puck Status")
      
      -- bug...last bracket missing from ltn12 lib sink
      response = table.concat(response).."}"
      log.debug("Response: "..response)
      
      local jsonData = json.decode(response)
      
      -- temperature
      local temperature = jsonData["data"]["attributes"]["current-temperature-c"]
      temperature = 1.8 * temperature + 32.0
      temperature = math.floor(temperature*100)/100      
  
      -- humidity
      local humidity = jsonData["data"]["attributes"]["current-humidity"]
      
      -- battery 
      local battery        = jsonData["data"]["attributes"]["voltage"]
      local batteryPercent = math.floor(battery / 3.3 * 100 + 0.5)
      if batteryPercent > 100 then
         batteryPercent = 100
      end
           
      log.debug("Temperature (F): "..temperature)
      log.debug("Humidity %:      "..humidity)
      log.debug("Battery (V):     "..battery)
      
      device:emit_event(caps.temperatureMeasurement.temperature({value=temperature,unit="F"}) ) 
      device:emit_event(caps.relativeHumidityMeasurement.humidity(humidity) )
      device:emit_event(caps.battery.battery(batteryPercent))
            
   end

end 

------------------
-- Setpoint Status
function command_handler.thermostatSetpointStatus(device, token)

   local response = {}
   local puckId = device:get_field("puckId")
   local apiEndpoint = device:get_field("apiEndpoint")
   local url = apiEndpoint .. "/flairThermostatSetpointStatus.php?token="..token.."&puckId="..puckId
   
   log.debug("URL: "..url)
  
   local _, code = http.request({
      url=url,
      sink=ltn12.sink.table(response)
   })
   
   -- log.debug("CODE: "..code)
   
   -- got the access token
   if code == 200 then
   
      log.debug("200: Setpoint Status")
      
      -- bug...last bracket missing from ltn12 lib sink
      response = table.concat(response).."}"
      log.debug("Response: "..response)
      
      local jsonData = json.decode(response)
      
      -- setpoint
      local setpoint = jsonData["data"]["attributes"]["set-point-c"]
      setpoint = math.floor(1.8 * setpoint + 32.0 + 0.5)

      -- room Id
      local roomId = jsonData["data"]["id"]
      device:set_field("roomId", roomId)
      
      -- structure ID
      local structureId = jsonData["data"]["relationships"]["structure"]["data"]["id"]
      device:set_field("structureId", structureId)
      
      log.debug("Structure Id: "..structureId)
      log.debug("Room Id:      "..roomId)
      log.debug("Setpoint:     "..setpoint)

      device:emit_event(caps.thermostatCoolingSetpoint.coolingSetpoint({value = setpoint, unit="F"}) )
      device:emit_event(caps.thermostatHeatingSetpoint.heatingSetpoint({value = setpoint, unit="F"}) )       
      
   end

end 

--------------------------
-- Thermostat Mode Status
function command_handler.thermostatModeStatus(device, token)

   local response = {}
   local structureId = device:get_field("structureId")
   local puckId      = device:get_field("puckId")
   local apiEndpoint = device:get_field("apiEndpoint")
   
   local url = apiEndpoint .. "/flairThermostatModeStatus.php?token="..token.."&puckId="..puckId
   
   log.debug("URL: "..url)
  
   local _, code = http.request({
      url=url,
      sink=ltn12.sink.table(response)
   })
   
   -- log.debug("CODE: "..code)
   
   -- got the access token
   if code == 200 then
      log.debug("200: Mode Status")
      
      -- bug...last bracket missing from ltn12 lib sink
      response = table.concat(response).."}"
      log.debug("Response: "..response)
      
      local jsonData = json.decode(response)
      
      -- setpoint
      local mode = jsonData["data"]["attributes"]["structure-heat-cool-mode"]

      log.debug("Thermostat Mode: "..mode)
      device:emit_event(caps.thermostatMode.thermostatMode(mode) )
  
   end

end 

return command_handler
