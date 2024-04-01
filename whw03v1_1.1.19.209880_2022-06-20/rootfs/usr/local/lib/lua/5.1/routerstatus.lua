local _M = {} -- create the module

-- The router heartbeat cycle time, in seconds
_M.ROUTER_HEARTBEAT_CYCLE_SECS = 60


function _M.getHeartbeatInterval(sc)
    sc:readlock()

    -- Convert the returned router heartbeat interval to seconds
    return sc:get_router_heartbeat_interval() * _M.ROUTER_HEARTBEAT_CYCLE_SECS
end

function _M.setHeartbeatInterval(sc, input)
    local interval = input.heartbeatInterval
    sc:writelock()

    if (interval < 0) then
        return 'ErrorInvalidHeartbeatInterval'
    end
    -- Convert the input interval, in seconds, to the router heartbeat interval
    interval = math.floor(interval / _M.ROUTER_HEARTBEAT_CYCLE_SECS)

    sc:set_router_heartbeat_interval(interval)
end


return _M -- return the module
