RAINIER.setup.remoteUiEnabled=null;function launchLinksysSmartWifi(b,a){if(b){if(a){RAINIER.shared.ui.goToVerifiedUrl("/ui/dynamic/login-simple.html")}else{RAINIER.shared.ui.goToVerifiedUrl("/ui/dynamic/create-account.html?rp="+window.btoa(getRouterPassword()))}}else{RAINIER.shared.ui.goToVerifiedUrl("/ui/dynamic/home.html")}}function onNextPage(a){var b,c,d;if(a){b=!a;c=!b;d=a!==RAINIER.setup.remoteUiEnabled}else{b=document.getElementById("noThanksCheckbox").checked;c=b;d=b===RAINIER.setup.remoteUiEnabled}if(d){showView("working");setTimeout(function(){RAINIER.shared.util.setRemoteSetting(RAINIER.jnap,!b,function(){launchLinksysSmartWifi(!b,a)},{disableDefaultAjaxErrHandler:true,disableDefaultJnapErrHandler:true});RAINIER.shared.util.setUIProxyPathCookie(c?"local":"remote")},RAINIER.setup.UI_DELAY)}else{launchLinksysSmartWifi(!b,a)}}function getRemoteSetting(){RAINIER.jnap.send({action:"/jnap/ui/GetRemoteSetting",data:{},cb:function(a){if(a&&a.result==="OK"){RAINIER.setup.remoteUiEnabled=a.output.isEnabled}showView("landing")},disableDefaultAjaxErrHandler:true,disableDefaultJnapErrHandler:true})}window.onload=function(){showView("working");getRemoteSetting()};