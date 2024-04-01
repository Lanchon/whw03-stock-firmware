(function(){var e=$("#add-a-device"),j=$("#device-list-applet"),a="7B1F462B-1A78-4AF6-8FBB-0C221703BEA4",g=false,b={radio:{band24:{},band50:{}}};var m={onAddDeviceButtonClick:function(){RAINIER.event.fire("Add Device Button Pressed");m.onAddDeviceClick()},onAddDeviceClick:function(){j.find("#divTabWrap .tabs span").first().click();j.find("#add-a-device-wrapper").addClass("expand");f(e.find("#add-device-container"));j.find("ul.tabs").hide();c()},onCancelClick:function(){i()},onAddComputerClick:function(){f(e.find("#add-computer-container"))},onComputerOkClick:function(){RAINIER.event.fire("New Device Connected");i()},onAddWPSClick:function(){j.find("header .close-button").click();RAINIER.ui.showWaiting();setTimeout(function(){RAINIER.ui.hideWaiting();var n=RAINIER.connect.AppletManager.getAppletById(a);if(n){RAINIER.ui.MainMenu.launchApplet(n,"wps")}else{console.warn("Widget: cannot locate Wireless applet")}},500)},onAddOtherClick:function(){f(e.find("#add-other-container"))},onOtherOkClick:function(){RAINIER.event.fire("New Device Connected");i()},onAddUSBPrinterClick:function(){f(e.find("#add-usb-printer-container"))}};function i(){j.find("#add-a-device-wrapper").removeClass("expand");j.find("ul.tabs").show()}function f(n){e.children("section").css("display","none");n.css("display","block")}function d(){RAINIER.jnap.send({action:RAINIER.jnapActions.getRadioInfo(),data:{},cb:function(n){b.radio=n.output||{};if(n.result==="OK"){$.each(n.output.radios,function(){switch(this.band){case"2.4GHz":b.radio.band24=this;break;case"5GHz":b.radio.band50=this;break}});l()}}})}function h(q,p,n){q.find("#password-row-"+n).hide();q.find("#key-row-"+n).hide();q.find("#shared-key-row-"+n).hide();if(RAINIER.util.isSecurityTypeWep(p.security,n)){q.find("#key-row-"+n).show();var o=q.find("#key-"+n);if(p.wepSettings.txKey===1){o.text(p.wepSettings.key1)}else{if(p.wepSettings.txKey===2){o.text(p.wepSettings.key2)}else{if(p.wepSettings.txKey===3){o.text(p.wepSettings.key3)}else{if(p.wepSettings.txKey===4){o.text(p.wepSettings.key4)}}}}}else{if(RAINIER.util.isSecurityTypeWpaPersonal(p.security,n)){q.find("#password-row-"+n).show();q.find("#password-"+n).text(p.wpaPersonalSettings.passphrase)}else{if(RAINIER.util.isSecurityTypeWpaEnterprise(p.security,n)){q.find("#shared-key-row-"+n).show();q.find("#shared-key-"+n).text(p.wpaEnterpriseSettings.sharedKey)}}}}function c(){if(g){return}g=true;e.find("footer>button.cancel").click(m.onCancelClick);var n=e.find("#add-device-container");n.find("#add-computer").click(m.onAddComputerClick);n.find("#add-wps").click(m.onAddWPSClick);n.find("#add-other").click(m.onAddOtherClick);if(RAINIER.shared.util.areServicesSupported(["/jnap/storage/Storage"])&&RAINIER.applets.USBStorage.isVUSBDriverInstalled()){n.find("#add-usb-printer").click(m.onAddUSBPrinterClick)}else{n.find("#add-usb-printer").hide();n.find("#usb-printer-text").hide()}n.find(".back").click(m.onCancelClick);n=e.find("#add-computer-container");n.find(".back").click(m.onAddDeviceClick);n.find(".submit").click(m.onComputerOkClick);n.find(".cancel").click(m.onCancelClick);n=e.find("#add-other-container");n.find(".back").click(m.onAddDeviceClick);n.find(".submit").click(m.onOtherOkClick);n=e.find("#add-usb-printer-container");n.find(".back").click(m.onAddDeviceClick)}function l(){var u={ssid:RAINIER.ui.strings.deviceList.networkNotEnabled,wpaPersonalSettings:{passphrase:""},security:""};var q=u,p=u;if(b.radio.band24&&b.radio.band24.settings&&b.radio.band24.settings.isEnabled){q=b.radio.band24.settings}if(b.radio.band50&&b.radio.band50.settings&&b.radio.band50.settings.isEnabled){p=b.radio.band50.settings}var o=q.ssid,t=(q.security)?RAINIER.ui.common.strings.wirelessSecurity[q.security]:"",n=p.ssid,s=(p.security)?RAINIER.ui.common.strings.wirelessSecurity[p.security]:"";var r=e.find("#add-computer-container");r.find("#networkName24").text(o);r.find("#securityType24").text(t);r.find("#networkName50").text(n);r.find("#securityType50").text(s);h(r,q,"24");h(r,p,"50");r=e.find("#add-other-container");r.find("#networkName24").text(o);r.find("#securityType24").text(t);r.find("#networkName50").text(n);r.find("#securityType50").text(s);h(r,q,"24");h(r,p,"50");if($.cookie("app-flag")==="add-device"){j.find("#show-add-a-device").click()}}function k(){e.css("display","block");j.find("#show-add-a-device").click(m.onAddDeviceButtonClick);d();RAINIER.event.fire("Add Device Loaded")}k()}());