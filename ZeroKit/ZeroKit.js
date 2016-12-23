// ZeroKit iOS SDK javascript support

window.iosZeroKit = new Object()
window.iosZeroKit.tokenCache = []

function ios_cmd_api_getInvitationLinkInfo(secret) {
    return cmd.api.getInvitationLinkInfo(secret).then(function(succ) {
        /* $token object contains uint8 array that cannot be returned to native code.
         Do not need it there anyway, return only an ID for the token. */
        window.iosZeroKit.tokenCache.push(succ.$token)
        succ.$token = null
        succ.tokenId = window.iosZeroKit.tokenCache.length - 1
        return succ
    }, function(err) {
        return err
    })
}

function ios_mobileCmd_acceptInvitationLink(tokenId, password) {
    var token = window.iosZeroKit.tokenCache[parseInt(tokenId)]
    return mobileCmd.acceptInvitationLink(token, password)
}

function ios_cmd_api_acceptInvitationLinkNoPassword(tokenId) {
    var token = window.iosZeroKit.tokenCache[parseInt(tokenId)]
    return cmd.api.acceptInvitationLinkNoPassword(token)
}

function ios_cmd_api_encryptBytes(tresorId, base64PlainBytes) {
    /* We cannot pass binary data to javascript from native code so we base64 encode it. */
    var plainBytes = ios_base64ToUint8Array(base64PlainBytes)
    return cmd.api.encryptBytes(tresorId, plainBytes).then(function(succ) {
        return ios_uint8ArrayToBase64(succ)
    }, function(err) {
        return err
    })
}

function ios_cmd_api_decryptBytes(base64CipherBytes) {
    /* We cannot pass binary data to javascript from native code so we base64 encode it. */
    var cipherBytes = ios_base64ToUint8Array(base64CipherBytes)
    return cmd.api.decryptBytes(cipherBytes).then(function(succ) {
        return ios_uint8ArrayToBase64(succ)
    }, function(err) {
        return err
    })
}

function ios_callApiMethod(object, method, callbackId) {
    /* Additional arguments after the first 3 named arguments.
     These will be passed to the api method. */
    var methodArgs = Array.prototype.splice.call(arguments, 3);
    
    method.apply(object, methodArgs).then(function(succ) {
        window.webkit.messageHandlers.ZeroKitHandler.postMessage([true, callbackId, succ])
    }, function(err) {
        window.webkit.messageHandlers.ZeroKitHandler.postMessage([false, callbackId, err])
    })
}


// Helper functions

function ios_uint8ArrayToBase64(bytes) {
    var binary = '';
    var len = bytes.byteLength;
    for (var i = 0; i < len; i++) {
        binary += String.fromCharCode(bytes[i]);
    }
    return btoa(binary);
}

function ios_base64ToUint8Array(base64) {
    var binary_string = atob(base64);
    var len = binary_string.length;
    var bytes = new Uint8Array(len);
    for (var i = 0; i < len; i++)        {
        bytes[i] = binary_string.charCodeAt(i);
    }
    return bytes;
}
