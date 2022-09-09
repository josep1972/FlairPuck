local caps   = require('st.capabilities')
local utils  = require('st.utils')
local base64  = require('st.base64')
local neturl = require('net.url')
local log    = require('log')
local json   = require('dkjson')
local cosock = require "cosock"
local http   = cosock.asyncify "socket.http"
local ltn12  = require('ltn12')
local xml2lua = require("xml2lua")
local xml_handler = require "xmlhandler.tree"

local command_handler = {}

------------------
-- Refresh command
function command_handler.refresh(_, device)
   command_handler.getStatus(device)
end

-----------------
-- Switch command
function command_handler.on_off(_, device, command)
  
   local level = device:get_field("level")
   
   -- fan low default
   if level == nil then
      level = 1
      device:set_field("level", level)
   end
   
   log.debug("On Off")
   local on_off = command.command
   if on_off == 'off' then
      device:emit_event(caps.switch.switch.off())
      command_handler.sendCmd(device,"13",0)  
   else 
      device:emit_event(caps.switch.switch.on())   
      command_handler.sendCmd(device,"11",level)  
   end
end

-----------------------
-- Switch level command
function command_handler.set_level(_, device, command)
   local value = command.args.level
  
   log.debug("Level: "..value)

   device:emit_event(caps.switchLevel.level(value))  
   if value == 0 then
      device:emit_event(caps.switch.switch.off())
      command_handler.sendCmd(device,"11",0)
   else
      device:emit_event(caps.switch.switch.on())            
   end
  
   if value > 0 and value <= 33 then
      device:set_field("level", 1)
      command_handler.sendCmd(device,"11",1)
   end 
   if value > 33 and value <= 67 then
      device:set_field("level", 2)
      command_handler.sendCmd(device,"11",2)
   end
   if value > 67 then
      device:set_field("level", 3)
      command_handler.sendCmd(device,"11",3)
   end
end

------------------------
-- Get Status
function command_handler.getStatus(device)

   log.debug("Get Status")

   local response = {}
   local cmd  = "/sx.xml?"..device.preferences.deviceId.."=1903"
   local auth = device.preferences.hubUsername..':'..device.preferences.hubPassword
   local authEncoded = base64.encode(auth)
   local host = device.preferences.hubUrl..':'..device.preferences.hubPort
   --local url = host..cmd
   local url = "http://"..host..cmd
   
   --log.debug("URL: "..url)
   --log.debug("Auth: "..auth)
   --log.debug("Auth2: "..authEncoded)
   
   local _, code = http.request({
      url=url,
      method='GET',
      headers = {
         ['Authorization'] = 'Basic '..authEncoded
      },
      sink=ltn12.sink.table(response)
   })
   
   -- TODO: set the status correctly 
   -- log.debug("CODE: "..code)
   
   if code == 200 then
      log.debug("200: Get Status")
      
      response = table.concat(response)
      local value = string.match(response,'D="%x%x%x%x%x%x%x%x%x%x(%x%x)"')
      --log.debug("Response: "..response)
      -- log.debug("Value: "..value)
     
      if value == nil then
         value = "00"
      end

      if value == "00" then
         device:emit_event(caps.switch.switch.off())
      else
         device:emit_event(caps.switch.switch.on())      
      end 
      
      if value == "55" then
         device:set_field("level", 1)
         device:emit_event(caps.switchLevel.level(33))
      end
      if value == "AA" then
         device:set_field("level", 2)
         device:emit_event(caps.switchLevel.level(67))
      end
      if value == "FF" then
         device:set_field("level", 3)
         device:emit_event(caps.switchLevel.level(100))
      end      
   end
   
end

function command_handler.sendCmd(device,num,level)
   log.debug("Send Cmd")
   log.debug("Level: "..level) 

   -- off
   local speed = "0002000000000000000000000000ED"
   
   -- low
   if level == 1 then
      speed = "55020000000000000000000000009A"
   end
   
   -- mid
   if level == 2 then
      speed = "AA0200000000000000000000000045"
   end
   
   -- high
   if level == 3 then
      speed = "FF02000000000000000000000000F0"
   end

   local response = {}
   local cmd  = "/3?0262"..device.preferences.deviceId.."1F"..num..speed.."=I=3"
   local auth = device.preferences.hubUsername..':'..device.preferences.hubPassword
   local authEncoded = base64.encode(auth)
   local host = device.preferences.hubUrl..':'..device.preferences.hubPort
   local url = "http://"..host..cmd
   
   --log.debug("URL: "..url)
   --log.debug("Auth: "..auth)
   --log.debug("Auth2: "..authEncoded)
  
   local _, code = http.request({
      url=url,
      method='GET',
      headers = {
         ['Authorization'] = 'Basic '..authEncoded
      },
      sink=ltn12.sink.table(response)
   })
   
   -- log.debug("CODE: "..code)
   
   if code == 200 then
      log.debug("200: Send Cmd")
      -- response = table.concat(response)
      -- log.debug("Response: "..response)
      device.thread:call_with_delay(5,
         function() 
            command_handler.getStatus(device)
         end,
         "Get Status"
      )
   end
end

return command_handler
