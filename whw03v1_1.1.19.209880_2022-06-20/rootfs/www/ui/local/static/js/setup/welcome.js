var isDataUploadSupported;function turnOffUnsecuredWarning(c,d){var b=20000;showView("working");var a=new XMLHttpRequest();a.open("POST","/JNAP/",true);a.setRequestHeader("Content-Type","application/json;charset=UTF-8");a.setRequestHeader("X-JNAP-Action","http://cisco.com/jnap/core/SetUnsecuredWiFiWarning");a.onreadystatechange=function(){if(a.readyState===4&&a.status===200&&parseJSON(a.responseText)["result"]==="OK"){if(c){setTimeout(function(){RAINIER.setup.goToPage(window.location.protocol+"//"+window.location.hostname+":80/ui/dynamic/setup/check_router_settings.html")},b)}else{setTimeout(function(){var e=window.location.protocol+"//"+window.location.hostname+"/";window.onbeforeunload=null;window.location.replace(e)},b)}}else{if(a.readyState===4&&a.status===200&&parseJSON(a.responseText)["result"]==="_ErrorNotReady"){if(d<=6){setTimeout(function(){turnOffUnsecuredWarning(c,++d)},5000)}else{window.onbeforeunload=null;window.location.reload()}}}};if(!c){RAINIER.shared.util.setRemoteSetting(RAINIER.jnap,true,null,{disableDefaultAjaxErrHandler:true,disableDefaultJnapErrHandler:true})}a.send(JSON.stringify({enabled:false}))}function setDataUploadConfig(a){var b=document.getElementById("rdcCheckbox").checked;if(!isDataUploadSupported){a();return false}RAINIER.shared.util.signOutCookies();setRouterPassword("admin");RAINIER.jnap.send({action:"/jnap/core/SetDataUploadUserConsent",data:{userConsent:b},cb:function(){RAINIER.shared.util.signOutCookies();a()}})}function onSkipSetup(){if(!document.getElementById("eulaCheckbox").checked){document.getElementById("eulaError").style.visibility="visible";return false}document.getElementById("eulaCheckbox").disabled=true;setDataUploadConfig(function(){turnOffUnsecuredWarning(false,0)});return false}function onNext(){if(!document.getElementById("eulaCheckbox").checked){document.getElementById("eulaError").style.visibility="visible";return false}document.getElementById("eulaCheckbox").disabled=true;setDataUploadConfig(function(){turnOffUnsecuredWarning(true,0)})}window.onbeforeunload=function(){return RAINIER.shared.util.decodeHtml(RAINIER.setup.ui.confirmExit)};function initFinished(){var a=document.getElementById("routerImage"),b=RAINIER.shared.ui.getModelDataFromIcon(getModelNumber(),getHardwareVersion());if(isDataUploadSupported){document.getElementById("rdcDiv").style.display="block"}a.src=a.src.replace("Default",b);showView("landing")}function init(){document.getElementById("eulaCheckbox").onclick=function(){if(document.getElementById("eulaCheckbox").checked){document.getElementById("eulaError").style.visibility="hidden"}};document.getElementById("eulaDiv").getElementsByTagName("a")[0].onclick=function(){RAINIER.shared.ui.goToLegalDoc("embeddedTermsAndConditions");return false};document.getElementById("skipSetupLink").onclick=onSkipSetup;RAINIER.jnap.send({action:RAINIER.jnapActions.getDeviceInfo(),data:{},cb:function(a){if(a.result==="OK"){RAINIER.jnapCache.set(RAINIER.jnapActions.getDeviceInfo(),a.output);isDataUploadSupported=RAINIER.shared.util.areServicesSupported(["/jnap/core/Core4"]);RAINIER.shared.util.deleteCookie("modelNumber");reviewModelNumber(initFinished)}}})}window.onload=function(){showView("working");init()};