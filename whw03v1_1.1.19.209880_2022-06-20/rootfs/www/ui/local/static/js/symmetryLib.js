if(!window.RAINIER){window.RAINIER={}}RAINIER.symmetryLib={jnapInit:function(){if(RAINIER.network.uiLoadedFromCloud()&&RAINIER.network.isAuthorityRemote()){JNAP.setAuth(CLOUD_REST.setAuth(RAINIER.shared.util.getCiscoHNClientID(),$.cookie("user-auth-token"),RAINIER.network.getCurrentNetworkID()))}else{if($.cookie("user-auth-token")){JNAP.setAuth(CLOUD_REST.setAuth(RAINIER.shared.util.getCiscoHNClientID(),$.cookie("user-auth-token")))}else{JNAP.setAuth($.cookie("admin-auth"))}}}};