function convertToPython(obj) {
    if (!obj)
        return obj;

    if (obj.constructor.name === "Error")
        return obj;

    if (obj.constructor.name === "Uint8Array")
        return "@Uint8Array(" + asmCrypto.bytes_to_base64(obj) + ")";

    if (typeof obj !== "object")
        return obj;

    Object.keys(obj).forEach(function(k) {
        obj[k] = convertToPython(obj[k]);
    });

    return obj;
}

function convertFromPython(obj) {
    if (!obj)
        return obj;
    if (typeof obj === "string" && obj.startsWith('@Uint8Array')) {
        return asmCrypto.base64_to_bytes(id, obj.replace(/@Uint8Array\((.*)\)/, '$1'));
    }

    if (typeof obj !== "object")
        return obj;
    Object.keys(obj).forEach(function(k) {
        if (typeof obj[k] === "string" && obj[k].startsWith('@Uint8Array'))
            obj[k] = asmCrypto.base64_to_bytes(obj[k].replace(/@Uint8Array\((.*)\)/, '$1'));
        else if (typeof obj[k] === "object")
            obj[k] = convertFromPython(obj[k]);
    });

    return obj;
}

function isEquivalent(a, b) {
    if (typeof a === "string" || typeof b === "string" || typeof a === "number" || typeof b === "number") {
        console.log("isEquivalent cmp ===", a === b)
        return a === b;
    }
    
    if (typeof a === "object") {
        // Create arrays of property names
        var aProps = Object.getOwnPropertyNames(a);
        var bProps = Object.getOwnPropertyNames(b);
        // If number of properties is different,
        // objects are not equivalent
        if (aProps.length != bProps.length) {
            console.log("isEquivalent length mismatch")
            return false;
        }
        for (var i = 0; i < aProps.length; i++) {
            var propName = aProps[i];
            // If values of same property are not equal,
            // objects are not equivalent
            if (!isEquivalent(a[propName], b[propName])) {
                console.log("isEquivalent prop mismatch", propName)
                return false;
            }
        }
    }
    
    // If we made it this far, objects
    // are considered equivalent
    console.log("isEquivalent true")
    return true;
}

var xhrExpectations = null;
var mockedRandoms = null;

origCryptoRandomBytes = mockCrypto.cryptoRandomBytes

mockCrypto.cryptoRandomBytes = function(len) {
    if (mockedRandoms) {
        const cRand = mockedRandoms.shift();
        if (!cRand)
            throw new Error("NoRandomSet" + len);
        if (cRand.length !== len)
            throw new Error("FormatTestRandomLengthMismatch " + cRand.length + " != " + len);

        return cRand;
    }
    return origCryptoRandomBytes(len)
};

const origXHRCallback = XHRCallback;

XHRCallback = function(id, method, url, headers, body) {
    if (xhrExpectations) {
        const currExpectation = xhrExpectations.shift();
        if (!currExpectation) {
            return XHRResolve(id, "", 403, asmCrypto.string_to_bytes(JSON.stringify({ ErrorMessage: "ApiError", "ErrorCode": "XHRExpectationMissing" + url })));
        }
        if (!url.endsWith(currExpectation.url)) {
            return XHRResolve(id, "", 403, asmCrypto.string_to_bytes(JSON.stringify({ ErrorMessage: "ApiError", "ErrorCode": "XHRExpectationUrlMismatch" })));
        }
        if (method !== currExpectation.method) {
            return XHRResolve(id, "", 403, asmCrypto.string_to_bytes(JSON.stringify({ ErrorMessage: "ApiError", "ErrorCode": "XHRExpectationMethodMismatch" })));
        }

        if ((body || currExpectation.expectedBody) && !isEquivalent(JSON.parse(asmCrypto.bytes_to_string(new Uint8Array(body))), currExpectation.expectedBody)) {
            return XHRResolve(id, "", 403, asmCrypto.string_to_bytes(JSON.stringify({ ErrorMessage: "ApiError", "ErrorCode": "XHRExpectationBodyMismatch" })));
        }

        return XHRResolve(id, "", currExpectation.responseStatus, asmCrypto.string_to_bytes(JSON.stringify(currExpectation.responseBody)));
    }

    return origXHRCallback(id, method, url, headers, body);
};

mobileCommands.setXHRExpectation = function(method, url, expectedBody, responseStatus, responseBody) {
    if (xhrExpectations === null)
        xhrExpectations = [];
    xhrExpectations.push({ method, url, expectedBody, responseStatus, responseBody });
    return Promise.resolve();
};

mobileCommands.setRandoms = function(b64_arr) {
    if (mockedRandoms === null)
        mockedRandoms = [];

    b64_arr.forEach(function(a) {
        mockedRandoms.push(asmCrypto.base64_to_bytes(a));
    });
    return Promise.resolve();
};

const OrigDate = Date;

mobileCommands.clean = function() {
    Date = OrigDate;

    mockedRandoms = null;
    xhrExpectations = null;

    mockLocalStorage.keys().forEach(function(k) { mockLocalStorage.removeItem(k); });
    mockSessionStorage.keys().forEach(function(k) { mockSessionStorage.removeItem(k); });
    mockPersistenceKeys.removeWebSessionKey();

    return Promise.resolve();
};

mobileCommands.setLocalStorage = function(key, val) {
    mockLocalStorage.setItem(key, val);

    return Promise.resolve();
};

mobileCommands.setDate = function(date) {
    Date = class MockedDate extends OrigDate {
        constructor() {
            super(date)
        }

        static now() {
            return date;
        }
    };
    return Promise.resolve();
};


// iOS SDK

function ios_safeLinkTokenForId(tokenId) {
    var token = iosZeroKit.tokenCache[parseInt(tokenId)]
    return Promise.resolve(convertToPython(token))
}

function ios_placeSafeLinkToken(safeToken) {
    var token = convertFromPython(safeToken)
    iosZeroKit.tokenCache.push(token)
    return Promise.resolve((iosZeroKit.tokenCache.length - 1).toString())
}

function ios_mockCryptoB64(len) {
    var bytes = mockCrypto.cryptoRandomBytes(len)
    return asmCrypto.bytes_to_base64(bytes)
}
