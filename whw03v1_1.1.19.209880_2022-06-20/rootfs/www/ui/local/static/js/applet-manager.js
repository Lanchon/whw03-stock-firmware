RAINIER.connect.AppletFactory={};RAINIER.connect.AppletFactory.makeApplet=(function(){return function(b){var a=b.url;if(a.substring(0,12)==="/ui/applets/"){a=b.url.replace("/ui/applets/","/ui/dynamic/applets/")}return{appletId:b.appletId,version:b.version,name:b.name,url:a,description:b.description,defaultPosition:b.defaultPosition,categoryId:b.appletCategory.appletCategoryId,categoryName:b.appletCategory.name,defaultCategoryPosition:b.appletCategory.defaultPosition,enableInBridgeMode:b.enableInBridgeMode,isAppletDisabled:b.isAppletDisabled||false,urlAccess:b.urlAccess,serviceSettingsOverrides:b.serviceSettingsOverrides}}}());RAINIER.connect.AppletManager=(function(){var f=[],a={};function c(l){var j=window.location.hash;function i(n){var m;if(RAINIER.network.isBehindNode()&&n.appletId==="B24C693D-4DFF-417D-A10F-A8212051E60E"){n.enableInBridgeMode=true}if(!$.cookie("agent-remote-assistance-session")&&n.appletId==="CD34B015-6EA6-4FE3-89CA-B47B6F18EF92"){n.isAppletDisabled=true}m=RAINIER.connect.AppletFactory.makeApplet(n);f.push(m);a[m.appletId]=m}function h(){if(RAINIER.shared.util.areServicesSupported(["/jnap/debug/Debug"])){if(j.indexOf("rm_")>-1&&j.indexOf("&hv_")>-1){return true}}return false}function k(m){RAINIER.network.getLocalAppletList().applets.forEach(i);m(true)}if(h()){RAINIER.deviceManager.getAuthorityDevice(function(p){var n=l,o=p.modelNumber(),m=p.hardwareVersion();console.warn("Overriding UI - Actual Model: "+o+", Vers: "+m);$("html").addClass("rm-hv");if(j.indexOf("rm_")>-1){o=j.substr(4,j.indexOf("&hv_")-4).toUpperCase();m=j.substr(j.indexOf("&hv_")+4)}else{k(n);return}if(p){RAINIER.cloud.send({url:"/cloud/applet-support-service/rest/appletfilter",type:"POST",data:{appletFilter:{network:{networkId:RAINIER.network.getCurrentNetworkID(),routerModelNumber:o,routerHardwareVersion:m,routerFirmwareVersion:p.firmwareVersion()}}},cb:function(r){var q=[],s;r.appletList.applets.forEach(function(t){if(RAINIER.network.isBridgeMode()){s=RAINIER.network.getLocalAppletInfo(t.applet.appletId);if(s){t.applet.enableInBridgeMode=s.enableInBridgeMode}}q.push(t.applet)});q.forEach(i);n(true)},cbError:function(q){n(false);return true}})}else{n(false)}})}else{k(l)}}function e(i){var h=a[i];if(h&&h.widgets){return h.widgets}else{return null}}function g(j,i){var h=e(j);if(h){return h[i]?h[i].show:false}return false}function b(j,i){var h=e(j);if(h&&h[i].show){h[i].show=false;RAINIER.connect.widgetManager.handleWidgetShowChange(h[i])}}function d(j,i){var h=e(j);if(h){h[i].show=!h[i].show;RAINIER.connect.widgetManager.handleWidgetShowChange(h[i])}}return{initialize:function(h){c(function(i){if(i){f.sort(function(k,j){if(k.defaultCategoryPosition===j.defaultCategoryPosition){return k.defaultPosition-j.defaultPosition}else{return k.defaultCategoryPosition-j.defaultCategoryPosition}})}else{}h(i)})},getAppletList:function(){return f},getAppletById:function(h){return a[h]},getWidgetShowState:g,hideWidget:b,toggleWidgetShowState:d}}());