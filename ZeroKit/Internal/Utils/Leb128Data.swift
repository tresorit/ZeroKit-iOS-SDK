import Foundation

class Leb128InData: ByteIn {
    let data: Data
    private(set) var index = 0
    
    init(data: Data) {
        self.data = data
    }
    
    func read() -> UInt8 {
        guard index < data.count else {
            return 0
        }
        let value = data[index]
        index += 1
        return value
    }
}

class Leb128OutData: ByteOut {
    private var data = Data()
    
    var index: Int {
        return data.count
    }
    
    var leb128Data: Data {
        return data
    }
    
    func write(_ byte: UInt8) {
        data.append(byte)
    }
}
