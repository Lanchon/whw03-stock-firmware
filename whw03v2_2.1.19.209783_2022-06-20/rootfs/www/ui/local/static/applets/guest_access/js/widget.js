(function(){var a=$("#guest-access.widget"),i=null,d=null,r=RAINIER.network.isBehindNode(),k=RAINIER.connect.AppletManager.getAppletById("691E0149-A1D4-450C-9922-82CAA65B16C0"),b="known-guests",h,j,q,g;function p(u){var v=0,w=RAINIER.ui.common.strings.guest;if(i.isGuestNetworkEnabled){u.forEach(function(x){if(x.isOnline()&&x.isGuest()){v++}})}if(v!==1){w=RAINIER.ui.common.strings.guests}a.find("#lnkCurrently").text(v+" "+w)}function c(u){if(!u||u.result!=="OK"){i.isGuestNetworkEnabled=!i.isGuestNetworkEnabled;l(i)}}function m(){var u=RAINIER.applets.guestNetwork.isGuestSSIDConflict(i,[h,j,q]);if(u){f("conflict");c()}else{if(i.isGuestNetworkEnabled!==d.isGuestNetworkEnabled){RAINIER.applets.guestNetwork.setSettings(i,c)}else{}}}function o(){i.isGuestNetworkEnabled=a.find("#gaEnabled").is(":checked");if(r&&g){i.isGuestNetworkEnabled=!i.isGuestNetworkEnabled;l(i);t();return}if(i.isGuestNetworkEnabled){RAINIER.ui.showWaiting();RAINIER.jnap.send({action:RAINIER.jnapActions.getRadioInfo(),data:{},cb:function(u){if(u.result==="OK"){$.each(u.output.radios,function(){switch(this.radioID){case"RADIO_2.4GHz":h=this;break;case"RADIO_5GHz":j=this;break;case"RADIO_6GHz":q=this;break}});m()}else{c(u)}}})}else{m()}}function t(u){var v=RAINIER.connect.AppletManager.getAppletById("B24C693D-4DFF-417D-A10F-A8212051E60E");if(v){RAINIER.ui.MainMenu.launchApplet(v,null,u)}else{console.warn("Widget: cannot locate Guest Access applet")}}function f(u){if($(this).hasClass("disabled")){return false}t(u)}function s(){if($(this).hasClass("disabled")){return false}if(k){RAINIER.ui.MainMenu.launchApplet(k,b)}else{console.warn("Widget: cannot locate Device applet")}}function l(u){i=u?$.extend(true,i,u):i;d=$.extend(true,{},i);g=i.radio.band24.guestWPAPassphrase==="BeMyGuest";RAINIER.deviceManager.getDevices(p,null);if(!i.canEnableGuestNetwork){a.find("[tooltip]").hide();a.find("#lnkCurrently").hide();a.find("#gaEnabled").attr("disabled","disabled")}else{a.find("[tooltip]").show();a.find("#lnkCurrently").show();a.find("#gaEnabled").removeAttr("disabled")}if(i.radio.band50){a.find(".ga-50").css("display","block")}if(r&&!RAINIER.shared.util.areServicesSupported(["/jnap/devicelist/DeviceList4"])){a.find("#guestsCount").css("display","none")}if(i.isGuestNetworkEnabled){a.find(".on-state").show();a.find(".off-state").hide();a.find(".dlStats").removeClass("disabled");a.find(".app-link").removeClass("disabled");a.find("#lnkCurrently").removeClass("disabled");if(r||i.radio.band24.isEnabled){a.find('a[name="radio.band24.guestSSID"]').removeClass("disabled")}else{a.find('a[name="radio.band24.guestSSID"]').addClass("disabled")}if(i.radio.band50){if(i.radio.band50.isEnabled){a.find('a[name="radio.band50.guestSSID"]').removeClass("disabled")}else{a.find('a[name="radio.band50.guestSSID"]').addClass("disabled")}}}else{a.find(".off-state").show();a.find(".on-state").hide();a.find(".dlStats").addClass("disabled");a.find(".app-link").addClass("disabled");a.find("#lnkCurrently").addClass("disabled")}RAINIER.binder.toDom(i,a,{});a.find("[tooltip]").each(function(){$(this).attr("tooltip",$(this).text())});RAINIER.ui.tooltip.add(a.find("[tooltip]"),"top");a.find("#gaEnabled").trigger("change");if(r&&g){a.find('a[name="radio.band24.guestWPAPassphrase"]').text("")}}function e(){RAINIER.applets.guestNetwork.getSettings(i,l)}function n(){if(!k){k=RAINIER.connect.AppletManager.getAppletById("EEBEB3F4-5482-4DAE-8D77-1BA5AC7D19BE");b="guest-network"}a.find("#gaEnabled").click(o);a.find(".app-link").click(f);a.find("#lnkCurrently").click(s);RAINIER.event.connect("guestNetwork.updated",function(u,v){l(v)});RAINIER.event.connect(["devices.revisionUpdated","devices.guestNetworkUpdated"],function(){RAINIER.deviceManager.getDevices(p,null)});e()}n()}());