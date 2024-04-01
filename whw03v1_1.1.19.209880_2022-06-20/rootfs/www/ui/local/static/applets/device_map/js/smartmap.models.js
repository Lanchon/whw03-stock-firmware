window.RAINIER=window.RAINIER||{};RAINIER.applets=RAINIER.applets||{};RAINIER.applets.networkmap=RAINIER.applets.networkmap||{};RAINIER.applets.networkmap.Models=(function(){var a=Backbone.Model.extend({initialize:function(d){this.id=d.deviceID()},equals:function(d){if(_.isEqual(this.data,d)){return true}return false},get:function(e){var d;switch(e){case"id":case"modelID":d=this.attributes.deviceID();break;default:d=Backbone.Model.prototype.get.apply(this,arguments);break}return d},update:function(d){this.set(d);this.events.trigger("update",{});this.events.trigger("change",{})}});var b=a.extend({signalThresholdsSNR:[40,33,25,15,10],signalThresholdsRSSI:[-50,-60,-70,-80,-90],userDeviceName:"userDeviceName",userDeviceType:"userDeviceType",getConnectionType:function(){var d=_.intersection(["guest","wirelessTwo","wirelessFive","wirelessFive-2","lan","offline"],this.getFilters());if(d.length>0){return d[0]}else{return""}},getDeviceTypeFilter:function(){var d="";switch(this.attributes.deviceType()){case"Computer":case"desktop-mac":case"desktop-pc":case"laptop-mac":case"laptop-pc":case"server-mac":case"server-pc":d="computer";break;case"Phone":case"generic-cellphone":case"smartphone":case"voip-phone":case"tablet-ereader":case"tablet-pc":d="mobile";break;case"Printer":case"printer-inkjet":case"printer-laser":case"printer-photo":d="printer";break;default:d="other";break}return d},getFilters:function(){var d=[];if(this.attributes.isOnline()){if(this.attributes.isGuest()){d.push("guest")}else{d.push("online")}}else{d.push("offline")}if(this.attributes.data.connections.length>0){$.each(this.attributes.data.connections,function(e,f){if(f.wireless){d.push("wireless");if(f.wireless.band==="5GHz"){if(RAINIER.applets.networkmap.Loader.hasSecondarySteeredBand()&&RAINIER.applets.wireless.isSecondarySteeredBand(f.wireless)){d.push("wirelessFive-2")}else{d.push("wirelessFive")}}else{d.push("wirelessTwo")}}else{d.push("lan")}})}d.push(this.getDeviceTypeFilter());return d},getSignalDecibels:function(){var d=null,e;if(this.attributes.data.connections.length>0){_.each(this.attributes.data.connections,function(f){if(f.wireless){if(_.has(f.wireless,"signalDecibels")){e=parseInt(f.wireless.signalDecibels);d=_.isNull(d)?e:Math.max(d,e)}}},this)}return d},getSignalQuartile:function(){var e=0,g=this.getSignalDecibels();if(_.isNull(g)){return 0}var f=(g>0)?this.signalThresholdsSNR:this.signalThresholdsRSSI;var d=_.find(f,function(h){return g>h});if(!_.isUndefined(d)){e=4-_.indexOf(f,d)}return e}});var c=Backbone.Collection.extend({model:b,initting:true,countGuestDevices:null,countOnlineDevices:null,currentFilterSetName:null,excludeAuthorityFromFilter:false,bandwidthReportRunning:false,bandwidthReportTmr:null,getStatisticsByDeviceUrl:"/jnap/networktraffic/GetStatisticsByDevice",filterGuides:{device:["computer","mobile","printer","other"],connection:["lan","wirelessTwo","wirelessFive","wirelessFive-2","offline"]},filterSets:{},paging:{perPage:16},statisticsPollMs:5000,timestamp:null,type:"get",initialize:function(){var d=this;d.on("add",d.onAdd);if(!RAINIER.applets.networkmap.Loader.hasSecondarySteeredBand()){$.each(d.filterGuides.connection,function(e,f){if(f==="wirelessFive-2"){delete d.filterGuides.connection[e];return false}})}_.bindAll(d,"_updateDeviceList")},changeFilters:function(e,f){var d=true;this.filterSets[e]=this.filterSets[e]||[];if(e&&f){if(_.indexOf(this.filterSets[e],f)===-1){this.filterSets[e].push(f)}else{this.filterSets[e]=_.without(this.filterSets[e],f)}}if(e!=="guest-network"&&!this.initting&&(_.intersection(this.filterGuides.device,this.filterSets[e]).length===0||_.intersection(this.filterGuides.connection,this.filterSets[e]).length===0)){this.filterSets[e].push(f);d=false}else{this.updateFilteredCollection(e);this.updatePaging();if(e!=="guest-network"){$.cookie("smartmap-filter-set",e,{expires:null,path:"/"});$.cookie("smartmap-filter-values",this.filterSets[e].toString(),{expires:null,path:"/"})}this.currentFilterSetName=e}return d},clearFilterSet:function(d){this.filterSets[d]=[]},createFilterSet:function(d,e){if(!$.isArray(e)){e=[e]}this.filterSets[d]=e},getAuthority:function(){var d=null;$.each(this.models,function(e,f){if(f.attributes.isAuthority()){d=f;return false}});return d},endStatsTracking:function(d){RAINIER.applets.networkmap.App.deviceCollection.bandwidthReportRunning=false;if(this.bandwidthReportTmr!==null){clearTimeout(this.bandwidthReportTmr)}this.bandwidthReportTmr=null;var e=this.getStatisticsByDeviceUrl;RAINIER.jnap.send({action:e,data:{},cb:d})},beginStatsTracking:function(){var g=this,f=g.statisticsPollMs;function d(j){return(Math.round((j*8))/1000000)}function i(j){return j/(f/1000)}function h(m){var n={numDevices:0,devices:[],totals:{totalBytesPerSecond:0,totalMBitsPerSecond:0},sent:{totalBytesPerSecond:0,totalMBitsPerSecond:0},received:{totalBytesPerSecond:0,totalMBitsPerSecond:0}},l,k=0,j=0;if(m.ipStats&&m.ipStats.length>0){$.each(m.ipStats,function(o,p){RAINIER.deviceManager.getDeviceByIPAddress(function(q){l=q;if(l&&!l.isAuthority()){l.sent={val:parseInt(p.bytesSent,10),totalBytesPerSec:0,totalMBitsPerSec:0};l.received={val:parseInt(p.bytesReceived,10),totalBytesPerSec:0,totalMBitsPerSec:0};l.totals={val:l.sent.val+l.received.val,totalBytesPerSec:0,totalMBitsPerSec:0};k=d(l.totals.val);l.totals.val=i(l.totals.val);j=i(k).round(2);l.sent.totalBytesPerSec=i(l.sent.val);l.sent.totalMBitsPerSec=d(l.sent.totalBytesPerSec).round(2);l.received.totalBytesPerSec=i(l.received.val);l.received.totalMBitsPerSec=d(l.received.totalBytesPerSec).round(2);l.totals.totalBytes=l.totals.val;l.totals.totalBytesPerSec=l.totals.val;l.totals.totalMBitsPerSec=j;n.sent.totalBytesPerSecond+=l.sent.totalBytesPerSec;n.sent.totalMBitsPerSecond+=d(l.sent.totalBytesPerSec);n.received.totalBytesPerSecond+=l.received.totalBytesPerSec;n.received.totalMBitsPerSecond+=d(l.received.totalBytesPerSec);n.totals.totalBytesPerSecond+=l.sent.totalBytesPerSec+l.received.totalBytesPerSec;n.totals.totalMBitsPerSecond+=j;n.devices.push(l)}else{console.warn("BW Rpt - Did not find IP: "+p.ipAddress)}if(o===m.ipStats.length-1){if(n.devices.length){n.numDevices=n.devices.length}else{}RAINIER.applets.networkmap.App.bandwidthView.showBandwidth(n)}},p.ipAddress)})}else{RAINIER.applets.networkmap.App.bandwidthView.showBandwidth(n)}}RAINIER.applets.networkmap.App.bandwidthView.open();RAINIER.applets.networkmap.App.deviceCollection.bandwidthReportRunning=true;var e="/jnap/networktraffic/BeginStatisticsTracking";RAINIER.jnap.send({action:e,data:{},cb:function(k,j){if(k.result==="OK"){g.bandwidthReportTmr=setTimeout(function(){if(RAINIER.applets.networkmap.App.deviceCollection.bandwidthReportRunning){g.endStatsTracking(function(n,m){var l=g.getStatisticsByDeviceUrl;if(n.result==="OK"){h(n.output)}else{RAINIER.applets.devicelist.foldSection(self.$el);RAINIER.ajax().executeDefaultJnapErrorHandler(n,l,m)}})}},f)}else{RAINIER.applets.networkmap.App.deviceCollection.bandwidthReportRunning=false;RAINIER.applets.devicelist.foldSection(self.$el);if(k.result==="ErrorStatisticsTrackingStarted"){RAINIER.applets.networkmap.App.bandwidthView.showAlreadyRunningError()}else{RAINIER.ajax().executeDefaultJnapErrorHandler(k,e,j)}}},disableDefaultJnapErrHandler:true})},getModelByID:function(e){var d=null;$.each(this.models,function(f,g){if(g.id===e){d=g;return}});return d},merge:function(e){var d=this;this.lastUpdate=new Date().getTime();$.each(e,function(f,g){$.extend(true,d.models[f].data,g.data)})},sync:function(h,g,d){var f=true,e=false;if(h==="read"){if(_.has(d,"update")&&d.update===true){f=false}this.trigger("request");if(f){RAINIER.deviceManager.getDevices({threshold:-1,doPollForChange:e,cb:this._updateDeviceList})}else{RAINIER.deviceManager.getDevices(this._updateDeviceList)}}else{}},updateFilteredCollection:function(d){var e=_.indexOf(this.filterSets[d],"guest")!==-1;if(!d||this.filterSets[d].length===0){this.filteredCollection=this.models}else{this.filteredCollection=_.filter(this.models,function(f){return this._meetsFilterCriteria(this.filterSets[d],f)},this)}this.filteredCollection=_.filter(this.filteredCollection,function(f){return(!RAINIER.applets.networkmap.App.deviceCollection.excludeAuthorityFromFilter||!f.attributes.isAuthority())&&(e||!f.attributes.isGuest())});if(!e){this.countOnlineDevices=this.filteredCollection.length}else{this.countGuestDevices=this.filteredCollection.length}},updatePaging:function(){var e=this.paging,d=this.filteredCollection;if(d){e.pageNumber=1;e.totalPages=Math.ceil(d.length/this.paging.perPage);if(e.totalPages===0){e.totalPages=1}}},_meetsFilterCriteria:function(e,g){var i=false,h=false,f=g.getFilters(),d=_.contains(f,"guest");if(e.length===1&&e[0]==="guest"){return d}if(_.intersection(e,this.filterGuides.device).length===0){i=true}if(_.intersection(e,this.filterGuides.connection).length===0){h=true}if(i&&h){return true}_.each(e,function(j){if(_.contains(f,j)){if(_.contains(this.filterGuides.device,j)){i=true}else{if(_.contains(this.filterGuides.connection,j)){h=true}}}},this);return i&&h},_updateDeviceList:function(d){if(d.length<this.length){this.reset(d)}else{this.add(d,{merge:true})}this.updateFilteredCollection(this.currentFilterSetName);this.updatePaging();this.trigger("sync");this.trigger("refresh")},onAdd:function(){this.lastUpdate=new Date().getTime();this.countGuestDevices=_.filter(this.models,function(d){return _.contains(d.getFilters(),"guest")},this).length}});return{Model:a,DeviceModel:b,deviceCollection:c}}());