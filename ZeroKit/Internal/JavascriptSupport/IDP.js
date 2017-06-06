// ZeroKit IDP javascript support

function ios_setCookiesAndData(parameters) {
    var cookies = parameters[0]
    var localStorageKV = parameters[1]
    var sessionStorageKV = parameters[2]
    
    for (var i = 0; i < cookies.length; i++) {
        document.cookie = cookies[i]
    }
    
    for (var i = 0; i < localStorageKV.length; i++) {
        var kv = localStorageKV[i]
        localStorage.setItem(kv[0], kv[1])
    }
    
    for (var i = 0; i < sessionStorageKV.length; i++) {
        var kv = sessionStorageKV[i]
        sessionStorage.setItem(kv[0], kv[1])
    }
}
