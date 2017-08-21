// ZeroKit iOS SDK javascript support

var iosZeroKit = new Object()
iosZeroKit.tokenCache = []

function ios_cmd_api_getInvitationLinkInfo(secret) {
    return mobileCommands.getInvitationLinkInfo(secret).then(function(succ) {
        /* $token object contains uint8 array that cannot be returned to native code.
         Do not need it there anyway, return only an ID for the token. */
        iosZeroKit.tokenCache.push(succ.$token)
        succ.$token = null
        succ.tokenId = iosZeroKit.tokenCache.length - 1
        return succ
    }, function(err) {
        return err
    })
}

function ios_mobileCommands_acceptInvitationLink(tokenId, password) {
    var token = iosZeroKit.tokenCache[parseInt(tokenId)]
    return mobileCommands.acceptInvitationLink(token, password)
}

function ios_cmd_api_acceptInvitationLinkNoPassword(tokenId) {
    var token = iosZeroKit.tokenCache[parseInt(tokenId)]
    return mobileCommands.acceptInvitationLinkNoPassword(token)
}

function ios_cmd_api_encryptBytes(tresorId, base64PlainBytes) {
    /* We cannot pass binary data to javascript from native code so we base64 encode it. */
    var plainBytes = ios_base64ToUint8Array(base64PlainBytes)
    return mobileCommands.encryptBytes(tresorId, plainBytes).then(function(succ) {
        return ios_uint8ArrayToBase64(succ)
    }, function(err) {
        return err
    })
}

function ios_cmd_api_decryptBytes(base64CipherBytes) {
    /* We cannot pass binary data to javascript from native code so we base64 encode it. */
    var cipherBytes = ios_base64ToUint8Array(base64CipherBytes)
    return mobileCommands.decryptBytes(cipherBytes).then(function(succ) {
        return ios_uint8ArrayToBase64(succ)
    }, function(err) {
        return err
    })
}

function ios_callApiMethod(object, method, callbackId, methodArgs) {
    method.apply(object, methodArgs).then(function(succ) {
        ZeroKitResultCallback(true, callbackId, succ)
    }, function(err) {
        ZeroKitResultCallback(false, callbackId, err)
    })
}


// API Callbacks
// The javascript sdk expects these functions to be defined. Results are returned by calling the expected callbacks.
// Some functions are defined in native code.

function XHRCallback(id, method, url, headers, body) {
    var bodyBase64 = null
    if (body != null) {
        var bodyUint8 = new Uint8Array(body)
        bodyBase64 = ios_uint8ArrayToBase64(bodyUint8)
    }
    XHRCallbackInner(method, url, Array.from(headers.entries()), bodyBase64, function(responseHeaders, responseStatus, responseBase64) {
        if (responseStatus != 0) {
            var headers = []
            Object.keys(responseHeaders).forEach(function(key) {
                headers.push(key + ": " + responseHeaders[key])
            });
            var response = ios_base64ToUint8Array(responseBase64)
            XHRResolve(id, headers.join("\r\n"), responseStatus, response)
        } else {
            XHRResolve(id, "", 503, asmCrypto.string_to_bytes('{ErrorCode:"NetworkError"}'))
        }
    })
}

