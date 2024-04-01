--
-- 2017 Belkin International, Inc. and/or its affiliates. All rights reserved.
--
-- $Author$
-- $DateTime$
-- $Id$
--


local function GetSoftSKUSettings(ctx, input)
    local sc = ctx:sysctx()
    sc:readlock()

    return 'OK', {
        modelNumber = sc:get_modelnumber()
    }
end

local function SetSoftSKUSettings(ctx, input)
    local sc = ctx:sysctx()

    if #input.modelNumber == 0 then
        return 'ErrorInvalidModelNumber'
    end
    sc:writelock()
    sc:set_modelnumber(input.modelNumber)

    return 'OK'
end

local function SetSoftSKUByProduct(ctx, input)
    local sc = ctx:sysctx()

    sc:writelock()
    sc:set_soft_sku_by_product(input.productId)

    return 'OK'
end

return require('libhdklua').loadmodule('jnap_product'), {
    ['http://linksys.com/jnap/product/GetSoftSKUSettings'] = GetSoftSKUSettings,
    ['http://linksys.com/jnap/product/SetSoftSKUSettings'] = SetSoftSKUSettings,
    ['http://linksys.com/jnap/product/SetSoftSKUByProduct'] = SetSoftSKUByProduct
}
