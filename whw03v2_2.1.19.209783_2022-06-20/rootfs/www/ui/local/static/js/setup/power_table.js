function goToNextPage(){var a=document.getElementById("regionsSelect"),b=a.options[a.selectedIndex].value;if(isRegionValid(a)){showView("working");RAINIER.jnap.send({action:"/jnap/powertable/SetPowerTableSettings",data:{country:b},cb:function(c){if(c.result==="OK"){RAINIER.setup.goToPage("/ui/dynamic/setup/change_radio_settings.html")}}})}}function isRegionValid(a){changeBtnState(document.getElementById("nextButton"),true);if(!a.selectedIndex){showInputValidationError("regionValidation",true,RAINIER.setup.ui.inputRequired);return false}clearAllInputErrors();return true}window.onbeforeunload=function(){return RAINIER.shared.util.decodeHtml(RAINIER.setup.ui.confirmExit)};window.onload=function(){showView("working");RAINIER.jnap.send({action:"/jnap/powertable/GetPowerTableSettings",data:{},cb:function(a){if(a.result==="OK"){RAINIER.shared.ui.populateRegions(a.output.supportedCountries,document.getElementById("regionsSelect"));showView("landing")}else{}}})};