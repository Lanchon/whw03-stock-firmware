(function(){var c,a=$("#media-prioritization-widget"),h=a.find("#media-pri-widget-list"),i=a.find("#device-templates").html();var b={devices:[],QoSSettings:{},WLANQoSSettings:{},LVVPSettings:{}};function f(){var m=c.sortRules(b.QoSSettings.deviceRules,b.QoSSettings.applicationRules),l=b.QoSSettings.isQoSEnabled,k=m.high.length;if(RAINIER.network.isLvvpSupported()&&b.LVVPSettings.isEnabled){return a.addClass("enabled videoCallsEnabled").removeClass("disabled populated empty")}a.removeClass("videoCallsEnabled");h.empty();a.toggleClass("enabled",l).toggleClass("disabled",!l);a.toggleClass("populated",k!==0).toggleClass("empty",k===0);$.each(m.high,function(){c.buildLi(i,h,c.getMediaData(this.ruleType,this.rule,false))})}function g(){var k=RAINIER.connect.AppletManager.getAppletById(c.appletId);if(k){RAINIER.ui.MainMenu.launchApplet(k)}else{console.warn("Widget: cannot locate Media pri applet")}}function d(){a.find("#media-pri-widget-container").click(g);RAINIER.event.connect("connection.applets.mediaPrioritization.change",function(l,k){if(k){_.extend(b,k);f()}else{e()}})}function e(){if(!c){return}c.load(function(k){b=k;f()})}function j(k){c=k;if(!RAINIER.shared.util.areServicesSupported(c.requiredServices)&&!RAINIER.network.isGamingPrioritizationSupported()){RAINIER.connect.AppletManager.hideWidget(c.appletId,c.widgetId);return}e()}d();j(RAINIER.applets.MediaPrioritization)}());