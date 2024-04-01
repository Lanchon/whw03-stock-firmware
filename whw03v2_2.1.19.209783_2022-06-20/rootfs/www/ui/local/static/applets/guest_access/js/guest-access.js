(function(){var h=$("#guest-access-applet"),v=RAINIER.network.isBehindNode(),j=v?h.find("#guestWPAPassphrase"):h.find("#guestPassword"),q=h.find('select[name="maxSimultaneousGuests"]'),g=h.find("#guest-access-settings"),r=false,b,d,t,f=RAINIER.ui.dialogWarning,k=5*1000,u=true,c={};var o={guestSettings:{},radio:{}},i={guestSettings:{}};var l={isGuestNetworkEnabled:"boolean",maxSimultaneousGuests:"number","radio.band24.isEnabled":"boolean","radio.band50.isEnabled":"boolean"};var e={onToggleWidget:function(){RAINIER.connect.AppletManager.toggleWidgetShowState("B24C693D-4DFF-417D-A10F-A8212051E60E","E50B6C6C-35E7-425A-91BA-4313F87AA0B7")},onClose:function(){RAINIER.ui.MainMenu.closeApplet()},onSave:function(){s()}};function a(){RAINIER.ui.tooltip.add(h.find("[tooltip]"),"top");h.find("footer .cancel").click(e.onClose);h.find("footer .submit").click(e.onSave);h.find("#cbAddWidget").click(e.onToggleWidget);RAINIER.ui.editFormClick(g,g.find("#edit-guest-access > a"))}function n(){var w={validationType:"utf8LengthTooLong",maxLen:32,whiteSpace:false,isRequired:true},x=validation.ruleSet.wpaPassphrase;if(u){x={minLen:o.guestSettings.guestPasswordRestrictions.minLength,maxLen:o.guestSettings.guestPasswordRestrictions.maxLength,isRequired:true,validCharSet:RAINIER.ui.validation.concatAllowedCharRanges(o.guestSettings.guestPasswordRestrictions.allowedCharacters)}}x.message=RAINIER.ui.validation.strings.guestAccess.passwordInvalid;c.fnPasswordValid=RAINIER.ui.buildInputValidBalloon($.extend(true,{},x,{els:j}));c.fnSsid24Valid=RAINIER.ui.buildInputValidBalloon($.extend(true,{},w,{els:h.find('input[name="radio.band24.guestSSID"]')}));c.fnSsid50Valid=RAINIER.ui.buildInputValidBalloon($.extend(true,{},w,{els:h.find('input[name="radio.band50.guestSSID"]')}))}function s(){function x(){RAINIER.connect.checkRouterConnectionForRestoration(true,false)}var z=true;if(!o.guestSettings.canEnableGuestNetwork){RAINIER.ui.MainMenu.closeApplet()}else{i.guestSettings=$.extend(true,{},o.guestSettings,RAINIER.binder.fromDom(h,l));if(!u){$.delAttr(i.guestSettings,"maxSimultaneousGuests")}if(!r){$.delAttr(i.guestSettings.radio,"band50");$.delAttr(i.guestSettings.radio,"band60")}if(RAINIER.applets.guestNetwork.isGuestSSIDConflict(i.guestSettings,o.radio)){b.show();z=false}else{if(r){if(!o.radio.band24){$.delAttr(i.guestSettings.radio,"band24")}if(!o.radio.band50){$.delAttr(i.guestSettings.radio,"band50")}if(!o.radio.band60){$.delAttr(i.guestSettings.radio,"band60")}if(!v){if(o.radio.band24&&!o.radio.band24.settings.isEnabled&&i.guestSettings.radio.band24.isEnabled){d.show();z=false}else{if(o.radio.band50&&!o.radio.band50.settings.isEnabled&&i.guestSettings.radio.band50.isEnabled){t.show();z=false}}}}}console.warn("doUpdate: "+z);if(z&&c.fnPasswordValid.isValid(true)&&c.fnSsid24Valid.isValid(true)&&(!o.guestSettings.radio.band50||c.fnSsid50Valid.isValid(true))){console.warn("isBand24Changing",RAINIER.applets.guestNetwork.isBand24Changing(o,i));console.warn("isBand50Changing",RAINIER.applets.guestNetwork.isBand50Changing(o,i));if(i.guestSettings.isGuestNetworkEnabled!==o.guestSettings.isGuestNetworkEnabled||i.guestSettings.maxSimultaneousGuests!==o.guestSettings.maxSimultaneousGuests||RAINIER.applets.guestNetwork.isBand24Changing(o,i)||RAINIER.applets.guestNetwork.isBand50Changing(o,i)){var y=false,w=null;if(!r&&o.guestSettings.isGuestNetworkEnabled&&i.guestSettings.isGuestNetworkEnabled&&o.guestSettings.radio.band24.guestSSID!==i.guestSettings.radio.band24.guestSSID){RAINIER.ui.showWaiting();y=true;w=function(){setTimeout(function(){RAINIER.jnap.send({action:"/jnap/core/Reboot",data:{},cb:function(A){if(A.result==="OK"){RAINIER.event.fire("router.interruptionStarted");RAINIER.ui.showWaiting();setTimeout(function(){x()},4000)}else{}},disableDefaultAjaxErrHandler:true,disableDefaultRebootErrHandler:true})},k)}}RAINIER.applets.guestNetwork.setSettings(i.guestSettings,w,null,true,y)}else{}RAINIER.ui.MainMenu.closeApplet()}}}function m(z){o.guestSettings=z||o.guestSettings;g.removeClass("edit");if(v){if(o.guestSettings.radio.band24.guestWPAPassphrase==="BeMyGuest"){g.find("#edit-guest-access > a").click();g.find("#guestWPAPassphrase").focus();o.guestSettings.radio.band24.guestWPAPassphrase=""}}i.guestSettings=$.extend(true,{},o.guestSettings);u=symmetryUtil.guestAccess.isCaptivePortal(o.guestSettings);if(!v&&o.guestSettings.radio.band50){g.addClass("guest-50")}if(q.find("option").length===0){var y=parseInt(o.guestSettings.maxSimultaneousGuestsLimit/10,10),x=RAINIER.ui.common.strings.guest;for(var w=y;w<=o.guestSettings.maxSimultaneousGuestsLimit;w+=y){if(x!==RAINIER.ui.common.strings.guests&&w>1){x=RAINIER.ui.common.strings.guests}q.append('<option value="{0}">{0} {1}</option>'.format(w,x))}}RAINIER.binder.toDom(o.guestSettings,h,{});h.find("[tooltip]").each(function(){var A=$(this);A.attr("tooltip",A.text())});if(!o.guestSettings.canEnableGuestNetwork){f({msg:h.find("#wirelessIsDisabled").html(),hideSubmit:true,cancel:RAINIER.ui.button.strings.ok});q.attr("disabled","disabled");h.find('input[name="isGuestNetworkEnabled"]').attr("disabled","disabled");h.find("#edit-guest-access > a").hide();h.find("footer .cancel").hide();h.find("#enabled-text-24").text(RAINIER.ui.common.strings.disabled);h.find("#enabled-text-50").text(RAINIER.ui.common.strings.disabled)}else{h.find('input[name="isGuestNetworkEnabled"]').removeAttr("disabled");h.find("#edit-guest-access > a").show();q.removeAttr("disabled");h.find("footer .cancel").show();if(h.find("#enabled-24").is(":checked")){h.find("#enabled-text-24").text(RAINIER.ui.common.strings.enabled)}else{h.find("#enabled-text-24").text(RAINIER.ui.common.strings.disabled)}if(h.find("#enabled-50").is(":checked")){h.find("#enabled-text-50").text(RAINIER.ui.common.strings.enabled)}else{h.find("#enabled-text-50").text(RAINIER.ui.common.strings.disabled)}j.attr("maxlength",u?o.guestSettings.guestPasswordRestrictions.maxLength:validation.ruleSet.wpaPassphrase.maxLength);n()}h.find('input[name="isGuestNetworkEnabled"]').trigger("change");RAINIER.ui.fixIeForm(g);RAINIER.event.fire("applet.loaded")}function p(){r=RAINIER.network.isGuestNetwork3Supported();if(v){h.find(".showForLinksysRouters").remove()}else{h.find(".showForNodes").remove()}RAINIER.util.trapEnter(".toggle-edit input");h.find("#cbAddWidget").attr("checked",RAINIER.connect.AppletManager.getWidgetShowState("B24C693D-4DFF-417D-A10F-A8212051E60E","E50B6C6C-35E7-425A-91BA-4313F87AA0B7"));b=RAINIER.ui.dialog($("#guest-ssid-conflict"));d=RAINIER.ui.dialog($("#band24-disabled"));t=RAINIER.ui.dialog($("#band50-disabled"));var w=RAINIER.jnap.Transaction();RAINIER.applets.guestNetwork.getSettings(o.guestSettings,m,w);w.add({action:RAINIER.jnapActions.getRadioInfo(),data:{},cb:function(x){if(x.result==="OK"){o.radio=x.output||{};$.each(o.radio.radios,function(){switch(this.radioID){case"RADIO_2.4GHz":o.radio.band24=this;break;case"RADIO_5GHz":o.radio.band50=this;break;case"RADIO_6GHz":o.radio.band60=this;break}})}}});w.send();a();if($.cookie("app-flag")==="conflict"){$.cookie("app-flag",null,{expires:null,path:"/"});b.show()}}p()}());