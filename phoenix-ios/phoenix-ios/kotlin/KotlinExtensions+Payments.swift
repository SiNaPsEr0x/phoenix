import Foundation
import PhoenixShared


extension WalletPaymentOrderRow {
	
	var createdAtDate: Date {
		return createdAt.toDate(from: .milliseconds)
	}
	
	var completedAtDate: Date? {
		if let completedAt = self.completedAt?.int64Value {
			return completedAt.toDate(from: .milliseconds)
		} else {
			return nil
		}
	}
	
	/// Models the sorting done in the raw Sqlite queries.
	/// I.e.: `ORDER BY COALESCE(completed_at, created_at)`
	///
	/// See: AggregatedQueries.sq
	///
	var sortDate: Date {
		return completedAtDate ?? createdAtDate
	}
}

extension WalletPaymentInfo {
	
	func paymentDescription(includingUserDescription: Bool = true) -> String? {
		
		let sanitize = { (input: String?) -> String? in
			
			if let trimmedInput = input?.trimmingCharacters(in: .whitespacesAndNewlines) {
				if trimmedInput.count > 0 {
					return trimmedInput
				}
			}
			
			return nil
		}
		
		if includingUserDescription {
			if let description = sanitize(metadata.userDescription) {
				return description
			}
		}
		if let description = sanitize(metadata.lnurl?.description_) {
			return description
		}
		
		if let incomingPayment = payment as? Lightning_kmpIncomingPayment {
			
			if let invoice = incomingPayment.origin.asInvoice() {
				return sanitize(invoice.paymentRequest.description_)
			} else if let _ = incomingPayment.origin.asKeySend() {
				return NSLocalizedString("Donation", comment: "Payment description for received KeySend")
			} else if let swapIn = incomingPayment.origin.asSwapIn() {
				return sanitize(swapIn.address)
			}
			
		} else if let outgoingPayment = payment as? Lightning_kmpOutgoingPayment {
			
			if let normal = outgoingPayment.details.asNormal() {
				return sanitize(normal.paymentRequest.desc())
			} else if let _ = outgoingPayment.details.asKeySend() {
				return NSLocalizedString("Donation", comment: "Payment description for received KeySend")
			} else if let swapOut = outgoingPayment.details.asSwapOut() {
				return sanitize(swapOut.address)
			} else if let _ = outgoingPayment.details.asChannelClosing() {
				return NSLocalizedString("Channel closing", comment: "Payment description for channel closing")
			}
		}
		
		return nil
	}
}

extension WalletPaymentMetadata {
	
	static func empty() -> WalletPaymentMetadata {
		return WalletPaymentMetadata(
			lnurl: nil,
			originalFiat: nil,
			userDescription: nil,
			userNotes: nil,
			modifiedAt: nil
		)
	}
}

extension Lightning_kmpWalletPayment {
	
	func completedAtDate() -> Date? {
		
		let millis = self.completedAt()
		if millis > 0 {
			return millis.toDate(from: .milliseconds)
		} else {
			return nil
		}
	}	
}

extension Lightning_kmpIncomingPayment {
	
	var createdAtDate: Date {
		return createdAt.toDate(from: .milliseconds)
	}
}

extension Lightning_kmpIncomingPayment.Received {
	
	var receivedAtDate: Date {
		return receivedAt.toDate(from: .milliseconds)
	}
}

extension Lightning_kmpOutgoingPayment {
	
	var createdAtDate: Date {
		return createdAt.toDate(from: .milliseconds)
	}
}

extension Lightning_kmpOutgoingPayment.Part {
	
	var createdAtDate: Date {
		return createdAt.toDate(from: .milliseconds)
	}
}

extension Lightning_kmpOutgoingPayment.LightningPartStatusSucceeded {
	
	var completedAtDate: Date {
		return completedAt.toDate(from: .milliseconds)
	}
}

extension Lightning_kmpOutgoingPayment.LightningPartStatusFailed {
	
	var completedAtDate: Date {
		return completedAt.toDate(from: .milliseconds)
	}
}

extension Lightning_kmpOutgoingPayment.StatusCompleted {
	
	var completedAtDate: Date {
		return completedAt.toDate(from: .milliseconds)
	}
}

extension Lightning_kmpPaymentRequest {
	
	var timestampDate: Date {
		return timestampSeconds.toDate(from: .seconds)
	}
}