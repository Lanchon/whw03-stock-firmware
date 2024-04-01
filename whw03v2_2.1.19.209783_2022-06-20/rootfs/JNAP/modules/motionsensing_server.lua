--
-- 2019 Belkin International, Inc. and/or its affiliates. All rights reserved.
--
-- $Author: hsulliva $
-- $DateTime: 2021/06/02 11:24:20 $
-- $Id: //depot-irv/olympus/nodes_dev_tb/lego_overlay/proprietary/jnap/modules/motionsensing/motionsensing_server.lua#5 $
--

local function GetMotionSensingSettings(ctx)
    local sc = ctx:sysctx()
    local ms = require('motionsensing')

    return 'OK', ms.getMotionSensingSettings(sc)
end

local function SetMotionSensingSettings(ctx, input)
    local sc = ctx:sysctx()
    local ms = require('motionsensing')

    return 'OK', ms.setMotionSensingSettings(sc, input.isMotionSensingEnabled)
end

local function GetMotionSensingCapableSlaves(ctx)
    local sc = ctx:sysctx()
    local ms = require('motionsensing')

    return 'OK', ms.getMotionSensingCapableSlaves(sc, 1)
end

local function GetMotionSensingCapableSlaves2(ctx)
    local sc = ctx:sysctx()
    local ms = require('motionsensing')

    return 'OK', ms.getMotionSensingCapableSlaves(sc, 2)
end

local function StartMotionSensingBotScanning(ctx)
    local sc = ctx:sysctx()
    local ms = require('motionsensing')

    local err = ms.startBotScanning(sc)
    return err or 'OK'
end

local function GetBotScanningStatus(ctx)
    local sc = ctx:sysctx()
    local ms = require('motionsensing')

    return 'OK', ms.getBotScanningStatus(sc)
end

local function AddMotionSensingBots(ctx, input)
    local sc = ctx:sysctx()
    local ms = require('motionsensing')

    local err, output =  ms.addMotionSensingBots(sc, input.deviceIDs)
    return err or 'OK', output
end

local function RemoveMotionSensingBots(ctx, input)
    local sc = ctx:sysctx()
    local ms = require('motionsensing')

    local err, output =  ms.removeMotionSensingBots(sc, input.deviceIDs)
    return err or 'OK', output
end

local function GetAvailableMotionSensingBots(ctx)
    local sc = ctx:sysctx()
    local ms = require('motionsensing')

    local err, output = ms.getAvailableMotionSensingBots(sc)
    return err or 'OK', output
end

local function GetActiveMotionSensingBots(ctx)
    local sc = ctx:sysctx()
    local ms = require('motionsensing')

    local err, output = ms.getActiveMotionSensingBots(sc)
    return err or 'OK', output
end

return require('libhdklua').loadmodule('jnap_motionsensing'), {
    ['http://linksys.com/jnap/motionsensing/GetMotionSensingSettings'] = GetMotionSensingSettings,
    ['http://linksys.com/jnap/motionsensing/SetMotionSensingSettings'] = SetMotionSensingSettings,
    ['http://linksys.com/jnap/motionsensing/GetMotionSensingCapableSlaves'] = GetMotionSensingCapableSlaves,
    ['http://linksys.com/jnap/motionsensing/GetMotionSensingCapableSlaves2'] = GetMotionSensingCapableSlaves2,
    ['http://linksys.com/jnap/motionsensing/StartMotionSensingBotScanning'] = StartMotionSensingBotScanning,
    ['http://linksys.com/jnap/motionsensing/GetBotScanningStatus'] = GetBotScanningStatus,
    ['http://linksys.com/jnap/motionsensing/AddMotionSensingBots'] = AddMotionSensingBots,
    ['http://linksys.com/jnap/motionsensing/RemoveMotionSensingBots'] = RemoveMotionSensingBots,
    ['http://linksys.com/jnap/motionsensing/GetAvailableMotionSensingBots'] = GetAvailableMotionSensingBots,
    ['http://linksys.com/jnap/motionsensing/GetActiveMotionSensingBots'] = GetActiveMotionSensingBots
}
