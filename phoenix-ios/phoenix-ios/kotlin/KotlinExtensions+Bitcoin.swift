import Foundation
import PhoenixShared
import CryptoKit


extension Bitcoin_kmpSatoshi {
	
	func toMilliSatoshi() -> Lightning_kmpMilliSatoshi {
		return Lightning_kmpMilliSatoshi(sat: self)
	}
	
	func toMsat() -> Int64 {
		return self.toLong() * Utils.Millisatoshis_Per_Satoshi
	}
}

extension Bitcoin_kmpTxId {
	
	func toHex() -> String {
		return self.value.toHex()
	}
}

extension Bitcoin_kmpByteVector32 {
	
	static func random() -> Bitcoin_kmpByteVector32 {
		
		let key = SymmetricKey(size: .bits256) // 256 / 8 = 32
		
		let data = key.withUnsafeBytes {(bytes: UnsafeRawBufferPointer) -> Data in
			return Data(bytes: bytes.baseAddress!, count: bytes.count)
		}
		
		return Bitcoin_kmpByteVector32(bytes: data.toKotlinByteArray())
	}
}
