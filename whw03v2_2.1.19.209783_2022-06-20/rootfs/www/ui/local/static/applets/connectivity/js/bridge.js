RAINIER.applets.connectivity.bridge=RAINIER.applets.connectivity.bridge||(function(){var i=RAINIER.ui.buildInputValidBalloon,v=RAINIER.applets.connectivity.sharedOptions,b={},m=null;function k(){if($('#WirelessRepeater select:[name="wan.wirelessModeSettings.security"]').val()==="None"){$("#WirelessRepeater .wireless-password").hide()}else{$("#WirelessRepeater .wireless-password").show()}if($('#WirelessBridge select:[name="wan.wirelessModeSettings.security"]').val()==="None"){$("#WirelessBridge .wireless-password").hide()}else{$("#WirelessBridge .wireless-password").show()}RAINIER.ui.fixIeForm("#ip-v4-fieldset")}function s(y){var x=RAINIER.network.isBehindNode();if(y.wanStatus.supportedWANTypes){var z=y.wanStatus.supportedWANTypes;$("#wanType option").each(function(){var A=$(this).val();if(z.indexOf(A)===-1){$(this).remove()}})}if(!RAINIER.shared.util.areServicesSupported(["/jnap/router/Router3"])||(x&&y.deviceMode.mode==="Master")){$('#wanType option[value="WirelessRepeater"]').remove();$('#wanType option[value="WirelessBridge"]').remove()}if(!RAINIER.shared.util.areServicesSupported(["/jnap/router/Router9"])&&x){$('#wanType option[value="Bridge"]').remove()}if(x){RAINIER.ui.progressBar.build("bridgemode-progress-bar")}}function h(z){var x=[],A=$("<div></div>"),y;if(z.supportedWirelessModeSecurities&&z.supportedWirelessModeSecurities.length>0){x=z.supportedWirelessModeSecurities[0].supportedSecurityTypes}$('select[name="wan.wirelessModeSettings.security"]').children().each(function(B,C){if($.inArray(C.value,x)!==-1){A.append(C)}});$("#WirelessRepeater select").empty();$("#WirelessRepeater select").append(A.children());y=$("#WirelessRepeater").clone();$(y.html()).appendTo("#WirelessBridge");RAINIER.ui.fixCustomControls($("#WirelessBridge"));$('select:[name="wan.wirelessModeSettings.security"]').change(k)}function a(x){var y={};if(x==="WirelessRepeater"){y=RAINIER.binder.fromDom($("#WirelessRepeater"))}else{if(x==="WirelessBridge"){y=RAINIER.binder.fromDom($("#WirelessBridge"))}}y.wan.bridgeSettings={useStaticSettings:false};return y}function c(y){var x='#WirelessRepeater .band input:[value="5GHz"]';x=x.replace("WirelessRepeater",$("#wanType").val());if(y.wan&&y.wan.wirelessModeSettings&&y.wan.wirelessModeSettings.band){x=x.replace("5GHz",y.wan.wirelessModeSettings.band)}$(x).click()}function d(z){RAINIER.binder.toDom(z,$("#WirelessRepeater"));RAINIER.binder.toDom(z,$("#WirelessBridge"));k();c(z);var B=0;if(RAINIER.network.getCurrentWanStatus().wirelessConnection){B=RAINIER.network.getCurrentWanStatus().wirelessConnection.signalStrength}var x=RAINIER.network.getCurrentWanType(),y;if(x==="WirelessBridge"||x==="WirelessRepeater"){y=$("#"+x);if(z.wan.wirelessModeSettings.band==="2.4GHz"){y.find(".radio-24").show();y.find(".radio-5").hide()}else{if(z.wan.wirelessModeSettings.band==="5GHz"){y.find(".radio-24").hide();y.find(".radio-5").show()}}}var A=-29*Math.ceil(5*B/100);$(".signalStrength").css("background-position",A+"px 0")}function g(x){$("#bridgeModeHint span").text(n(x))}function o(){b.wirelessBridge={};b.wirelessRepeater={};b.wirelessRepeater.ssid=i($.extend(true,{},v.rules.ssid,{els:$('#WirelessRepeater input:[name="wan.wirelessModeSettings.ssid"]')}));b.wirelessRepeater.password=i($.extend(true,{},v.rules.password,{els:$('#WirelessRepeater input:[name="wan.wirelessModeSettings.password"]')}));b.wirelessBridge.ssid=i($.extend(true,{},v.rules.ssid,{els:$('#WirelessBridge input:[name="wan.wirelessModeSettings.ssid"]')}));b.wirelessBridge.password=i($.extend(true,{},v.rules.password,{els:$('#WirelessBridge input:[name="wan.wirelessModeSettings.password"]')}))}function r(){var x=true;if(x&&$('#WirelessRepeater input:[name="wan.wirelessModeSettings.ssid"]').is(":visible")){x=b.wirelessRepeater.ssid.isValid(true)}if(x&&$('#WirelessRepeater input:[name="wan.wirelessModeSettings.password"]').is(":visible")){x=b.wirelessRepeater.password.isValid(true)}if(x&&$('#WirelessBridge input:[name="wan.wirelessModeSettings.ssid"]').is(":visible")){x=b.wirelessBridge.ssid.isValid(true)}if(x&&$('#WirelessBridge input:[name="wan.wirelessModeSettings.password"]').is(":visible")){x=b.wirelessBridge.password.isValid(true)}return x}function t(y){var A=y.wanType==="WirelessRepeater"?$("#wirelessrepeater-warning-dialog").clone():$("#wirelessbridge-warning-dialog").clone();if(y.wanType==="WirelessRepeater"){var x=y.wirelessModeSettings.band==="5GHz"?"5":"2.4",z=RAINIER.ui.shared.strings.bands[x];return A.html().replace(/{radio_name}/g,z["short"])}else{if(y.wanType==="WirelessBridge"){if(y.wirelessModeSettings.band==="5GHz"){A.find("#band-24").hide()}else{A.find("#band-50").hide()}return A.html()}}return $("#bridgemode-warning-dialog").html()}function w(x,y){setTimeout(function(){window.location.replace(n(x))},y)}function p(x){setTimeout(function(){window.location.replace("http://linksyssmartwifi.com")},x)}function n(x){var y="http://"+x.hostName+"."+x.domain,z=window.navigator;if(z.platform.indexOf("Win32")>-1&&z.userAgent.indexOf("Win64")===-1){y=y.replace(".local","")}return y}function j(x){setInterval(function(){RAINIER.shared.pingTests.start(RAINIER.shared.pingTests.allTests,function(){x?w(x,30000):p(30000)},function(){})},15000)}function l(y,x,B){var z=RAINIER.network.isBehindNode(),A=z?150000:180000;RAINIER.event.fire("router.interruptionStarted");if(B&&B.powerModem.isPowerModemEnabled){return}if(z){e(x);RAINIER.event.connect("router.interruptionCompleted",function(){u(100);setTimeout(function(){w(x,0)},1500)});RAINIER.connect.checkRouterConnectionForRestoration(true,false)}else{f(y,x);j(x)}w(x,A)}function q(x){var y=x?150000:180000;if(x){e();RAINIER.event.fire("router.interruptionStarted");RAINIER.event.connect("router.interruptionCompleted",function(){u(100);setTimeout(function(){p(0)},1500)});RAINIER.connect.checkRouterConnectionForRestoration(true,false)}else{j()}p(y)}function u(x){if(x>=100){clearInterval(m)}else{RAINIER.ui.progressBar.update({element:$("#bridgemode-progress-bar"),percent:x})}}function e(x){function y(){var A=0,z=2.5*60000/100;m=setInterval(function(){A+=z;u(A/z)},z)}RAINIER.ui.dialog("#bridgemode-progress-dialog").show();y()}function f(z,x){var y="#bridgemode-set-dialog",A={};if(z==="WirelessRepeater"){y="#repeatermode-set-dialog"}if(x){RAINIER.ui.showWaiting()}else{RAINIER.ui.dialog(y,A).show()}}return{init:s,wanFromDom:a,wanToDom:d,redirectUrlToDom:g,addValidation:o,isValid:r,redirectToLSWF:q,redirectToBridgeDomain:l,dialogWarning:t,sanitizeWirelessModeSecurity:h}}());