var mockCrypto = {
    cryptoRandomBytes(len) {
        var result = iosCrypto.cryptoSecureRandomBytes(len)
        return ios_base64ToUint8Array(result)
    },
    
    aesGcmEncrypt(data, key, iv, adata, tagLength) {
        var hexAdata = ""
        if (adata != null) {
            hexAdata = ios_uint8ArrayToHex(adata)
        }
        
        var result = iosCrypto.aesGcmEncrypt(ios_uint8ArrayToHex(data),
                                             ios_uint8ArrayToHex(key),
                                             ios_uint8ArrayToHex(iv),
                                             hexAdata,
                                             tagLength)
        
        if (result == null) {
            throw "iOS aesGcmEncrypt error"
        }
        
        return ios_hexToUint8Array(result)
    },
    
    aesGcmDecrypt(data, key, iv, adata, tagLength) {
        var hexAdata = ""
        if (adata != null) {
            hexAdata = ios_uint8ArrayToHex(adata)
        }
        
        var result = iosCrypto.aesGcmDecrypt(ios_uint8ArrayToHex(data),
                                             ios_uint8ArrayToHex(key),
                                             ios_uint8ArrayToHex(iv),
                                             hexAdata,
                                             tagLength)
        
        if (result == null) {
            throw "iOS aesGcmDecrypt error"
        }
        
        return ios_hexToUint8Array(result)
    },
    
    hmacSha256(data, password) {
        if (typeof data === 'string') data = utf8.encode(data);
        if (typeof password === 'string') password = utf8.encode(password);
        
        var result = iosCrypto.hmacSha256(ios_uint8ArrayToHex(data),
                                          ios_uint8ArrayToHex(password))
        
        if (result == null) {
            throw "iOS hmacSha256 error"
        }
        
        return ios_hexToUint8Array(result)
    },
    
    pbkdf2HmacSha256(password, salt, iterations, size) {
        if (typeof password === 'string') password = utf8.encode(password);
        
        var result = iosCrypto.pbkdf2HmacSha256(ios_uint8ArrayToHex(password),
                                                ios_uint8ArrayToHex(salt),
                                                iterations,
                                                size || 32)
        
        if (result == null) {
            throw "iOS pbkdf2HmacSha256 error"
        }
        
        return ios_hexToUint8Array(result)
    },
    
    pbkdf2HmacSha512(password, salt, iterations, size) {
        if (typeof password === 'string') password = utf8.encode(password);
        
        var result = iosCrypto.pbkdf2HmacSha512(ios_uint8ArrayToHex(password),
                                                ios_uint8ArrayToHex(salt),
                                                iterations,
                                                size || 64)
        
        if (result == null) {
            throw "iOS pbkdf2HmacSha512 error"
        }
        
        return ios_hexToUint8Array(result)
    },
    
    sha256(data) {
        var result = iosCrypto.sha256(ios_uint8ArrayToHex(data))
        
        if (result == null) {
            throw "iOS sha256 error"
        }
        
        return ios_hexToUint8Array(result)
    },
    
    sha512(data) {
        var result = iosCrypto.sha512(ios_uint8ArrayToHex(data))
        
        if (result == null) {
            throw "iOS sha512 error"
        }
        
        return ios_hexToUint8Array(result)
    },

    deriveScrypt(password, salt, N, r, p, keyLen) {
        if (typeof password === 'string') password = utf8.encode(password);

        var result = iosCrypto.scrypt(ios_uint8ArrayToHex(password),
                                      ios_uint8ArrayToHex(salt),
                                      N,
                                      r,
                                      p,
                                      keyLen)

        if (result == null) {
            throw "iOS deriveScrypt error"
        }
        
        return ios_hexToUint8Array(result)
    }
}

var NativeSRP = {
    newSession(N, G) {
        var result = iosSrp.newSession(N, G)

        if (result == null) {
            throw "iOS SRP newSession error"
        }

        return result
    },

    generatePubA(client) {
        var result = iosSrp.generatePubA(client)

        if (result == null) {
            throw "iOS SRP generatePubA error"
        }

        return ios_hexToUint8Array(result)
    },

    calculateSecret(client, x, B) {
        var result = iosSrp.calculateSecret(client, 
                                            ios_uint8ArrayToHex(x),
                                            ios_uint8ArrayToHex(B))

        if (result == null) {
            throw "iOS SRP calculateSecret error"
        }

        return ios_hexToUint8Array(result)
    },

    calculateClientEvidence(client) {
        var result = iosSrp.calculateClientEvidence(client)

        if (result == null) {
            throw "iOS SRP calculateClientEvidence error"
        }
        
        return ios_hexToUint8Array(result)
    },

    verifyServerEvidenceMessage(client, serverProof) {
        var result = iosSrp.verifyServerEvidenceMessage(client,
                                                        ios_uint8ArrayToHex(serverProof))
        return result
    },

    calculateVerifier(client, x) {
        var result = iosSrp.calculateVerifier(client,
                                              ios_uint8ArrayToHex(x))

        if (result == null) {
            throw "iOS SRP calculateVerifier error"
        }
        
        return ios_hexToUint8Array(result)
    },

    releaseClient(client) {
        iosSrp.releaseClient(client)
    }
}

// Helper functions

function ios_uint8ArrayToBase64(bytes) {
    return asmCrypto.bytes_to_base64(bytes)
}

function ios_base64ToUint8Array(base64) {
    return asmCrypto.base64_to_bytes(base64)
}

function ios_uint8ArrayToHex(bytes) {
    return asmCrypto.bytes_to_hex(bytes)
}

function ios_hexToUint8Array(hex) {
    return asmCrypto.hex_to_bytes(hex)
}
