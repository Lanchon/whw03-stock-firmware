window.RAINIER=window.RAINIER||{};RAINIER.applets=RAINIER.applets||{};RAINIER.applets.connectivity=RAINIER.applets.connectivity||(function(){var e={destinationTab:null,doTabChange:false,doClose:false,doSave:false,checks:{basic:{}}},b={onClose:function(){RAINIER.ui.MainMenu.closeApplet()},onSaveComplete:function(){RAINIER.ui.hideWaiting();if(e.doSave){if(e.doClose){b.onClose()}else{if(e.doTabChange){e.destinationTab.click()}}}}};e.rules={ssid:{validationType:"utf8LengthTooLong",maxLen:32,whiteSpace:false,isRequired:true},password:{minLen:8,maxLen:64,validCharSet:"ascii",whiteSpace:false,isRequired:true}};function d(h){switch(h){case"PPPoE":case"PPPoA":return 1492;case"PPTP":case"L2TP":return 1460;case"DHCP":case"Static":case"2684Bridged":case"2684Routed":case"IPoA":return 1500;default:return -1}}function c(l,k,i,h){var j=RAINIER.ui.validation.tests.isIPAddress(k,l.val()==="Internet");if(j){j=RAINIER.util.parseIPAddress(k)!==RAINIER.util.parseIPAddress(i)}if(j){if(l.val()=="LAN"){return RAINIER.ui.validation.tests.isHostValidForGivenRouterIPAddressAndSubnetMask(k,i,h)}else{if(l.val()=="Internet"){return !RAINIER.ui.validation.tests.isHostValidForGivenRouterIPAddressAndSubnetMask(k,i,h)}else{j=false}}}return j}function a(i){var h=i.find("div.mac-input > input");h.val("00");h.attr("defaultValue","00")}function g(h){h.find("div.ip-input > input").val(0)}function f(){e.destinationTab=null;e.doTabChange=false;e.doClose=false;e.doSave=false}return{sharedOptions:e,sharedEvents:b,getMaxMTUValue:d,isStaticRouteGatewayValid:c,initializeDefaultMacAddressInputValues:a,initializeGeneralInputValues:g,resetSharedOptions:f}}());