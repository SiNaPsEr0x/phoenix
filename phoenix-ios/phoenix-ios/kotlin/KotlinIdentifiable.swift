import Foundation
import PhoenixShared

extension Lightning_kmpUUID: @retroactive Identifiable {
	
	public var id: String {
		return self.description
	}
}

extension WalletPaymentId: @retroactive Identifiable {
	
	/// Returns a unique identifier, in the form of:
	/// - "outgoing|id"
	/// - "incoming|paymentHash"
	///
	public var id: String {
		return self.identifier // defined in WalletPayment.kt
	}
}

extension WalletPaymentOrderRow: @retroactive Identifiable {
	
	/// In kotlin the variable is called `id`, but that's a reserved property name in objective-c.
	/// So it gets automatically overwritten, and is inaccessible to us.
	/// Thus we'll provide an alternative property name that's easier to understand.
	public var walletPaymentId: WalletPaymentId {
		return self.kotlinId() // defined in PhoenixExposure.kt
	}
	
	/// Returns a unique identifier, in the form of:
	/// - "outgoing|id|createdAt|completedAt|metadataModifiedAt"
	/// - "incoming|paymentHash|createdAt|completedAt|metadataModifiedAt"
	///
	public var id: String {
		return self.identifier // defined in SqlitePaymentsDb.kt
	}
}

extension BitcoinUnit: @retroactive Identifiable {
	
	public var id: String {
		// BitcoinUnit is an enum in Kotlin.
		// So `.name` is guaranteed to be unique.
		return self.name
	}
}

extension FiatCurrency: @retroactive Identifiable {
	
	public var id: String {
		// FiatCurrency is an enum in Kotlin.
		// So `.name` is guaranteed to be unique.
		return self.name
	}
}

extension ContactInfo: @retroactive Identifiable {
	
	/// In kotlin the variable is called `id`, but that's a reserved property name in objective-c.
	/// So it gets automatically overwritten, and is inaccessible to us.
	/// Thus we'll provide an alternative property name that's easier to understand.
	public var uuid: Lightning_kmpUUID {
		return self.kotlinId() // defined in PhoenixExposure.kt
	}
	
	public var id: String {
		return self.uuid.description()
	}
}

extension Lightning_kmpWalletState.Utxo: @retroactive Identifiable {
	
	public var id: String {
		return "\(previousTx.txid.toHex()):\(outputIndex):\(blockHeight)"
	}
}

extension Lightning_kmpSensitiveTaskEventsTaskIdentifier.InteractiveTx: @retroactive Identifiable {
	
	public var id: String {
		return "\(self.channelId.toHex()):\(self.fundingTxIndex)"
	}
}
