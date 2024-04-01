var isPasswordHintSupported=false;var maxHintBytes=512;var checks={};function goToNextPage(){RAINIER.setup.goToPage("/ui/dynamic/setup/congratulations.html")}function saveRouterPasswordInTransaction(b,e,a){var d=isPasswordHintSupported?"/jnap/core/SetAdminPassword2":"/jnap/core/SetAdminPassword",c={adminPassword:e};if(isPasswordHintSupported){c.passwordHint=a}b.add({action:d,data:c,cb:function(f){if(f.result==="OK"){setRouterPassword(e);setPasswordHint(c.passwordHint)}else{if(f.result==="ErrorInvalidAdminPassword"||f.result==="Error"){showView("landing");showInputValidationError("routerPasswordInputValidation",false)}else{if(f.result!=="_AjaxError"&&f.result!=="_ErrorAbortedAction"){RAINIER.executeDefaultJnapErrorHandler(f)}}}}})}function simpleInputValidation(a){var b=true;if($("#routerPassword").is(":visible")){b=checks.password.isValid();if(!b){checks.password.isValid(true);$("#routerPassword").blur().focus()}}else{b=checks.passwordVisible.isValid();if(!b){checks.password.isValid(true);$("#routerPasswordText").blur().focus()}}if(b){b=checks.hint.isValid(true)}return b}function checkValidation(){var a=true;if($("#routerPassword").is(":visible")){a=checks.password.isValid()}else{a=checks.passwordVisible.isValid()}return a&&checks.hint.isValid(true)}function applySettings(){var a=document.getElementById("routerPassword").value,b=document.getElementById("passwordHint");passwordHint=b.value;if(!simpleInputValidation()){return}startPleaseWaitTimer();showView("working");setTimeout(function(){var c=RAINIER.jnap.Transaction({onComplete:function(d){if(d.result==="OK"){goToNextPage()}},disableDefaultJnapErrHandler:true});saveRouterPasswordInTransaction(c,a,passwordHint);RAINIER.setup.removeRouterPropertiesInTransaction(c,["setupState","hasInternet"]);c.send()},RAINIER.setup.UI_DELAY)}function generateRouterPassword(){var b="abcdefghjkmnopqrstuvwxyzABCDEFGHJKLMNPQRTUVWXYZ2346789",d="";for(var a=0;a<10;a++){var c=Math.floor(Math.random()*b.length);d+=b.charAt(c)}return d}function saveHasInternetCookie(a){getRouterPropertyValue("hasInternet",function(b){if(b&&b==="true"){RAINIER.shared.util.setCookie("hasInternet","true",null,"/")}if(typeof a==="function"){a()}})}function ensureRouterSettingsAreCookiedAfterReconnect(b){if(getRouterPassword()===""){setRouterPassword("admin")}var c=RAINIER.jnap.Transaction({onComplete:function(){saveHasInternetCookie(b)}});var a=false;if(getModelNumber()===""||!RAINIER.jnapCache.get(RAINIER.jnapActions.getDeviceInfo())){a=true;getRouterInfo(c,function(d){if(d.result==="OK"){RAINIER.jnapCache.set(RAINIER.jnapActions.getDeviceInfo(),d.output);saveModelNumber(RAINIER.setup.getCurrentNetworkModelName())}})}if(getWirelessSsid()===""||getWirelessPassword()===""){a=true;getRadioSettingsInTransaction(c,function(d){if(d.result==="OK"&&getRadioByIndex(0)){saveWirelessSsidAll();saveWirelessPasswordAll()}})}if(!RAINIER.shared.util.getCookie("routerDeviceId")){a=true;RAINIER.setup.getRouterDeviceID(null,null,c)}if(a){c.send()}else{if(typeof b==="function"){b()}}}function hideAndShowPasswordHintText(b){var a=document.getElementById("moreText");passwordHintText=document.getElementById("passwordHintMoreText");if(b){a.style.display="none";passwordHintText.style.display="block"}else{passwordHintText.style.display="none";a.style.display="inline"}}window.onbeforeunload=function(){return RAINIER.shared.util.decodeHtml(RAINIER.setup.ui.confirmExit)};window.onload=function(){var a=RAINIER.ui.buildInputValidBalloon;showView("working");ensureRouterSettingsAreCookiedAfterReconnect(function(){var b=document.getElementById("router-password");isPasswordHintSupported=RAINIER.shared.util.areServicesSupported(["/jnap/core/Core3"]);var c=document.getElementById("routerImage"),d=RAINIER.shared.ui.getModelDataFromIcon(getModelNumber(),getHardwareVersion());c.src=c.src.replace("Default",d);checks.password=a($.extend(true,{},{els:$("#routerPassword"),validationType:"newRouterPassword",isChecklist:true,noWarnIcon:true},RAINIER.network.getRouterPasswordOptions()));checks.passwordVisible=a($.extend(true,{},{els:$("#routerPasswordText"),validationType:"newRouterPassword",isChecklist:true,noWarnIcon:true},RAINIER.network.getRouterPasswordOptions()));checks.hint=a($.extend(true,{},{els:$("#passwordHint"),validationType:"routerPasswordHint",maxLen:512,elCompareTo:$("#routerPassword")}));$("#routerPassword, #routerPasswordText, #passwordHint").on("keyup",function(){changeBtnState(document.getElementById("nextButton"),checkValidation())});RAINIER.ui.viewPassword($(".password-eye-box"));showView("landing");if(!isPasswordHintSupported){document.getElementById("passwordHintSection").style.display="none";b.value=generateRouterPassword()}else{document.getElementById("noPasswordHintSection").style.display="none";changeBtnState(document.getElementById("nextButton"),false)}})};