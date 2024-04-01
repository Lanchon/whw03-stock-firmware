(function(a,b){if(typeof define==="function"&&define.amd){define(["jquery","lodash","punycode","./symmetry-jnap","./errorstring-mappings","./util-logging","./util-guest-access","./util-wireless","./util-wan","./util-monitors","./util-nodes","./util-firmware-update","./util-lan","./util-network-security"],b)}else{if(typeof module==="object"&&module.exports){module.exports=b(require("jquery"),require("lodash"),require("punycode"),require("./symmetry-jnap"),require("./errorstring-mappings"),require("./util-logging"),require("./util-guest-access"),require("./util-wireless"),require("./util-wan"),require("./util-monitors"),require("./util-nodes"),require("./util-firmware-update"),require("./util-lan"),require("./util-network-security"))}else{a.symmetryUtil=b(a.$,(a.lodash||a._),a.punycode,a.JNAP,a.errorStringMappings,a.utilLogging,a.utilGuestAccess,a.utilWireless,a.utilWAN,a.utilMonitors,a.utilNodes,a.utilFirmwareUpdate,a.utilLAN,a.utilNetworkSecurity)}}}(this,function(Q,at,ai,z,y,ah,s,X,S,n,F,U,an,ac){var ak;at.padEnd=at.padEnd||at.padRight;var T=["sunday","monday","tuesday","wednesday","thursday","friday","saturday"];var M=/[+-]\d{4}$/;var K=/\d+|[\u0660-\u0669]+/;var u=/ (AM|PM)\b/;var J=["sortWeight"];function e(av){av=av||"";var au=encodeURIComponent(av).match(/%[89ABab]/g);return av.length+(au?au.length:0)}function g(ax,au){var aw=ai.ucs2.decode(ax),ay=e(ax);for(var av=aw.length-1;av>=0&&ay>au;av--){aw.splice(av,1);ax=ai.ucs2.encode(aw);ay=e(ax)}return ax}function ad(au){return function(aw){aw.attr("maxlength",au);var av=function(){if(e(aw.val())>au){aw.val(g(aw.val(),au)).change()}};aw.keyup(av);aw.blur(av)}}function x(av){var au=av.split(".");return(((((parseInt(au[0],10)*256)+parseInt(au[1],10))*256)+parseInt(au[2],10))*256)+parseInt(au[3],10)}function aj(av){var au=av%256;at.range(0,3).forEach(function(){av=Math.floor(av/256);au=av%256+"."+au});return au}function I(av,au,aw){return x(av)>=x(au)&&x(av)<=x(aw)}function Y(ax,av,au){if(at.isEmpty(ax)){return false}if(!av){av=8}else{if(av<1||av>31){throw"Invalid minNetworkPrefixLength passed, must be between 1 and 31"}}if(!au){au=30}else{if(au<1||au>31){throw"Invalid maxNetworkPrefixLength passed, must be between 1 and 31"}}if(au<av){throw"maxNetworkPrefixLength cannot be less than minNetworkPrefixLength"}var ay=x(ax).toString(2),aw=ay.indexOf("0"),az=at.padEnd(at.repeat("1",aw),32,"0");if(ay!==az||aw<av||aw>au){return false}return true}function h(au){var av=at.padEnd(at.repeat("1",au),32,"0");return av.match(/.{1,8}/g).map(function(aw){return parseInt(aw,2)}).join(".")}function j(av){var au=x(av).toString(2).indexOf("0");if(!Y(av,1,31)){throw"Invalid subnet mask passed"}return au===-1?32:au}function aq(au){if(at.isDate(au)){return au}if(at.isEmpty(au)||!at.isString(au)){throw"routerTimeToDate - Need to pass in timeString or a Date obj"}if(M.test(au)){au=au.replace(/(..$)/,":$1")}return new Date(au)}function ab(au){return new Date(Date.UTC(au.getUTCFullYear(),au.getUTCMonth(),au.getUTCDate(),au.getUTCHours(),au.getUTCMinutes(),au.getUTCSeconds())+au.getTimezoneOffset()*60*1000)}function W(au){au=au.replace(M,"+0000");return ab(aq(au))}function i(au){var ax=new Date(),ay,av,aw;ax.setHours(au);av=ax.toLocaleTimeString();aw=av.match(K);if(aw&&aw.length){ay=aw[0];aw=av.match(u);if(aw&&aw.length){ay+=aw[0].toLowerCase()}}else{throw"Error attempting to call toLocaleTimeString, please verify that hour passed in is a # 0 - 23"}return ay}function c(au){au++;if(au>6){au=0}return au}function ag(au){var av=c(T.indexOf(au));return T[av]}function af(au){au--;if(au<0){au=6}return au}function p(au){var av=af(T.indexOf(au));return T[av]}function ae(av){var ax=av/1000,au;if(ax>=60){var ay=parseInt(ax/60),aw=at.round(ax%60,2);au=ay+"m "+(at.isNaN(aw)?0:aw)+"s"}else{au=at.round(ax,2)+"s"}return au}function V(au){return(new Date()).getTime()-au}function a(au){return ae(V(au))}function C(av,au){return av[T[au.getDay()]].split("")}function R(au){var av=at.union(at.map(au));return av.length===1&&at.uniq(av[0]).length===1}function D(au){return R(au)&&au.sunday[0]==="0"}function E(au){return R(au)&&au.sunday[0]==="1"}function d(au){return au>=30?1:0}function o(au){return au?30:0}function ar(aA,au,av){var aw,az=0,ax=d(au.getMinutes()),ay;au.setMinutes(o(ax));au.setSeconds(0);while(true){if(!aw||au.getHours()===0){aw=C(aA,au)}ay={date:at.clone(au),day:au.getDay(),hour:au.getHours(),minutes:o(ax),hourText:i(au.getHours()),isBlocked:aw[au.getHours()*2+ax]==="0"};if(!av(ay,az,ax)){break}ax++;if(ax>1){au.setUTCHours(au.getUTCHours()+1);az++;ax=0}}}function G(aB,az){var au,ay,aA=0,ax,av,aw;if(at.isEmpty(aB)){throw"getNextSchedulerEvent - Need to pass the schedule-JSON as first parameter"}if(!at.isDate(az)&&(!at.isString(az)||at.isEmpty(az))){throw"getNextSchedulerEvent - Need to pass the routerLocalTime as a String or Date as second parameter"}au=aq(az);ar(aB,at.clone(au),function(aD,aE,aC){if(ay===undefined){ay=aD.isBlocked}if(aE>0&&aC===0&&(aD.hour===0||aD.hour===12)){aA++}if(!ay&&!ax&&aD.isBlocked){ax=aD;ax.hourOffset=aE;ax.minutes=o(aC);ax.meridiemOffset=aA;aA=0}else{if((ax||ay)&&!av&&!aD.isBlocked){av=aD;av.hourOffset=aE;av.minutes=o(aC);av.meridiemOffset=aA}}if((ay&&av)||(ax&&av)||aE===168){return false}return true});aw={currentDay:au.getDay(),isCurrentlyBlocked:ay};if(ax||av){if(ax){aw.startBlock={day:ax.day,hour:ax.hour,hourOffset:ax.hourOffset,hourText:ax.hourText,minutes:ax.minutes,dayOfWeekShown:ax.meridiemOffset>1}}if(av){aw.endBlock={day:av.day,hour:av.hour,hourOffset:av.hourOffset,hourText:av.hourText,minutes:av.minutes,dayOfWeekShown:av.meridiemOffset>1}}}return aw}function H(ay,aw){var ax,aA=1,aB=[],av=new Date("2016-02-01T00:00:00-00:00"),au;if(at.isEmpty(ay)){throw"getScheduleRangesForWeek - Need to pass the schedule-JSON as first parameter"}if(aw&&!at.isString(aw)&&!at.isDate(aw)){throw"getScheduleRangesForWeek - Need to pass the routerLocalTime as a String or Date"}if(aw){au=aq(aw)}av=ab(av);ar(ay,av,function(aD,aE){if(aA!==aD.day){if(ax){ax.endHour=-1;ax.endMinutes=0;if(au&&au.getDay()===ax.day&&au.getHours()>=ax.startHour){ax.isRangeActive=true}aB.push(ax);ax=null}aA=aD.day}if(!ax&&aD.isBlocked){ax={day:aD.day,startHour:aD.hour,startMinutes:aD.minutes};if(au){ax.startDate=aD.date}}else{if(ax&&!aD.isBlocked){ax.endHour=aD.hour;ax.endMinutes=aD.minutes;if(au&&au.getDay()===ax.day&&au.getHours()>=ax.startHour&&au.getHours()<ax.endHour){ax.isRangeActive=true}aB.push(ax);ax=null}}if(aE===168){return false}return true});if(au){if(!R(ay)&&!at.compact(at.map(aB,"isRangeActive")).length){var aC,az;au=new Date(Date.UTC(av.getUTCFullYear(),av.getUTCMonth(),au.getDay(),au.getHours(),0,0)+av.getTimezoneOffset()*60*1000);aB.forEach(function(aD){if(aD.startDate<au){aD.startDate.setTime(aD.startDate.getTime()+168*60*60*1000)}});aC=at.sortBy(aB,"startDate");az=at.findIndex(aB,aC[0]);aB[az].isNextActiveRange=true}aB.forEach(function(aD){delete aD.startDate})}return aB}function f(az){var aI=[],aJ=[],aE=[],aA,au;var aC=H(az);function aF(aK){return aJ.indexOf(aK)===-1}function ay(aK){au=aD(aK);return aK.endHour===-1&&au!==-1}function av(aK){return aK.startHour===0&&aK.startMinutes===0&&aK.endHour===-1}function aH(aK){return aK.day<5&&aK.startHour>11&&ay(aK)}function ax(aK){return aK.day>4&&aK.startHour>11&&ay(aK)}function aw(aK,aL){return aF(aL)}aE.push({title:"Multiple All-day Blocked ranges",fnRule:av,requireMatches:true});aE.push({title:"Multiple Weekday, overlapping to next day, Blocked ranges",fnRule:aH,requireMatches:true});aE.push({title:"Multiple Weekend, overlapping to next day, Blocked ranges",fnRule:ax,requireMatches:true});aE.push({title:"Remaining Multiple and Unique Blocked ranges",sortWeight:3,fnRule:aw,requireMatches:false});function aD(aL,aO,aN){var aK;var aM={day:c(aL.day),startHour:0,startMinutes:0};if(aO){aM.endHour=aO;aM.endMinutes=aN}aK=at.findIndex(aC,aM);return aK!==-1&&aF(aK)&&aC[aK].endHour!==-1?aK:-1}function aB(aL){var aK=false;if(aA.startHour===aL.startHour&&aA.startMinutes===aL.startMinutes&&((aA.endHour===aL.endHour&&aA.endMinutes===aL.endMinutes)||(aA.endNextDay&&aL.endHour===-1))){aK=true;if(aA.endNextDay){au=aD(aL,aA.endHour,aA.endMinutes);if(au!==-1){aJ.push(au)}else{aK=false}}}return aK}function aG(aL){var aK;aC.forEach(function(aM,aN){if(aF(aN)&&aL.fnRule(aM,aN)){aJ.push(aN);aA={days:[T[aM.day]],startHour:aM.startHour,startMinutes:aM.startMinutes,endHour:aM.endHour,endMinutes:aM.endMinutes,endNextDay:aM.endHour===-1&&aM.startHour!==0,sortWeight:10};if(aA.endNextDay){au=aD(aM);if(au!==-1){aA.endHour=aC[au].endHour;aA.endMinutes=aC[au].endMinutes;aJ.push(au)}else{aA.endNextDay=false}}aC.forEach(function(aO,aP){if(aF(aP)&&aB(aO)){aJ.push(aP);aA.days.push(T[aO.day])}});if(!aL.requireMatches||aA.days.length>1){if(aA.endHour===-1){aA.endHour=24;aA.endMinutes=0}if(aA.days.length===7){aA.sortWeight=0}if(aA.days.length>1){aA.days=at.sortBy(aA.days,function(aO){return T.indexOf(aO)})}aI.push(aA)}else{aK=aA.endNextDay?2:1;aJ.splice(-aK,aK)}}})}aC=at.sortBy(aC,"day");aE.forEach(aG);aI=at.sortBy(aI,function(aK){return aK.sortWeight*10000+T.indexOf(aK.days[0])*1000+aK.startHour*10+aK.days.length});aI.forEach(function(aK,aL){aI[aL]=at.omit(aK,J)});return aI}function r(av,ax,aB){var ay=at.clone(av),au=ax.startHour*2+d(ax.startMinutes),aw=ax.endHour*2+d(ax.endMinutes),az=aw,aC,aA;if(ax.endNextDay){aw=48}ax.days.forEach(function(aD){aC=ay[aD].split("");at.fill(aC,aB,au,aw);ay[aD]=aC.join("");if(ax.endNextDay){aA=ag(aD);aC=ay[aA].split("");at.fill(aC,aB,0,az);ay[aA]=aC.join("")}});return ay}function N(av,au){return r(av,au,"0")}function m(av,au){return r(av,au,"1")}function t(aw,av,au){aw=m(aw,av);return N(aw,au)}function w(az,ay){var aw=false,ax,aD=ay.startHour*2+d(ay.startMinutes),aB=ay.endHour*2+d(ay.endMinutes)-1,aC,av,au=aD-1,aA=aB+1;if(ay.startHour===0){au=47}if(ay.endHour===24){aA=0}at.each(ay.days,function(aE){ax=ay.endNextDay?ag(aE):aE;aC=ay.startHour===0?p(aE):aE;av=ay.endHour===24?ag(aE):ax;if(az[aC][au]==="0"||az[aE][aD]==="0"||az[av][aA]==="0"||az[ax][aB]==="0"){aw=true;return false}});return aw}function O(av,ax,au){var aw=at.clone(av);aw=m(aw,ax);return w(aw,au)}function al(av,ax){var au=z.Deferred(),aw=z.transaction();aw.add("/macfilter/SetMACFilterSettings",av);b(ax.enabled,av.macFilterMode,null,aw);aw.send().success(function(){au.resolve(av)}).error(function(ay){au.reject(ay)});return au}function aa(au){au=at.trim(au);if(au.indexOf("://")>0){au=au.substring(au.indexOf("://")+3)}au=au.replace(/^www\./,"");return au}function B(av,au){return at.findIndex(av,function(aw){return at.isEqual(aw.macAddresses,au.knownMACAddresses)})}function L(av,aw){var ay=[],ax=av.rules,au;aw.forEach(function(az){au=B(ax,az);if(au!==-1){ay.push(ax[au])}});return ay}function v(av,aw){var ax=at.cloneDeep(av.rules),au;at.each(aw,function(ay){au=B(ax,ay);if(au!==-1){ax.splice(au,1)}});return ax}function A(au){var av=["WEP","WPA-Personal","WPA-Enterprise","WPA3-Personal"];return av.indexOf(au.settings.security)===-1}function am(au){return !au.settings.isEnabled||!au.settings.broadcastSSID||!A(au)}function l(au){return au!=="Disabled"}function ao(av){var au=at.filter(av,function(aw){return !ak.wireless.isSecondaryBandRadio(aw)&&aw.band!=="6GHz"});return au}function k(av,ay,az,ax){var au=0,aw=0;if(av&&l(av)){return false}if(ay){var aA=ao(ay.radios);aA.forEach(function(aB){au++;if(am(aB)){aw++}});if(aw===au){return false}}if(az&&ak.wireless.isWirelessDisabledBySchedule(az,ax)){return false}return true}function P(au,aw,ax,av){var az=[],ay=ao(aw.radios);if(l(au)){az.push("SYM-MAC_FILTER_ENABLED")}if(ax&&ak.wireless.isWirelessDisabledBySchedule(ax,av)){az.push("SYM-WIRELESS_SCHEDULER_BLOCKING")}ay.forEach(function(aA){if(am(aA)){if(!aA.settings.isEnabled){az.push("SYM-"+aA.radioID+"_DISABLED")}if(!aA.settings.broadcastSSID){az.push("SYM-"+aA.radioID+"_NOT_VISIBLE")}if(!A(aA)){az.push("SYM-"+aA.radioID+"_INVALID_SECURITY-"+aA.settings.security)}}});return az}function b(aw,az,aA,ax){var av=z.Deferred(),au={enabled:false},ay=ax?ax.add:z.send;if(aw&&!k(az,aA)){ay("/wirelessap/SetWPSServerSettings",au).success(function(){av.resolve(au)}).error(function(aB){av.reject(aB)})}else{av.resolve()}return av}function ap(av){var au=["CHN","HKG","IND","IDN","JPN","KOR","PHL","SGP","TWN","THA","XAH","AUS","CAN","EEE","BHR","EGY","KWT","OMN","QAT","SAU","TUR","ARE","XME","NZL","USA"],aw={CHN:"{{Asia - China}}",HKG:"{{Asia - Hong Kong}}",IND:"{{Asia - India}}",IDN:"{{Asia - Indonesia}}",JPN:"{{Asia - Japan}}",KOR:"{{Asia - Korea}}",PHL:"{{Asia - Philippines}}",SGP:"{{Asia - Singapore}}",TWN:"{{Asia - Taiwan}}",THA:"{{Asia - Thailand}}",XAH:"{{Asia - Rest of Asia}}",AUS:"{{Australia}}",CAN:"{{Canada}}",EEE:"{{Europe}}",BHR:"{{Middle East - Bahrain}}",EGY:"{{Middle East - Egypt}}",KWT:"{{Middle East - Kuwait}}",OMN:"{{Middle East - Oman}}",QAT:"{{Middle East - Qatar}}",SAU:"{{Middle East - Saudi Arabia}}",TUR:"{{Middle East - Turkey}}",ARE:"{{Middle East - United Arab Emirates}}",XME:"{{Middle East}}",NZL:"{{New Zealand}}",USA:"{{United States}}"};return at.intersection(au,av).map(function(ax){return{country:ax,text:aw[ax]}})}function q(aw,ay){var av=at.isPlainObject(aw),au=av?{}:[],ax;if(av){aw=[aw]}at.each(aw,function(az){ax={};at.each(ay,function(aB){var aA=at.last(at.words(aB,/[^.]+/g));ax[aA]=at.result(az,aB)});if(av){au=ax}else{au.push(ax)}});return au}function Z(ax,aA){var av="\n\t",aw="\n",ay=aA.length,au=at.fill(ay,0),az=new Array(ay);if(at.isPlainObject(ax)){ax=[ax]}at.each(aA,function(aD,aC){var aB=[],aE="";at.each(ax,function(aF){aB.push(at.result(aF,aD))});az[aC]=aB;aE=at.last(at.words(aD,/[^.]+/g));au[aC]=(aC===ay-1)?0:Math.max(aE.length,at.sortBy(aB,function(aF){return -aF.length})[0].length)+2;av+=at.padEnd(aE,au[aC]," ")});at.range(0,ax.length).forEach(function(aB){aw+="\t";at.range(0,ay).forEach(function(aC){aw+=at.padEnd(az[aC][aB],au[aC]," ")});aw+="\n"});return av+"\n\t"+at.repeat("-",av.length+2)+aw+"\n"}ak={stringFormat:function(av){var au=at.drop(arguments,1);return av.replace(/{(\d+)}/g,function(aw,ax){return typeof au[ax]!=="undefined"?au[ax]:aw})},errors:{errorStringToCode:function(au){return at.result(y,au)}},formatter:{filterJsonByPaths:q,jsonToTable:Z},maxBytes:{lengthInBytes:e,truncateToMaxByte:g,limitPasswordHint:ad(512),limitSsid:ad(32),limitApplicationName:ad(32),limitInputField:function(au,aw){var av=ad(aw);av(au)}},ip:{ipToNum:x,numToIP:aj,ipInRange:I,isValidSubnetMask:Y,prefixLengthToSubnetMask:h,subnetMaskToPrefixLength:j,notZero:function(au){return au&&au!=="0.0.0.0"}},time:{routerTimeToDate:aq,routerTimeToLocalShiftedDate:W,shiftUTCDateToLocalTZ:ab,isScheduleAlwaysBlocked:D,isScheduleAlwaysUnblocked:E,getSimplifiedLocaleHour:i,getNextDayNum:c,getNextDay:ag,getPreviousDayNum:af,getPreviousDay:p,getNextSchedulerEvent:G,getDayFromSchedule:C,getScheduleRangesForWeek:H,addBlockedRange:N,removeBlockedRange:m,editBlockedRange:t,isAddAdjacentOrOverlapping:w,isEditAdjacentOrOverlapping:O,msToReadableTime:ae,getElapsedMs:V,getElapsedMsReadable:a},macFilter:{setMACFilterSettings:al},parentalControls:{trimBlockedDomain:aa,getUpdatedRules:L,getOrphanedRules:v,getUniqueWeekRanges:f},powerTable:{getCountriesList:ap},wps:{isWPSAvailable:k,getWPSEnabledRadios:ao,getWPSUnavailableReasons:P,checkAndDisableWPS:b}};ak.logging=ah(ak);ak.guestAccess=s(ak);ak.wireless=X(ak);ak.wan=S(ak);ak.monitors=n(ak);ak.nodes=F;ak.firmwareUpdate=U(ak);ak.lan=an(ak);ak.networkSecurity=ac(ak);return ak}));