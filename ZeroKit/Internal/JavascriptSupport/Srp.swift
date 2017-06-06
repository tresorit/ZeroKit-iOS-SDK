import JavaScriptCore

@objc protocol SrpJSExport: JSExport {
    func newSession(_ N: NSString, _ g: NSString) -> SrpClient?
    func generatePubA(_ client: SrpClient) -> NSString?
    func calculateSecret(_ client: SrpClient, _ x: NSString, _ serverB: NSString) -> NSString?
    func calculateClientEvidence(_ client: SrpClient) -> NSString?
    func verifyServerEvidenceMessage(_ client: SrpClient, _ serverProof: NSString) -> Bool
    func calculateVerifier(_ client: SrpClient, _ x: NSString) -> NSString?
}

class Srp: NSObject, SrpJSExport {
    
    private var clients = [SrpClient]()
    
    deinit {
        cleanUpClients()
    }
    
    func cleanUpClients() {
        zk_synchronized {
            for client in clients {
                client.free()
            }
            clients.removeAll()
        }
    }
    
    func newSession(_ N: NSString, _ g: NSString) -> SrpClient? {
        let client = SrpClient(N: N, g: g)
        if let client = client {
            zk_synchronized {
                clients.append(client)
            }
        }
        return client
    }
    
    func generatePubA(_ client: SrpClient) -> NSString? {
        if let ptr = client.clientPtr, let pubA = srp6ClientGenerateClientCredentials(ptr) {
            return String(data: Data(bytes: UnsafeRawPointer(pubA), count: Int(strlen(pubA))), encoding: .utf8)! as NSString
        }
        return nil
    }
    
    func calculateSecret(_ client: SrpClient, _ x: NSString, _ serverB: NSString) -> NSString? {
        if let ptr = client.clientPtr, let secret = srp6ClientCalculateSecret(ptr, x.utf8String, serverB.utf8String) {
            return String(data: Data(bytes: UnsafeRawPointer(secret), count: Int(strlen(secret))), encoding: .utf8)! as NSString
        }
        return nil
    }
    
    func calculateClientEvidence(_ client: SrpClient) -> NSString? {
        if let ptr = client.clientPtr, let evidence = srp6ClientCalculateClientEvidenceMessage(ptr) {
            return String(data: Data(bytes: UnsafeRawPointer(evidence), count: Int(strlen(evidence))), encoding: .utf8)! as NSString
        }
        return nil
    }
    
    func verifyServerEvidenceMessage(_ client: SrpClient, _ serverProof: NSString) -> Bool {
        if let ptr = client.clientPtr {
            return srp6ClientVerifyServerEvidenceMessage(ptr, serverProof.utf8String) == 1
        }
        return false
    }
    
    func calculateVerifier(_ client: SrpClient, _ x: NSString) -> NSString? {
        if let ptr = client.clientPtr, let verifier = srp6ClientCalculateVerifier(ptr, x.utf8String) {
            return String(data: Data(bytes: UnsafeRawPointer(verifier), count: Int(strlen(verifier))), encoding: .utf8)! as NSString
        }
        return nil
    }
}

class SrpClient: NSObject {
    private(set) var clientPtr: UnsafeMutableRawPointer?
    
    init?(N: NSString, g: NSString) {
        if let newClient = srp6ClientNew(N.utf8String, g.utf8String) {
            clientPtr = newClient
        } else {
            return nil
        }
    }
    
    func free() {
        if let ptr = clientPtr {
            clientPtr = nil
            srp6ClientFree(ptr)
        }
    }
    
    deinit {
        free()
    }
}
