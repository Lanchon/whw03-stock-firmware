$(document).ready(function(){var g=RAINIER.ui.dialog($("#mfa-resent")),e=null,f=null;function b(){RAINIER.cloud.send({url:"/cloud/user-service/rest/accounts/self",type:"GET",cb:function(j){if(j){window.location.replace("/ui/dynamic/home.html")}else{RAINIER.network.signOut()}},cbError:function(l){var k=RAINIER.util.parseJSON(l.responseText),j=null,m=false;if(k&&k.errors){j=lodash.find(k.errors,{error:{code:"SESSION_RESTRICTED"}});if(j&&j.error.parameters){m=lodash.some(j.error.parameters,{parameter:{name:"restrictions",value:"MFA"}})}}if(m){h()}else{RAINIER.network.signOut()}}})}function h(){RAINIER.cloud.send({url:"/cloud/user-service/rest/accounts/self/mfa-methods",type:"GET",cb:function(j){e=j;if(j.length===1){f=j[0];Account.mfa.removeRestriction(f,function(){d("mfa-challenge-container")})}else{d("mfa-selection-container")}}})}function c(){var j=_.find(e,{method:"EMAIL"}),k=_.find(e,{method:"SMS"});if(j){$("#email-address").text(j.target)}if(k){$("#phone-number").text(k.target)}if(f){if(f.method==="EMAIL"){$(".mfa-email-method").each(function(){var l=$(this);l.text(l.text().replace("{email}",f.target))});$(".mfa-email-method").show()}else{if(f.method==="SMS"){$(".mfa-sms-method").each(function(){var l=$(this);l.text(l.text().replace("{phone}",f.target))});$(".mfa-sms-method").show()}}}}function i(){b();$("#mfa-selection-container .okButton").click(function(){var j=$("input[name=mfa-deliverymethod-radio]:checked","#mfa-selection").val();f=_.find(e,{method:j});RAINIER.ui.showMasterWaiting();Account.mfa.removeRestriction(f,function(){d("mfa-challenge-container")})});$("#mfa-challenge-container .okButton").click(function(){$(".error").hide();Account.mfa.verifyOTP({otp:$("#mfa-code-input").val(),saveRefreshToken:$('#mfa-challenge-container input[name="mfa-remember-checkbox"]').is(":checked"),cbError:function(j){if(j==="invalid_verification_token_or_otp"){$("#mfa-error-incorrect").show()}else{if(j==="invalid_request"){$("#mfa-error-incorrect").show()}}},cbCancel:RAINIER.network.signOut})});$("#mfa-challenge-container #mfa-input a").click(function(){Account.mfa.resend();return false});$(".cancelButton").click(RAINIER.network.signOut)}function a(){RAINIER.ui.hideMasterWaiting();RAINIER.ui.showAppletContainer()}function d(l){var k=$(".view"),j=$("#"+l);k.hide();c();j.show();a()}RAINIER.network.getDeviceInfo(function(){RAINIER.ui.init(i)})});