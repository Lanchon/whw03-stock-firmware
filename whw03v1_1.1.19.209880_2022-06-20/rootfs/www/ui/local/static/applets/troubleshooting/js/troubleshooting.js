(function(){var S=$("#troubleshooting-applet"),A=S.find("#status"),n=S.find("#dhcpclienttabledialog"),s=n.find("#dhcpclienttable"),aG=RAINIER.ui.dialog(n,{}),X=S.find("#diagnostics"),at=S.find("#diagnostics-ping"),K=S.find("#diagnostics-trace"),aR=S.find("#share-diagnostics"),ay=S.find("#ping-log"),g=S.find("#trace-log"),ab=S.find("#devices-ipv4"),Z=S.find("#devices-ipv6"),Y=S.find("#logs"),Q=$("#diagnostics-restore-configuration"),R=A.find("#lan-ports-wrapper"),aI=null,r=RAINIER.ui.buildInputValidBalloon,aK=RAINIER.ui.dialogWarning,v=null,a=null,aF=null,W=null,y=null,d=null,ao=false,q=null,j=false,U=null,av=60*1000;var ad=RAINIER.ui.template.createTemplate(S.find("#templateStatusRow tr")),ag=RAINIER.ui.template.createTemplate(S.find("#templateStatusRowIPv6 tr")),z=RAINIER.ui.template.createTemplate(S.find("#templateDHCPClientRow tr")),an=RAINIER.ui.template.createTemplate(S.find("#template-radio tr")),P=RAINIER.network.isLinkAggregationPresent()?'<tr class="port"><td>{0}</td><td name="port{1}_100"></td><td name="port{1}_1gbps"></td><td name="port{1}_linkagg"></td></tr>':'<tr class="port"><td>{0}</td><td name="port{1}_100"></td><td name="port{1}_1gbps"></td></tr>';var L={devices:[],wireless:{radios:[]},time:{},localtime:{},wan:{},wanStatus:{},ipv6:{},router5IPv6:{},routerManagement:{},lanSettings:{},info:{},connections:{},ports:{},dhcpLease:{},cloneSettings:{},linkAggregation:{},logs:{isLoggingEnabled:false,incoming:{},outgoing:{},dhcp:{},security:{}},authorityDevice:{},powerModem:{},adslLineStatus:{},wirelessScheduler:{},openVpn:{},dataUpload:{}};var aQ={"labels.wirelessNetwork":"display-only"};var O={};var w={onRestorePreviousFirmware:function(){aK({msg:S.find("#restorePreviousFirmware").html(),onSubmit:aw})},onReboot:function(){aK({msg:S.find("#rebootRouter").html(),onSubmit:J,submit:RAINIER.ui.button.strings.restart,cancel:RAINIER.ui.button.strings.cancel})},onFactoryReset:function(){aK({msg:S.find("#factoryReset").html(),onSubmit:x})},onRestoreBackup:function(){aK({msg:S.find("#restoreBackup").html(),onSubmit:aL})}};var V={isLocale2Supported:false,isRouter5Supported:false,isDiagnostics3Supported:false,isCore4Supported:false,isNodesRebootSupported:false};function M(){if(V.isLocale2Supported){var aT=L.localtime.currentTime.replace(/\d{4}\-\d{2}\-\d{2}T\d{2}\:\d{2}\:\d{2}(.+)(\d{2})(\d{2})/,"$1"),aU=parseInt(L.localtime.currentTime.replace(/\d{4}\-\d{2}\-\d{2}T\d{2}\:\d{2}\:\d{2}(.+)(\d{2})(\d{2})/,"$2"),10),aW=parseInt(L.localtime.currentTime.replace(/\d{4}\-\d{2}\-\d{2}T\d{2}\:\d{2}\:\d{2}(.+)(\d{2})(\d{2})/,"$3"),10);return parseInt(aT+(aU*60+aW),10)}else{for(var aV=0;aV<L.time.supportedTimeZones.length;aV++){if(L.time.timeZoneID===L.time.supportedTimeZones[aV].timeZoneID){return L.time.supportedTimeZones[aV].utcOffsetMinutes}}}return null}function aE(aV){var aT=aV>=0?"+":"-",aU=Math.floor(Math.abs(aV/60));aV=RAINIER.util.addALeadingZero(Math.abs(aV%60));return"("+RAINIER.ui.common.strings.GMT+" "+aT+RAINIER.util.addALeadingZero(aU)+":"+aV+")"}function aO(aT){var aU=M();return RAINIER.util.utcTimeWithOffsetToString(RAINIER.util.utcTimeToDate(aT),aU*60000)+" "+aE(aU)}function af(aU,aT){if(aU!==null){aU.add({action:RAINIER.jnapActions.getWANStatus(),data:{},cb:function(aV){if(typeof aT==="function"){aT(aV)}}})}else{RAINIER.jnap.send({action:RAINIER.jnapActions.getWANStatus(),data:{},cb:function(aV){if(aV.output){if(typeof aT==="function"){aT(aV)}}else{}}})}}function o(aU,aV,aT){if(aU.document.readyState==="complete"){aU.document.writeln(aV);if(aT){setTimeout(function(){aU.print();if($.browser.msie){setTimeout(function(){aU.location.reload()},550)}},550)}}else{setTimeout(function(){o(aU,aV,aT)},500)}}function au(aT){aT.add({action:RAINIER.jnapActions.getRadioInfo(),data:{},cb:function(aU){L.wireless=aU.output||{};if(aU.result==="OK"){_.each(L.wireless.radios,function(aV){if(aV.radioID==="RADIO_6GHz"){aV.band="6GHz"}});RAINIER.applets.wireless.sortRadios(L.wireless.radios);L.wireless.radios.reverse()}else{}}});af(aT,function(aU){if(aU.result==="OK"){L.wanStatus=aU.output||{}}else{}});aT.add({action:RAINIER.jnapActions.getWANSettings(),data:{},cb:function(aU){if(aU.result==="OK"){L.wan=aU.output||{}}else{}}});aT.add({action:"/jnap/locale/GetTimeSettings",data:{},cb:function(aU){if(aU.result==="OK"){L.time=aU.output||{}}else{}}});aT.add({action:"/jnap/core/GetDeviceInfo",data:{},cb:function(aU){if(aU.result==="OK"){L.info=aU.output||{}}else{}}});aT.add({action:"/jnap/router/GetEthernetPortConnections",data:{},cb:function(aU){if(aU.result==="OK"){L.ports=aU.output||{}}else{}}});aT.add({action:"/jnap/router/GetLANSettings",data:{},cb:function(aU){if(aU.result==="OK"){L.lanSettings=aU.output||{};if(aU.output){L.lanSettings.isDHCPEnabled=L.lanSettings.isDHCPEnabled?RAINIER.ui.common.strings.enabled:RAINIER.ui.common.strings.disabled}else{}}else{}}});aT.add({action:"/jnap/router/GetIPv6Settings",data:{},cb:function(aU){if(aU.result==="OK"){if(aU.output){L.ipv6=aU.output}else{}}else{}}});if(V.isRouter5Supported){aT.add({action:"/jnap/router/GetIPv6Settings2",data:{},cb:function(aU){if(aU.result==="OK"){if(aU.output){L.router5IPv6=aU.output}else{}}else{}}})}aT.add({action:"/jnap/router/GetMACAddressCloneSettings",data:{},cb:function(aU){if(aU.result==="OK"){if(aU.output){L.cloneSettings=aU.output}else{}}else{}}});if(RAINIER.shared.util.areServicesSupported(["/jnap/routermanagement/RouterManagement"])){aT.add({action:"/jnap/routermanagement/GetRemoteManagementStatus",data:{},cb:function(aU){if(aU.result==="OK"){L.routerManagement=aU.output||{};if(aU.output){L.routerManagement.serviceState=RAINIER.ui.common.strings.remoteManagementServiceState[L.routerManagement.serviceState]}else{}}else{}}})}if(V.isLocale2Supported){aT.add({action:"/jnap/locale/GetLocalTime",data:{},cb:function(aU){if(aU.result==="OK"){L.localtime=aU.output||{};if(aU.output){}else{}}else{}}})}if(RAINIER.network.isPowerModemSupported()){aT.add({action:"/jnap/powermodem/GetDSLSettings",data:{},cb:function(aU){if(aU.result==="OK"){L.powerModem=aU.output||{};if(aU.output){}else{}}else{}}})}else{A.find(".powerModem").hide()}if(RAINIER.network.isWirelessSchedulerSupported()){RAINIER.network.updateWirelessSchedulerSettings(function(){L.wirelessScheduler=$.extend(true,{},RAINIER.network.getWirelessSchedulerSettings());RAINIER.network.areRadiosDisabledByWFS(function(aU){L.wirelessScheduler.radiosStatus=aU});RAINIER.event.fire("wireless.updated")})}else{A.find(".wirelessScheduler").hide()}if(RAINIER.network.isOpenVPNSupported()){aT.add({action:"/jnap/openvpn/GetOpenVPNSettings",data:{},cb:function(aU){if(aU.result==="OK"){L.openVpn=aU.output||{};if(aU.output){}else{}}else{}}})}else{A.find(".openVpn").hide()}if(RAINIER.network.isLinkAggregationPresent()){R.append(S.find("#templateLANPortsLinkAgg").html());aI=R.find("#lan-ports-linkaggregation");aT.add({action:"/jnap/linkaggregation/GetLinkAggregationSettings",data:{},cb:function(aU){if(aU.result==="OK"){L.linkAggregation=$.extend(true,{},aU.output||{});if(!aU.output){}}else{}}})}else{R.append(S.find("#templateLANPorts").html());aI=R.find("#lan-ports")}}function aP(aT){RAINIER.jnap.send({action:"/jnap/powermodem/GetADSLLineStatus",data:{},timeoutMs:15000,cb:function(aU){if(aU.result==="OK"){L.adslLineStatus=aU.output||{};if(aU.output){}else{}}else{}aT(aU)}})}function i(aT){function aU(a0,aZ){if(aZ){a0.physInterface=RAINIER.ui.common.strings.offline;if(aZ.data.connections.length>0){for(var aY=0;aY<aZ.data.connections.length;aY++){console.warn(aZ.data);if(aZ.data.connections[aY].macAddress===a0.macAddress){if(aZ.data.connections[aY].wireless){a0.physInterface=RAINIER.ui.common.strings.netType.wireless}else{a0.physInterface=RAINIER.ui.common.strings.netType.lan}break}}}a0.friendlyName=aZ.friendlyName();var a1=RAINIER.ui.template.createBlock(z,a0);s.find("tbody").append(a1)}}function aW(aZ,a1){var a0=new RAINIER.util.utcTimeToDate(aZ),a2=new RAINIER.util.utcTimeToDate(a1),a6=a2.getTime()-a0.getTime();if(a6>0){var a4=Math.floor(a6/3600000),a5=Math.floor(a6%3600000/60000),a3=Math.floor(a6%3600000%60000/1000);if(a6>86400000){var a7=Math.floor(a4/24);if(a4%24>=12){a7+=1}var aY=RAINIER.ui.common.strings.day;if(a7>1){aY=RAINIER.ui.common.strings.days}return"~"+a7+" "+aY}else{return RAINIER.util.addALeadingZero(a4)+":"+RAINIER.util.addALeadingZero(a5)+":"+RAINIER.util.addALeadingZero(a3)}}else{return RAINIER.ui.common.strings.expired}}RAINIER.ui.clearTbl(s);for(var aV=0;aV<L.dhcpLease.leases.length;aV++){var aX={hostName:L.dhcpLease.leases[aV].hostName,ipAddress:L.dhcpLease.leases[aV].ipAddress,macAddress:L.dhcpLease.leases[aV].macAddress,expiration:L.dhcpLease.leases[aV].expiration,clientID:L.dhcpLease.leases[aV].clientID};aX.leaseTimeLeft=aW(L.time.currentTime,aX.expiration);RAINIER.deviceManager.getDeviceByMACAddress({cb:aU.curry(aX),macAddress:aX.macAddress})}if(typeof aT==="function"){aT()}}function aM(aT){RAINIER.ui.clearTbl(ab);RAINIER.ui.clearTbl(Z);$.each(aT,function(){ae(this);if(this.ipAddress){T(ab,this,ad)}if(this.ipv6Address){T(Z,this,ag)}})}function ap(){var aU=$.extend(true,{},L.wireless),a0=null,aY,aW=true,aV;A.find("#report-wrapper").scrollTop(0);if(!L.authorityDevice.macAddress){RAINIER.deviceManager.getAuthorityDevice(function(a1){L.authorityDevice.macAddress=a1.data.knownMACAddresses[0];A.find("#status-report-content").find('td[name="authorityDevice.macAddress"]').text(L.authorityDevice.macAddress)},-1)}RAINIER.deviceManager.getDevices(aM,{excludeAuthority:true},-1);var aZ=$.extend({},L.info);aZ.currentRouterTime=aO(L.time.currentTime);aZ.currentBrowserTime=RAINIER.util.currentDateString()+" "+aE(new Date().getTimezoneOffset()*-1);aZ.ipv6=L.ipv6;aZ.routerManagement=L.routerManagement;aZ.wan=L.wan;aZ.wanStatus=L.wanStatus;aZ.authorityDevice=L.authorityDevice;aZ.powerModem=L.powerModem;aZ.adslLineStatus=L.adslLineStatus;if(aZ.powerModem.isPowerModemEnabled){aZ.powerModem.dslSettings.wanType=RAINIER.ui.common.strings.wanType[aZ.powerModem.dslSettings.wanType];aZ.powerModem.dslSettings.multiplexing=RAINIER.ui.common.strings.powerModemStatus.multiplexing[aZ.powerModem.dslSettings.multiplexing];aZ.powerModem.dslSettings.qosType=RAINIER.ui.common.strings.powerModemStatus.qosType[aZ.powerModem.dslSettings.qosType];aZ.powerModem.dslSettings.pcr=aZ.powerModem.dslSettings.pcr+" "+RAINIER.ui.common.strings.powerModemStatus.cps;aZ.powerModem.dslSettings.scr=aZ.powerModem.dslSettings.scr+" "+RAINIER.ui.common.strings.powerModemStatus.cps;aZ.powerModem.dslSettings.vpi=aZ.powerModem.dslSettings.vpi;aZ.powerModem.dslSettings.vci=aZ.powerModem.dslSettings.vci;aZ.powerModem.dslSettings.modulation=RAINIER.ui.common.strings.powerModemStatus.modulation[aZ.powerModem.dslSettings.modulation];if(aZ.adslLineStatus.status==="Up"){aZ.adslLineStatus.downDataRateBps=parseFloat(Math.round((aZ.adslLineStatus.downDataRateBps/1024)*100)/100).toFixed(2)+" "+RAINIER.ui.common.strings.adslLineStatus.kbps;aZ.adslLineStatus.upDataRateBps=parseFloat(Math.round((aZ.adslLineStatus.upDataRateBps/1024)*100)/100).toFixed(2)+" "+RAINIER.ui.common.strings.adslLineStatus.kbps;aZ.adslLineStatus.downOutputPowerdBm=aZ.adslLineStatus.downOutputPowerdBm+" "+RAINIER.ui.common.strings.adslLineStatus.dBm;aZ.adslLineStatus.upOutputPowerdBm=aZ.adslLineStatus.upOutputPowerdBm+" "+RAINIER.ui.common.strings.adslLineStatus.dBm;aZ.adslLineStatus.downNoiseMargindB=aZ.adslLineStatus.downNoiseMargindB+" "+RAINIER.ui.common.strings.adslLineStatus.dB;aZ.adslLineStatus.upNoiseMargindB=aZ.adslLineStatus.upNoiseMargindB+" "+RAINIER.ui.common.strings.adslLineStatus.dB;aZ.adslLineStatus.downAttenuationdB=aZ.adslLineStatus.downAttenuationdB+" "+RAINIER.ui.common.strings.adslLineStatus.dB;aZ.adslLineStatus.upAttenuationdB=aZ.adslLineStatus.upAttenuationdB+" "+RAINIER.ui.common.strings.adslLineStatus.dB}}if(aZ.adslLineStatus.status){aZ.adslLineStatus.status=RAINIER.ui.common.strings.adslLineStatus.status[aZ.adslLineStatus.status]}aZ.wirelessScheduler=L.wirelessScheduler;if(aZ.wirelessScheduler.isWirelessSchedulerEnabled!==undefined){aZ.wirelessScheduler.isWirelessSchedulerEnabled=aZ.wirelessScheduler.isWirelessSchedulerEnabled?RAINIER.ui.common.strings.enabled:RAINIER.ui.common.strings.disabled;aZ.wirelessScheduler.radiosStatus=aZ.wirelessScheduler.radiosStatus?RAINIER.ui.common.strings.off:RAINIER.ui.common.strings.on}aZ.openVpn=L.openVpn;if(aZ.openVpn.isOpenVPNEnabled!==undefined){var aX=aZ.openVpn.clientIPStartAddress.split(".");aX[3]="2 - 6";aZ.openVpn.clientIPStartAddress=aX.join(".");aZ.openVpn.isOpenVPNEnabled=aZ.openVpn.isOpenVPNEnabled?RAINIER.ui.common.strings.enabled:RAINIER.ui.common.strings.disabled;aZ.openVpn.serverIPAddress=aZ.openVpn.hostname||aZ.openVpn.serverIPAddress;aZ.openVpn.protocol=RAINIER.ui.common.strings.ipProtocol[aZ.openVpn.protocol];A.find(".openVpn-users-table .userRow").remove();$.each(aZ.openVpn.profiles,function(){A.find(".openVpn-users-table").append('<tr class="userRow"><td>'+this.username+"</td></tr>")})}aZ.lanSettings=L.lanSettings;if(L.cloneSettings.isMACAddressCloneEnabled){aZ.internetMacAddress=L.cloneSettings.macAddress}else{aZ.internetMacAddress=L.wanStatus.macAddress}aZ.lanSettings.subnetMask=RAINIER.util.fromPrefixLengthToSubnet(L.lanSettings.networkPrefixLength);if(typeof L.wanStatus.wanConnection!=="undefined"&&L.wanStatus.wanConnection.mtu===0){aZ.wanStatus.wanConnection.mtu=RAINIER.ui.common.strings.auto}A.find("#lease-mins").text("");if(aZ.wanStatus.wanConnection){if(aZ.wanStatus.wanConnection.dhcpLeaseMinutes){if(aZ.wanStatus.wanConnection.dhcpLeaseMinutes===1){A.find("#lease-mins").text(RAINIER.ui.common.strings.minute)}else{A.find("#lease-mins").text(RAINIER.ui.common.strings.minutes)}}aZ.wanStatus.wanConnection.subnetMask=RAINIER.util.fromPrefixLengthToSubnet(L.wanStatus.wanConnection.networkPrefixLength);aZ.ipv4Type=RAINIER.ui.common.strings.wanType[L.wanStatus.wanConnection.wanType]}else{aZ.ipv4Type=RAINIER.ui.common.strings.wanType[L.wanStatus.detectedWANType]}if(aZ.powerModem.isPowerModemEnabled){aZ.ipv4Type=RAINIER.ui.common.strings.wanType[aZ.powerModem.dslSettings.wanType]}if(L.wanStatus.detectedWANType==="PPPoE"||L.wanStatus.detectedWANType==="PPTP"||L.wanStatus.detectedWANType==="L2TP"){A.find("#ppp-status").show();aZ.wanStatus.currentState=RAINIER.ui.common.strings.wanStatus[aZ.wanStatus.state]||RAINIER.ui.common.strings.wanStatus[L.wanStatus.wanStatus]}if(L.wanStatus.wanIPv6Status==="Connected"){aZ.ipv6Type=RAINIER.ui.common.strings.wanIpv6Type[L.wanStatus.wanIPv6Connection.wanType];if(L.wanStatus.wanIPv6Connection.wanType==="DHCPv6"){if(aZ.wanStatus.wanIPv6Connection.networkInfo.dhcpLeaseMinutes===1){A.find("#ipv6-lease-mins").html(RAINIER.ui.common.strings.minute)}else{A.find("#ipv6-lease-mins").html(RAINIER.ui.common.strings.minutes)}}else{A.find("#ipv6-lease-mins").empty()}if(V.isRouter5Supported){var aT=aZ.wanStatus.lanPrefixAddress;if(!aT&&aZ.wanStatus.wanIPv6Connection.networkInfo){aT=aZ.wanStatus.wanIPv6Connection.networkInfo.lanPrefixAddress}if(aZ.ipv6.ipv6rdTunnelSettings){aZ.ipv6.ipv6rdTunnelSettings.prefix=aT}else{aZ.ipv6.ipv6rdTunnelSettings={prefix:aT}}}}else{aZ.ipv6Type=RAINIER.ui.common.strings.wanStatus[L.wanStatus.wanIPv6Status]}switch(L.ports.wanPortConnection){case"10Gbps":aZ.gbpsPort=10;aZ.internetGbps="X";break;case"5Gbps":aZ.gbpsPort=5;aZ.internetGbps="X";break;case"2.5Gbps":aZ.gbpsPort=2.5;aZ.internetGbps="X";break;case"1Gbps":aZ.internetGbps="X";break;case"100Mbps":aZ.internet100="X";break;case"10Mbps":aZ.internet100="X";break}if(aZ.gbpsPort){aZ.gbpsPortText=RAINIER.ui.common.strings.templatedPortSpeed.Gbps.format(aZ.gbpsPort)}aI.find("tr.port").remove();for(aV=0;aV<L.ports.lanPortConnections.length;aV++){aZ["port"+aV+"_1gbps"]="";aZ["port"+aV+"_100"]="";switch(L.ports.lanPortConnections[aV]){case"1Gbps":aZ["port"+aV+"_1gbps"]="X";break;case"100Mbps":aZ["port"+aV+"_100"]="X";break;case"10Mbps":aZ["port"+aV+"_100"]="X";break}if(RAINIER.network.isLinkAggregationPresent()){aY=_.contains(L.linkAggregation.aggregatedPorts,aV);if(L.linkAggregation.isEnabled&&aY&&aZ["port"+aV+"_1gbps"]!=="X"){aW=false}}}for(aV=0;aV<L.ports.lanPortConnections.length;aV++){if(RAINIER.network.isLinkAggregationPresent()){aY=_.contains(L.linkAggregation.aggregatedPorts,aV);if(L.linkAggregation.isEnabled&&aY&&aW){aZ["port"+aV+"_1gbps"]="";aZ["port"+aV+"_100"]="";aZ["port"+aV+"_linkagg"]="X"}}aI.append(P.format(aV+1,aV));if(RAINIER.network.isLinkAggregationPresent()&&!aY){aI.find('[name="port'+aV+'_linkagg"]').addClass("not-aggregated")}}if((RAINIER.shared.util.areServicesSupported(["/jnap/wirelessap/WirelessAP3"])&&!RAINIER.shared.util.areServicesSupported(["/jnap/wirelessap/WirelessAP4"]))||(RAINIER.shared.util.areServicesSupported(["/jnap/wirelessap/WirelessAP4"])&&L.wireless.isBandSteeringSupported)){aZ.wireless=$.extend(true,{},L.wireless);aZ.wireless.isBandSteeringEnabled=(aZ.wireless.isBandSteeringEnabled)?RAINIER.ui.common.strings.enabled:RAINIER.ui.common.strings.disabled}else{A.find(".bandSteeringInfo").hide()}RAINIER.binder.toDom(aZ,$("#status-report-content"),{},null,true);A.find(".radioInfoReport").remove();aU.isBandSteeringEnabled=false;$.each(L.wireless.radios,function(){a0=RAINIER.shared.util.getLabeledRadio(aU,this.radioID);var a2=symmetryUtil.wireless.lookupChannelDataByChannel(a0.settings.channel,a0.band);if(a0.settings.channel===0){a0.settings.channel=RAINIER.ui.common.strings.auto}if(a2.dfs){a0.settings.channel+=" (DFS)"}a0.settings.isEnabled=a0.settings.isEnabled?RAINIER.ui.common.strings.enabled:RAINIER.ui.common.strings.disabled;a0.settings.channelWidth=RAINIER.ui.common.strings.wirelessChannelWidth[a0.settings.channelWidth];a0.settings.security=RAINIER.ui.common.strings.wirelessSecurity[a0.settings.security];var a1=RAINIER.ui.template.createBlock(an,a0,aQ);A.find("#bandSteeringEnabled").after(a1)});A.find("[tooltip]").each(function(){$(this).attr("tooltip",$(this).text())});RAINIER.ui.tooltip.add(A.find("[tooltip]"),"top")}function aN(){function aT(){ap();RAINIER.ui.hideWaiting()}RAINIER.ui.showWaiting();RAINIER.ui.clearTbl(ab);RAINIER.ui.clearTbl(Z);A.find("#lan-ports-wrapper").empty();var aU=RAINIER.jnap.Transaction({onComplete:function(){if(RAINIER.network.isPowerModemSupported()){aP(aT)}else{aT()}}});au(aU);aU.send()}function aC(){function aT(){var aU=RAINIER.jnap.Transaction({onComplete:i.curry(RAINIER.ui.hideWaiting)});aU.add({action:"/jnap/locale/GetTimeSettings",data:{},cb:function(aV){if(aV.result==="OK"){L.time=aV.output||{}}else{}}});aU.add({action:"/jnap/router/GetDHCPClientLeases",data:{},cb:function(aV){if(aV.result==="OK"){L.dhcpLease=aV.output||{}}else{}}});aU.send()}RAINIER.ui.showWaiting();RAINIER.ui.clearTbl(s);RAINIER.deviceManager.getDevices({threshold:-1,exclusions:{excludeAuthority:true},cb:aT})}function aj(){A.find("#refresh-status").click(function(){aN()});A.find("#open-status").click(function(){al(false)});A.find("#print-status").click(function(){al(true)});A.find("#open-dhcpclienttable").click(function(){aG.show();aC()});A.find("#ppp-connect").click(D);A.find("#ppp-disconnect").click(l);n.find(".refresh").click(function(){aC()});n.find(".cancel, .close-button").click(function(){aG.close();RAINIER.ui.clearTbl(s)})}function h(){ap();aj();if(RAINIER.network.isBridgeMode()){A.find("#devices-sub-tab").remove();A.find("#status-devices").remove();A.find("#report-sub-tab").click()}}function T(aX,aU,aT){var aV=$.extend(true,aU,{name:aU.friendlyName()});if(aV.ipAddress){var aW=RAINIER.ui.template.createBlock(aT,aV);aX.append(aW);RAINIER.util.trapEnter(aX.find("input[type=text]"))}}function ae(aU){var aT=aU.connections();if(aT.length>0){aU.macAddress=aT[0].macAddress;aU.ipAddress=aT[0].ipAddress;aU.ipv6Address=aT[0].ipv6Address;if(aT[0].wireless){aU.netType=RAINIER.ui.common.strings.netType.wireless}else{aU.netType=RAINIER.ui.common.strings.netType.lan}}}function al(aU){var aY=null,aW=window.open("/ui/dynamic/applets/troubleshooting/status-report.html"),aV,aX="",aT="";if(d!=="status-report"){aV=A.find("#devices-wrapper").parent().clone();aY=S.find("#device-status-report-title").text()}else{aV=A.find("#status-report-content").parent().clone();aY=S.find("#router-status-report-title").text()}$.ajax({url:"/ui/static/cache/applets/troubleshooting/css/troubleshooting-print.css",success:function(aZ){aT=aZ;aX+='<html dir="'+RAINIER.ui.getDirection()+'"><head>';aX+='<style type="text/css">'+aT+"</style>";aX+="<title>"+aY+"</title>";aX+="</head><body>";aX+='<article id="troubleshooting-applet">';if(d!=="status-report"){aX+='<div id="status-devices" class="print">'}aX+=aV.html();if(d!=="status-report"){aX+="</div>"}aX+="</article>";aX+="</body></html>";setTimeout(function(){o(aW,aX,aU)},500)}})}function e(){var aV,aU;function aT(){var aW=L.wanStatus.state||L.wanStatus.wanStatus,aX;af(null,function(aY){if(aY.result==="OK"){aX=aY.output.wanStatus;if(aX&&aX!==aW&&aX!=="Connecting"){clearInterval(aU);L.wanStatus=aY.output;aN();G()}else{if(aX==="Connecting"){S.find('label[name="wanStatus.currentState"]').text("Connecting")}}}});if(aV.getElapsedTimeMs()>av){clearInterval(aU);aN();G()}}aV=new RAINIER.util.timer();aV.start();aU=setInterval(aT,3000)}function D(){RAINIER.ui.showWaiting();RAINIER.jnap.send({action:"/jnap/router/ConnectPPPWAN",data:{},cb:function(aT){if(aT.result==="OK"){e()}else{}}})}function l(){RAINIER.ui.showWaiting();RAINIER.jnap.send({action:"/jnap/router/DisconnectPPPWAN",data:{},cb:function(aT){if(aT.result==="OK"){e()}else{}}})}function aS(aT){af(aT,function(aU){if(aU.result==="OK"){L.wanStatus=aU.output||{}}});if(V.isCore4Supported){aT.add({action:"/jnap/core/GetDataUploadUserConsent",data:{},cb:function(aU){if(aU.result==="OK"){L.dataUpload=aU.output||{}}else{}}})}}function H(){var aX={validationType:"domainOrIpAddress",whiteSpace:false},aV={errors:[{test:RAINIER.ui.validation.tests.isEmail,when:false,message:RAINIER.ui.validation.strings.invalidEmailAddress}]},aW=X.find("#ping-address"),aU=X.find("#trace-address"),aT={};RAINIER.util.trapEnter("#upload-configuration");aT.ping=r($.extend(true,{},aX,{els:aW,groupContainer:"#ping-ipv4"}));aT.trace=r($.extend(true,{},aX,{els:aU,groupContainer:"#trace-route"}));aT.shareEmail=r($.extend(true,{},aV,{els:aR.find("#send-router-info")}));O.diagnostics=aT}function ai(){return O.diagnostics.ping.isValid(true)}function G(){RAINIER.binder.toDom(L.dataUpload,S.find("#diagnostics-info"),{});RAINIER.binder.toDom(L.wanStatus,S.find("#router-address"),{});if(L.wanStatus.wanStatus!=="Connected"){S.find("#router-address #ip-addr").text("0.0.0.0")}if(L.wanStatus.wanIPv6Status!=="Connected"){S.find("#router-address #ipv6-addr").text("")}if($.cookie("user-auth-token")){X.find("#router-configuration #backup-user-auth-token").attr("value",$.cookie("user-auth-token"));X.find("#router-configuration #backup-admin-auth").detach();Q.find("#restore-user-auth-token").attr("value",$.cookie("user-auth-token"));Q.find("#restore-admin-auth").detach()}else{X.find("#router-configuration #backup-admin-auth").attr("value",$.cookie("admin-auth"));X.find("#router-configuration #backup-user-auth-token").detach();Q.find("#restore-admin-auth").attr("value",$.cookie("admin-auth"));Q.find("#restore-user-auth-token").detach()}}function N(){return(RAINIER.network.getCurrentWanType()==="DHCP")}function t(){X.find("#restore-previous-firmware").click(w.onRestorePreviousFirmware);if(!N()){X.find("#renew-ip").prop("disabled","disabled").addClass("disabled");X.find("#renew-ipv6").prop("disabled","disabled").addClass("disabled")}else{X.find("#renew-ip").click(function(){aD("RenewDHCPWANLease")});if(V.isRouter5Supported&&L.router5IPv6.wanType==="Pass-through"){X.find("#renew-ipv6").prop("disabled","disabled").addClass("disabled")}else{X.find("#renew-ipv6").click(function(){aD("RenewDHCPIPv6WANLease")})}}X.find(".reboot-router").click(w.onReboot);X.find("#factory-reset").click(w.onFactoryReset);X.find("#ping-ipv4 #start-ping").click(am);at.find(".close-button").click(function(){v.close()});RAINIER.util.trapEnter("#ping-address",am);RAINIER.util.trapEnter("#trace-address",p);at.find("#stop-ping").click(f);X.find("#trace-route #start-trace").click(p);K.find(".close-button").click(function(){a.close()});K.find("#stop-trace").click(az);if(Q.find("#upload-configuration").attr("disabled")){X.find("#router-configuration #restore").attr("disabled","disabled");X.find("#router-configuration #backup-config").attr("disabled","disabled")}X.find("#router-configuration #restore").click(function(){j=true;aF.show()});Q.find("#start-to-restore").click(w.onRestoreBackup);Q.find(".close-button").click(function(){aF.close()});Q.find("#upload-configuration-button").click(function(){if(!$.browser.msie){Q.find("#upload-configuration").click()}});if($.browser.msie){Q.find("#upload-configuration").hover(function(){Q.find("#upload-configuration-button").addClass("hover")},function(){Q.find("#upload-configuration-button").removeClass("hover")});Q.find("#upload-configuration").mousedown(function(){Q.find("#upload-configuration-button").addClass("active")});Q.find("#upload-configuration").mouseup(function(){Q.find("#upload-configuration-button").removeClass("active")});Q.find("#upload-configuration").mouseout(function(){Q.find("#upload-configuration-button").removeClass("active")})}Q.find("#upload-configuration").change(function(){if($(this).val()){Q.find("#start-to-restore").removeAttr("disabled");var aT=$(this).val().replace(/^.*[\\\/]/,"");Q.find("#upload-file-name").text(aT)}else{Q.find("#start-to-restore").attr("disabled","disabled")}});Q.find("#restore-form").submit(function(){if(ao){ao=false;return true}return false});$("#form-target").load(function(){var aV=this.contentWindow.document.body.innerHTML,aU=$(aV),aW=aU?aU.text():"[no response]",aX=RAINIER.util.parseJSON(aW),aT="2123";console.warn("JCGI call complete - response: "+aU.text());if(aX){aT=aX.result}if(aT==="OK"){if(j===true){RAINIER.event.connect("router.interruptionCompleted",function(){RAINIER.network.signOut()});RAINIER.connect.handleSideEffects(["DeviceRestart"]);RAINIER.ui.showMasterWaiting()}}else{RAINIER.ui.dialogError({result:aT,action:"JCGI return: "+aW})}});aR.find(".close-button").click(W.close);aR.find("button").click(ak);S.find("#success-share-diagnostics .close").click(y.close);S.find("#share-info").click(function(){W.show()})}function aL(){ao=true;Q.find("#restore-form").submit()}function u(){G();t();H();if(V.isDiagnostics3Supported){S.find("#diagnostics-info").removeClass("hidden")}if(V.isCore4Supported){S.find("#auto-upload-div").removeClass("hidden");S.find("#diagnostics-upload").change(function(){RAINIER.ui.showWaiting();RAINIER.jnap.send({action:"/jnap/core/SetDataUploadUserConsent",data:{userConsent:$(this).prop("checked")},cb:function(aT){RAINIER.ui.wait(false);if(aT.result!=="OK"){}}})})}if(RAINIER.network.isBehindNode()&&!V.isNodesRebootSupported){S.find("#reboot").hide()}}function ak(){var aU="/jnap/diagnostics/SendSysinfoEmail",aT={addressList:["sysinfoupload@belkin.com"]},aV=$("#send-router-info").val();if(aV){aT.addressList.push(aV)}if(!O.diagnostics.shareEmail.isValid(true)){return}W.close();RAINIER.ui.showWaiting();RAINIER.jnap.send({action:aU,data:aT,cb:function(aW){if(aW.result==="OK"){y.show()}else{if(RAINIER.ui.validation.strings.errors[aW.result]){RAINIER.ui.alert("",RAINIER.ui.validation.strings.errors[aW.result])}else{RAINIER.ajax().executeDefaultJnapErrorHandler(aW,aU)}}},disableDefaultJnapErrHandler:true,timeoutMs:60000})}function I(){var aV,aU;function aT(){af(null,function(aW){if(aW.result==="OK"){if(aW.output.wanStatus&&(aW.output.wanStatus==="Connected"||aW.output.wanIPv6Status==="Connected")){clearInterval(aU);L.wanStatus=aW.output;setTimeout(function(){aN();G();RAINIER.event.fire("connection.enableCheck");RAINIER.ui.hideWaiting()},10000)}}});if(aV.getElapsedTimeMs()>av){clearInterval(aU);RAINIER.event.fire("connection.enableCheck");RAINIER.ui.hideWaiting()}}aV=new RAINIER.util.timer();aV.start();aU=setInterval(aT,3000)}function aD(aT){aK({msg:S.find("#renewWANIp").html(),onSubmit:function(){aH(aT)}})}function aH(aT){if(aT==="RenewDHCPWANLease"){S.find("#router-address #ip-addr").text("0.0.0.0")}if(aT==="RenewDHCPIPv6WANLease"){S.find("#router-address #ipv6-addr").text("")}RAINIER.ui.showWaiting();RAINIER.event.fire("connection.disableCheck");RAINIER.jnap.send({action:"/jnap/router/"+aT,data:{},cb:function(aU){if(aU.result!=="OK"){}I()}})}function aw(){RAINIER.jnap.send({action:"/jnap/diagnostics/RestorePreviousFirmware",data:{},cb:function(aT){if(aT.result==="OK"){RAINIER.connect.startInterruptionPolling(function(){RAINIER.network.signOut()})}else{}},disableDefaultRebootErrHandler:true,disableDefaultAjaxErrHandler:true})}function J(){function aT(){RAINIER.ui.hideMasterWaiting();RAINIER.event.disconnect("router.interruptionCompleted",aT)}RAINIER.jnap.send({action:"/jnap/core/Reboot",data:{},cb:function(aU){if(aU.result==="OK"){RAINIER.connect.startInterruptionPolling(aT)}else{}},disableDefaultRebootErrHandler:true,disableDefaultAjaxErrHandler:true})}function x(){RAINIER.jnap.send({action:"/jnap/core/FactoryReset",data:{},cb:function(aT){if(aT.result==="OK"){RAINIER.event.connect("router.interruptionCompleted",function(){RAINIER.network.signOut()});RAINIER.ui.showMasterWaiting()}else{}}})}function c(){RAINIER.jnap.send({action:"/jnap/diagnostics/GetTracerouteStatus",data:{},cb:function(aT){if(aT.output){g.text(aT.output.tracerouteLog);if(!aT.output.isRunning){}else{clearTimeout(q);q=setTimeout(c,100)}}else{}}})}function aA(){clearTimeout(q);q=null;az();g.empty()}function am(){if(ai()){X.find("#ping-ipv4 #start-ping").attr("disabled","true");var aW=RAINIER.binder.fromDom($("#ping-ipv4"));var aV={};aV.host=aW.pingAddress.host;aV.packetSizeBytes=32;var aT=(aW.pingAddress.pingCount==="five")?5:(aW.pingAddress.pingCount==="ten")?10:(aW.pingAddress.pingCount==="fifteen")?15:0;if(aT>0){aV.pingCount=aT}var aU="/jnap/diagnostics/StartPing";RAINIER.jnap.send({action:aU,data:aV,cb:function(aX){if(aX&&aX.result==="OK"){ay.empty();v.show()}else{if(aX&&aX.result&&aX.result!=="_AjaxError"&&RAINIER.ui.validation.strings.errors[aX.result]){RAINIER.ui.alert("",RAINIER.ui.validation.strings.errors[aX.result])}else{RAINIER.ajax().executeDefaultJnapErrorHandler(aX,aU)}}X.find("#ping-ipv4 #start-ping").removeAttr("disabled")},disableDefaultJnapErrHandler:true})}}function f(){at.find("#stop-ping").attr("disabled","true");RAINIER.jnap.send({action:"/jnap/diagnostics/StopPing",data:{},cb:function(aT){}});at.find("#stop-ping").removeAttr("disabled")}function m(){RAINIER.jnap.send({action:"/jnap/diagnostics/GetPingStatus",data:{},cb:function(aT){if(aT.output){ay.text(aT.output.pingLog);if(!aT.output.isRunning){}else{setTimeout(m,100)}}else{}}})}function E(){f();ay.empty()}function ax(){return O.diagnostics.trace.isValid(true)}function p(){if(ax()){X.find("#trace-route #start-trace").attr("disabled","true");var aV=RAINIER.binder.fromDom($("#trace-route"));var aU={host:aV.traceAddress.host};var aT="/jnap/diagnostics/StartTraceroute";RAINIER.jnap.send({action:aT,data:aU,cb:function(aW){if(aW&&aW.result==="OK"){g.empty();a.show()}else{if(aW&&aW.result&&aW.result!=="_AjaxError"&&RAINIER.ui.validation.strings.errors[aW.result]){RAINIER.ui.alert("",RAINIER.ui.validation.strings.errors[aW.result])}else{RAINIER.ajax().executeDefaultJnapErrorHandler(aW,aT)}}X.find("#trace-route #start-trace").removeAttr("disabled")},disableDefaultJnapErrHandler:true})}}function az(){at.find("#stop-trace").attr("disabled","true");RAINIER.jnap.send({action:"/jnap/diagnostics/StopTraceroute",data:{},cb:function(aT){}});at.find("#stop-trace").removeAttr("disabled")}function aa(aT){var aU={firstEntryIndex:1,entryCount:255};aT.add({action:"/jnap/routerlog/GetLogSettings",data:{},cb:function(aV){if(aV.result==="OK"){L.logs.isLoggingEnabled=aV.output.isLoggingEnabled}}});aT.add({action:"/jnap/routerlog/GetIncomingLogEntries",data:aU,cb:function(aV){if(aV.result==="OK"){L.logs.incoming=aV.output}else{}}});aT.add({action:"/jnap/routerlog/GetOutgoingLogEntries",data:aU,cb:function(aV){if(aV.result==="OK"){L.logs.outgoing=aV.output}else{}}});aT.add({action:"/jnap/routerlog/GetSecurityLogEntries",data:aU,cb:function(aV){if(aV.result==="OK"){L.logs.security=aV.output}else{}}});aT.add({action:"/jnap/routerlog/GetDHCPLogEntries",data:aU,cb:function(aV){if(aV.result==="OK"){L.logs.dhcp=aV.output}else{}}})}function B(){var aT=null,aU;U=Y.find(".panel-form").clone();console.warn(["logTbl",U]);Y.find("#enable-logs").attr("checked",L.logs.isLoggingEnabled);if(L.logs.isLoggingEnabled){aT=Y.find("#log-content #incoming");$.each(L.logs.incoming.entries,function(){aU=this;aT.after("<tr><td>{source}</td><td></td><td>{destinationPort}</td><td></td></tr>".formatObj(aU))});aT=Y.find("#log-content #outgoing");$.each(L.logs.outgoing.entries,function(){aU=this;if(aU.service){aU.destinationPort=aU.service}aT.after("<tr><td>{source}</td><td></td><td>{destination}</td><td></td><td>{destinationPort}</td></tr>".formatObj(aU))});aT=Y.find("#log-content #security");$.each(L.logs.security.entries,function(){aU=this;if(aU.authSucceeded){aU.authResult=RAINIER.ui.validation.strings.successful}else{aU.authResult=RAINIER.ui.validation.strings.failed}aT.after("<tr><td>{ipAddress}</td><td></td><td>{macAddress}</td><td></td><td>{timestamp}</td><td></td><td>{authResult}</td></tr>".formatObj(aU))});aT=Y.find("#log-content #dhcp");$.each(L.logs.dhcp.entries,function(){aT.after("<tr><td>{ipAddress}</td><td></td><td>{macAddress}</td><td></td><td>{timestamp}</td><td></td><td>{messageType}</td></tr>".formatObj(this))})}}function aJ(){if(L.logs.isLoggingEnabled){RAINIER.ui.showWaiting();Y.find(".panel-form").html(U.html());var aT=RAINIER.jnap.Transaction({onComplete:function(){RAINIER.ui.hideWaiting();B()}});aa(aT);aT.send()}}function ac(){RAINIER.ui.showWaiting();Y.find(".panel-form").html(U.html());RAINIER.jnap.send({action:"/jnap/routerlog/DeleteLogEntries",data:{},cb:function(aT){if(aT.result!=="OK"){}RAINIER.ui.hideWaiting()}})}function F(){Y.find("#refresh-logs").click(function(){aJ()});Y.find("#open-logs").click(function(){C(false)});Y.find("#print-logs").click(function(){C(true)});Y.find("#clear-logs").click(function(){ac()})}function aB(){B();F();Y.find("#enable-logs").click(b)}function C(aU){var aW=window.open("/ui/dynamic/applets/troubleshooting/status-report.html"),aV,aX="",aT="";$.ajax({url:"/ui/static/cache/applets/troubleshooting/css/troubleshooting-print.css",success:function(aY){aT=aY;aV=Y.find(".panel-form").clone();aX+='<html dir="'+RAINIER.ui.getDirection()+'"><head>';aX+="<title>"+RAINIER.ui.common.strings.troubleshooting.routerLogs+"</title>";aX+='<style type="text/css">'+aT+"</style>";aX+="</head><body>";aX+='<article id="troubleshooting-applet">';aX+=aV.html();aX+="</article>";aX+="</body></html>";setTimeout(function(){o(aW,aX,aU)},500)}})}function ar(){RAINIER.event.disconnect("connection.enableCheck",ar);setTimeout(aJ,4000)}function b(){var aT={isLoggingEnabled:Y.find("#enable-logs").is(":checked")};RAINIER.ui.showWaiting();RAINIER.jnap.send({action:"/jnap/routerlog/SetLogSettings",data:aT,cb:function(aU){if(aU.result==="OK"){L.logs.isLoggingEnabled=aT.isLoggingEnabled;if(L.logs.isLoggingEnabled){RAINIER.event.connect("connection.enableCheck",ar)}RAINIER.ui.hideWaiting()}else{}}})}function aq(){function aT(){h();u();aB();RAINIER.event.fire("applet.loaded")}if(RAINIER.network.isPowerModemSupported()){aP(aT)}else{aT()}}function k(){if(RAINIER.network.isBehindNode()){RAINIER.deviceManager.stopUpdateNodeConnections()}RAINIER.event.disconnect("applet.unloaded",k)}function ah(){RAINIER.deviceManager.getDevices({cb:function(aV){L.devices=aV}});if(RAINIER.network.isBehindNode()){RAINIER.deviceManager.updateNodeConnections(function(){RAINIER.deviceManager.getDevices(aM,{excludeAuthority:true},-1)})}RAINIER.event.connect("applet.unloaded",k);RAINIER.event.connect("tab.changed",function(aV,aW){switch(aW.destTabId){case"diagnostics":RAINIER.ui.fixIeForm("#"+aW.destTabId);break}});var aU=RAINIER.ui.tabs.init({fireEvents:true,initialTab:$.cookie("initial-tab")});aU.connect(function(aW,aV){if(aV.type==="subtab"){d=aV.destTabId}});v=RAINIER.ui.dialog(at,{onShow:m,onClose:E});a=RAINIER.ui.dialog(K,{onShow:c,onClose:aA});aF=RAINIER.ui.dialog(Q,{});W=RAINIER.ui.dialog(aR);y=RAINIER.ui.dialog(S.find("#success-share-diagnostics"));V.isLocale2Supported=RAINIER.shared.util.areServicesSupported(["/jnap/locale/Locale2"]);V.isRouter5Supported=RAINIER.shared.util.areServicesSupported(["/jnap/router/Router5"]);V.isDiagnostics3Supported=RAINIER.shared.util.areServicesSupported(["/jnap/diagnostics/Diagnostics3"]);V.isCore4Supported=RAINIER.shared.util.areServicesSupported(["/jnap/core/Core4"]);V.isNodesRebootSupported=RAINIER.shared.util.areServicesSupported(["/jnap/nodes/setup/Setup3"]);var aT=RAINIER.jnap.Transaction({onComplete:aq});au(aT);aS(aT);aa(aT);aT.send()}ah()}());