(function(){var d=$("#wireless.widget"),o=1,k,b=false;function i(r){r=r||"";if($(this).hasClass("disabled")){return false}var q=RAINIER.connect.AppletManager.getAppletById("7B1F462B-1A78-4AF6-8FBB-0C221703BEA4");if(q){RAINIER.ui.MainMenu.launchApplet(q,r)}else{console.warn("Widget: cannot locate Wireless applet")}}function c(){var q=$(this),r=q.parent().siblings();if(!r.is(":visible")){d.find(".collapsedPassword").hide();d.find(".ssidLabel").removeClass("ssidLabelActive");r.show();q.addClass("ssidLabelActive")}else{q.removeClass("ssidLabelActive");r.hide()}}function f(s){if((RAINIER.network.isBehindNode()&&!b)&&window.location.hash!=="#casupport"){var q=_.find(s,{radioID:"RADIO_2.4GHz"}),r=_.find(s,{radioID:"RADIO_5GHz"});if(RAINIER.applets.wireless.areAllRadioSettingsIdentical(s)){return[q]}else{return _.compact([q,r])}}return s}function l(){var r=d.find("#radiosDisplay"),q;r.empty();RAINIER.applets.wireless.sortRadios(k.radios);q=f(k.radios);k.combineNetworks=q.length===1;q.forEach(function(t,s){if(RAINIER.applets.wireless.shouldFilterRadio(t,k)){var u=d.find("#radioTemplate").clone(),v=RAINIER.shared.util.getLabeledRadio(k,t.radioID);v.radioIDTemplate=t.radioID.replace(".","");u.attr("id",v.radioIDTemplate);if(s===0){u.find(".radioDisplay").addClass("first")}r.append(u);h(v);p(v);a(v);j(v);n(v);RAINIER.binder.toDom(v,d.find("#"+v.radioIDTemplate),{})}});if(k.bandSteeringMode==="TriBand"){r.addClass("triBandSteeringMode")}else{r.removeClass("triBandSteeringMode")}d.find(".app-link").click(function(){i("")});d.find(".wfs-icon, .active-wfs-icon").click(function(){i("scheduler")});d.find(".ssidLabel").click(c);RAINIER.ui.tooltip.add(d.find("[tooltip]"),"top")}function n(r){var q=d.find("#"+r.radioIDTemplate+" .ssidLabel"),s=217;switch(o){case 2:s=199;break;case 3:s=181;break}if(!k.isBandSteeringEnabled||r.radioID!=="RADIO_5GHz"){s=(s-d.find("#"+r.radioIDTemplate+" .bandInfo").outerWidth(true))}else{d.find("#"+r.radioIDTemplate+" .bandInfo").css("margin-top",5)}q.css("max-width",s);o=1}function h(q){if(RAINIER.util.isSecurityTypeOpen(q.settings.security)){d.find("#"+q.radioIDTemplate+" .radioIcons .unlock-icon").css("display","inline");d.find("#"+q.radioIDTemplate+" .collapsedPassword .password").addClass("unsecured");q.settings.password=RAINIER.ui.common.strings.wirelessSecurity.None}else{e(q);d.find("#"+q.radioIDTemplate+" .radioIcons .lock-icon").css("display","inline")}}function e(q){if(q.settings.security==="WEP"){q.settings.password=q.settings.wepSettings["key"+q.settings.wepSettings.txKey]}else{if(q.settings.security==="WPA-Enterprise"||q.settings.security==="WPA2-Enterprise"||q.settings.security==="WPA-Mixed-Enterprise"){q.settings.password=q.settings.wpaEnterpriseSettings.sharedKey}else{q.settings.password=q.settings.wpaPersonalSettings.passphrase}}}function p(q){if(!q.settings.isEnabled){d.find("#"+q.radioIDTemplate+" .radioDisplay").addClass("disabledSSID")}if(!q.settings.broadcastSSID){d.find("#"+q.radioIDTemplate+" .radioIcons .eye-icon").css("display","inline");o++}}function a(r){if(RAINIER.network.isWirelessSchedulerEnabled()){var q="wfs-icon";RAINIER.network.areRadiosDisabledByWFS(function(s){if(s){d.find("#"+r.radioIDTemplate+" .radioDisplay").addClass("disabledSSID");d.find("#"+r.radioIDTemplate+" .radioIcons ."+q).css("display","none");q="active-"+q}d.find("#"+r.radioIDTemplate+" .radioIcons ."+q).css("display","inline")});o++}}function j(q){d.find("#"+q.radioIDTemplate+" .bandInfo").html(q.labels["short"])}function g(){RAINIER.jnap.send({action:RAINIER.jnapActions.getRadioInfo(),data:{},cb:function(q){if(q.result==="OK"){k=q.output;b=symmetryUtil.wireless.has6GHzRadio(k.radios);l()}else{}}})}function m(){g();RAINIER.event.connect("wireless.updated",function(q,r){if(r){k=$.extend(true,{},r);l()}else{g()}})}m()}());