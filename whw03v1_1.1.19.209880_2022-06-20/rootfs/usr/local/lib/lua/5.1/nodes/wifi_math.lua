-- © 2018 Belkin International, Inc. and/or its affiliates. All rights reserved.
module( ..., package.seeall )

--! Convert an RCPI value to RSSI.
--! RCPI is "Received Channel Power Indicator"
--! See specification 802.11k, section 15.4.8.5 for details
--! @param rcpi An integer number
--! @return A float RSSI
function rcpi_to_rssi( rcpi )
   local result = 0.0

   rcpi = tonumber( rcpi )
   if type( rcpi ) ~= 'nil' then
      if rcpi <= 0.0 then
         result = -110.0
      elseif rcpi >= 220.0 then
         result = 0.0
      else
         result = rcpi / 2.0 - 110.0
      end
   end

   return result
end


--! Convert an RSSI value to RCPI.
--! RSSI is "Received signal strength indication" and is usually measured in dBm
--! See specification 802.11k, section 15.4.8.5 for details
--! @param rssi A floating point number
--! @return An integer RCPI
function rssi_to_rcpi( rssi )
   local result = 0.0

   rssi = tonumber( rssi )
   if type( rssi ) ~= 'nil' then
      if rssi >= 0 then
         result = 220
      elseif rssi <= -110.0 then
         result = 0
      else
         result = (rssi + 110.0) * 2.0
      end
   end

   return result
end
