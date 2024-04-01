--- class.
-- @copyright Copyright (c) 2019, Belkin Inc. All rights reserved.


--- Basic class constructor w/ inheritance.
-- @param members The members inherited.
-- @return The metatable for the class.
function class( members )
    local members = members or {}
    
    local mt = {
        __metatable = members;
        __index     = members;
    }
    
    local function new( _, init )
        -- setmetatable returns its first argument
        return setmetatable( init or {}, mt )
    end
    
    local function copy( obj, ... )
        local new_obj = obj:new( unpack(arg) )
        
        for n,v in pairs( obj ) do
            new_obj[n] = v
        end
        
        return new_obj
    end
    
    members.new  = members.new or new
    members.copy = members.copy or copy
    
    return mt
end

return class