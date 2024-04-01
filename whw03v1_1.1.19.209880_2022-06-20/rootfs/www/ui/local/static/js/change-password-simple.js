var checks={};function simpleInputValidation(){var a=checks.currentPassword.isValid(true);if(a){a=checks.password.isValid();if(!a){checks.password.isValid(true);$("#password").blur();$("#password").focus()}}if(a){a=checks.passwordConfirm.isValid(true);if(!a){$("passwordConfirm").blur();$("passwordConfirm").focus()}}return a}function showError(a){try{if(JSON.parse(a.responseText).errors[0].error.code==="INVALID_CURRENT_PASSWORD"){showGeneralError(RAINIER.ui.myAccountStrings.errorChangingPassword);showView("landing");return true}else{if(JSON.parse(a.responseText).errors[0].error.code==="INVALID_PARAMETER"){showGeneralError(RAINIER.ui.myAccountStrings.invalidParameter);showView("landing");return true}else{if(JSON.parse(a.responseText).errors[0].error.code==="INVALID_SESSION_TOKEN"){RAINIER.shared.ui.ensureSignedIn();return true}}}}catch(b){}showGeneralError(RAINIER.ui.myAccountStrings.couldNotSaveAccountModifications+"\n"+RAINIER.ui.myAccountStrings.couldNotSaveAccountModificationsTitle);showView("landing");return true}function changePassword(){if(!simpleInputValidation()){return}showView("working");var b=document.getElementById("passwordInput").value,c=document.getElementById("oldPasswordInput").value,a=RAINIER.shared.util.getURLParameter("callback");RAINIER.cloud.send({url:"/cloud/user-service/rest/accounts/self/passwordchanges",type:"POST",data:{passwordChange:{newPassword:b,currentPassword:c}},cb:function(e,d){if(d.status!==200){showError(d)}else{document.getElementById("okButton").style.display="none";document.getElementById("cancelButton").style.display="none";if(a){showGeneralMessage(RAINIER.ui.myAccountStrings.successMessage.replace("{url}",a))}else{showGeneralMessage(RAINIER.ui.myAccountStrings.successMessageNoCallback)}showView("passwordChanged")}},cbError:showError})}function callback(){var a=RAINIER.shared.util.getURLParameter("callback");if(a){window.location.assign(a)}}function cancel(){callback()}window.onload=function(){var a=RAINIER.shared.util.getURLParameter("callback"),b=RAINIER.ui.buildInputValidBalloon;document.getElementById("okButton").onclick=changePassword;document.getElementById("cancelButton").onclick=cancel;RAINIER.shared.ui.ensureSignedIn();if(!a){document.getElementById("cancelButton").style.display="none"}checks.currentPassword=b($.extend(true,{},{els:$("#currentPassword"),isBlankOnBlur:false},validation.ruleSet.cloudAccountPassword));checks.password=b($.extend(true,{},{els:$("#password"),validationType:"newCloudPassword",isChecklist:true,noWarnIcon:true},RAINIER.network.getCloudAccountNewPasswordOptions()));checks.passwordConfirm=b({els:$("#passwordConfirm"),validationType:"confirmPassword",elCompareTo:$("#password")});showView("landing")};