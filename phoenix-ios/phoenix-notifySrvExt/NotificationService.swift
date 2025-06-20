import UserNotifications
import PhoenixShared
import Combine
import notify

fileprivate let filename = "NotificationService"
#if DEBUG && true
fileprivate var log = LoggerFactory.shared.logger(filename, .trace)
#else
fileprivate var log = LoggerFactory.shared.logger(filename, .warning)
#endif

/**
 * What happens if multiple push notifications arrive ?
 *
 * iOS will launch the notification-service-extension upon receiving the first push notification.
 * Subsequent push notifications are queued by the OS. After the app extension finishes processing
 * the first notification (by invoking the `contentHandler`), then iOS will:
 *
 * - display the first push notification
 * - dealloc the `UNNotificationServiceExtension`
 * - Initialize a new `UNNotificationServiceExtension` instance
 * - And invoke it's `didReceive(_:)` function with the next item in the queue
 *
 * Note that it does **NOT** create a new app extension process.
 * It re-uses the existing process, and launches a new `UNNotificationServiceExtension` within it.
 *
 * This means that the following instances are recycled (continue existing in memory):
 * - PhoenixManager.shared
 * - NotificationServiceQueue.shared
 * - XPC.shared
 */
class NotificationService: UNNotificationServiceExtension {

	enum PushNotificationReason: CustomStringConvertible {
		case incomingPayment
		case incomingOnionMessage
		case pendingSettlement
		case unknown
		
		var description: String {
			switch self {
				case .incomingPayment      : return "incomingPayment"
				case .incomingOnionMessage : return "incomingOnionMessage"
				case .pendingSettlement    : return "pendingSettlement"
				case .unknown              : return "unknown"
			}
		}
	}
	
	private var contentHandler: ((UNNotificationContent) -> Void)?
	private var remoteNotificationContent: UNMutableNotificationContent?
	
	private var xpcStarted: Bool = false
	private var phoenixStarted: Bool = false
	private var srvExtDone: Bool = false
	
	private var business: PhoenixBusiness? = nil
	private var pushNotificationReason: PushNotificationReason = .unknown
	
	private var isConnectedToPeer = false
	private var receivedPayments: [Lightning_kmpIncomingPayment] = []
	
	private var totalTimer: Timer? = nil
	private var connectionTimer: Timer? = nil
	private var postReceivedPaymentTimer: Timer? = nil
	
	private var cancellables = Set<AnyCancellable>()
	
	override func didReceive(
		_ request: UNNotificationRequest,
		withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
	) {
		let selfPtr: String = Unmanaged.passUnretained(self).toOpaque().debugDescription
		
		log.trace("instance => \(selfPtr)")
		log.trace("didReceive(request:withContentHandler:)")
		log.trace("request.content.userInfo: \(request.content.userInfo)")
		
		self.contentHandler = contentHandler
		self.remoteNotificationContent = (request.content.mutableCopy() as? UNMutableNotificationContent)
		
		// IMPORTANT: This function is called on a NON-main thread.
		// 
		// And Kotlin-KMM has an unworkable threading policy that requires
		// everything to be on the main thread...
		DispatchQueue.main.async {
			
			self.startTotalTimer()
			self.processNotification(request.content.userInfo)
			self.startXpc()
			self.startPhoenix()
		}
	}
	
	override func serviceExtensionTimeWillExpire() {
		log.trace("serviceExtensionTimeWillExpire()")
		
		// iOS calls this function just before the extension will be terminated by the system.
		// Use this as an opportunity to deliver your "best attempt" at modified content,
		// otherwise the original push payload will be used.
		
		// IMPORTANT: This function is called on a NON-main thread.
		DispatchQueue.main.async {
			self.finish()
		}
	}
	
	// --------------------------------------------------
	// MARK: Notification Processing
	// --------------------------------------------------
	
	private func processNotification(_ userInfo: [AnyHashable : Any]) {
		log.trace("processNotification()")
		assertMainThread()
		
		// This could be a push notification coming from either:
		// - Google's Firebase Cloud Messaging (FCM)
		// - Amazon Web Services (AWS) (only used for debugging)
		
		if isFCM(userInfo) {
			processNotification_fcm(userInfo)
		} else {
			processNotification_aws(userInfo)
		}
	}
	
	private func isFCM(_ userInfo: [AnyHashable : Any]) -> Bool {
			
		/* This could be a push notification coming from Google Firebase or from AWS.
		 *
		 * Example from Google FCM:
		 * {
		 *   "aps": {
		 *     "alert": {
		 *       "title": "foobar"
		 *     }
		 *     "mutable-content": 1
		 *   },
		 *   "reason": "IncomingPayment",
		 *   "gcm.message_id": 1676919817341932,
		 *   "google.c.a.e": 1,
		 *   "google.c.fid": "f7Wfr_yqG00Gt6B9O7qI13",
		 *   "google.c.sender.id": 358118532563
		 * }
		 *
		 * Example from AWS:
		 * {
		 *   "aps": {
		 *     "alert": {
		 *       "title": "Missed incoming payment"
		 *     }
		 *     "mutable-content": 1
		 *   },
		 *   "acinq": {
		 *     "amt": 120000,
		 *     "h": "d48bf163c0e24d68567e80b10cc7dd583e2f44390c9592df56a61f79559611e6",
		 *     "n": "02ed721545840184d1544328059e8b20c01965b73b301a7d03fc89d3d84aba0642",
		 *     "t": "invoice",
		 *     "ts": 1676920273561
		 *   }
		 * }
		 */
		
		return userInfo["gcm.message_id"]     != nil ||
		       userInfo["google.c.a.e"]       != nil ||
		       userInfo["google.c.fid"]       != nil ||
		       userInfo["google.c.sender.id"] != nil ||
		       userInfo["reason"]             != nil // just in-case google changes format
	}
	
	private func processNotification_fcm(_ userInfo: [AnyHashable : Any]) {
		log.trace("processNotification_fcm()")
		assertMainThread()
		
		// Example:
		// {
		//   "gcm.message_id": 1605136272123442,
		//   "google.c.sender.id": 458618232423,
		//   "google.c.a.e": 1,
		//   "google.c.fid": "dRLLO-mxUxbDvmV1urj5Tt",
		//   "reason": "IncomingPayment",
		//   "aps": {
		//     "alert": {
		//       "title": "Missed incoming payment",
		//     },
		//     "mutable-content": 1
		//   }
		// }
		
		if let reason = userInfo["reason"] as? String {
			log.debug("userInfo.reason: '\(reason)'")
			
			switch reason {
				case "IncomingPayment"       : pushNotificationReason = .incomingPayment
				case "IncomingOnionMessage$" : pushNotificationReason = .incomingOnionMessage
				case "PendingSettlement"     : pushNotificationReason = .pendingSettlement
				default                      : pushNotificationReason = .unknown
			}
		} else {
			log.debug("userInfo.reason: !string")
			pushNotificationReason = .unknown
		}
		
		log.debug("pushNotificationReason = \(pushNotificationReason)")
		
		// Nothing else to do here.
		// These types of requests are handled automatically by the Peer.
	}
	
	private func processNotification_aws(_ userInfo: [AnyHashable : Any]) {
		log.trace("processNotification_aws()")
		assertMainThread()
		
		pushNotificationReason = .unknown
		log.debug("pushNotificationReason = \(pushNotificationReason)")
		
		return finish()
	}
	
	// --------------------------------------------------
	// MARK: Timers
	// --------------------------------------------------
	
	private func startTotalTimer() {
		log.trace("startTotalTimer()")
		assertMainThread()
		
		guard !srvExtDone else {
			log.debug("startTotalTimer(): ignoring: srvExtDone")
			return
		}
		guard totalTimer == nil else {
			log.debug("startTotalTimer(): ignoring: already started")
			return
		}
		
		// The OS gives us 30 seconds to fetch data, and then invoke the completionHandler.
		// Failure to properly "clean up" in this way will result in the OS reprimanding us.
		// So we set a timer to ensure we stop before the max allowed.
		totalTimer = Timer.scheduledTimer(
			withTimeInterval : 29.5,
			repeats          : false
		) {[weak self](_: Timer) -> Void in
			
			if let self {
				log.debug("totalTimer.fire()")
				self.finish()
			}
		}
	}
	
	private func startConnectionTimer() {
		log.trace("startConnectionTimer()")
		assertMainThread()
		
		guard !srvExtDone else {
			log.debug("startConnectionTimer(): ignoring: srvExtDone")
			return
		}
		guard connectionTimer == nil else {
			log.debug("startConnectionTimer(): ignoring: already started")
			return
		}
		
		log.debug("GroupPrefs.shared.srvExtConnection = now")
		GroupPrefs.shared.srvExtConnection = Date.now
		
		connectionTimer = Timer.scheduledTimer(
			withTimeInterval : 2.0,
			repeats          : true
		) {[weak self](_: Timer) in
		
			if let _ = self {
				log.debug("connectionsTimer.fire()")
				log.debug("GroupPrefs.shared.srvExtConnection = now")
				GroupPrefs.shared.srvExtConnection = Date.now
			}
		}
	}
	
	private func startPostReceivedPaymentTimer() {
		log.trace("startPostReceivedPaymentTimer()")
		assertMainThread()
		
		// This method is called everytime we receive a payment,
		// and it's possible we receive multiple payments.
		// So for every payment, we want to restart the timer.
		postReceivedPaymentTimer?.invalidate()
		
	#if DEBUG
		let delay: TimeInterval = 5.0
	#else
		let delay: TimeInterval = 5.0
	#endif
		
		postReceivedPaymentTimer = Timer.scheduledTimer(
			withTimeInterval : delay,
			repeats          : false
		) {[weak self](_: Timer) -> Void in
			
			if let self {
				log.debug("postReceivedPaymentTimer.fire()")
				self.finish()
			}
		}
	}
	
	// --------------------------------------------------
	// MARK: XPC
	// --------------------------------------------------
	
	private func startXpc() {
		log.trace("startXpc()")
		assertMainThread()
		
		guard !srvExtDone else {
			log.debug("startXpc(): ignoring: srvExtDone")
			return
		}
		guard !xpcStarted else {
			log.debug("startXpc(): ignoring: already started")
			return
		}
		xpcStarted = true
		
		XPC.shared.receivedMessagePublisher.sink {[weak self](msg: XpcMessage) in
			self?.didReceiveXpcMessage(msg)
		}.store(in: &cancellables)
		
		XPC.shared.resume()
	}
	
	private func stopXpc() {
		log.trace("stopXpc()")
		assertMainThread()
		
		guard xpcStarted else {
			log.debug("stopXpc(): ignoring: already stopped")
			return
		}
		xpcStarted = false
		
		XPC.shared.suspend()
	}
	
	private func didReceiveXpcMessage(_ msg: XpcMessage) {
		log.trace("didReceiveXpcMessage()")
		assertMainThread()
		
		if msg == .available {
			
			// The main phoenix app is running.
			
			if isConnectedToPeer {
				
				// But we're already connected to the peer, and processing the payment.
				// So we're going to continue working on the payment,
				// and the main app will have to wait for us to finish before connecting to the peer itself.
				
				log.debug("isConnectedToPeer is true => continue processing incoming payment")
				
			} else {
				
				// Since we're not connected yet, we'll just allow the main app to handle the payment.
				//
				// And we don't have to wait for the main app to finish handling the payment.
				// Because whatever we emit from this app extension won't be displayed to the user.
				// That is, the modified push content we emit isn't actually shown to the user.
				
				finish()
			}
		}
	}
	
	// --------------------------------------------------
	// MARK: Phoenix
	// --------------------------------------------------
	
	private func startPhoenix() {
		log.trace("startPhoenix()")
		assertMainThread()
		
		guard !srvExtDone else {
			log.debug("startPhoenix(): ignoring: srvExtDone")
			return
		}
		guard !phoenixStarted else {
			log.debug("startPhoenix(): ignoring: already started")
			return
		}
		phoenixStarted = true
		
		let newBusiness = PhoenixManager.shared.setupBusiness()
		business = newBusiness
		
		newBusiness.connectionsManager.connectionsPublisher().sink {
			[weak self](connections: Connections) in
				
			self?.connectionsChanged(connections)
		}
		.store(in: &cancellables)
			
		let pushReceivedAt = Date()
		newBusiness.paymentsManager.lastIncomingPaymentPublisher().sink {
			[weak self](payment: Lightning_kmpIncomingPayment) in
			
			guard
				let paymentReceivedAt = payment.completedAtDate,
				paymentReceivedAt > pushReceivedAt
			else {
				// Ignoring - this is the most recently received incomingPayment, but not a new one
				return
			}
			
			self?.didReceivePayment(payment)
		}
		.store(in: &cancellables)
	}
	
	private func stopPhoenix() {
		log.trace("stopPhoenix()")
		assertMainThread()
		
		guard phoenixStarted else {
			log.debug("stopPhoenix(): ignoring: already stopped")
			return
		}
		phoenixStarted = false
		
		PhoenixManager.shared.teardownBusiness()
		business = nil
	}
	
	private func connectionsChanged(_ connections: Connections) {
		log.trace("connectionsChanged(): isConnectedToPeer = \(connections.peer.isEstablished())")
		assertMainThread()
		
		isConnectedToPeer = connections.peer.isEstablished()
		if isConnectedToPeer && !srvExtDone {
			startConnectionTimer()
		}
	}
	
	private func didReceivePayment(_ payment: Lightning_kmpIncomingPayment) {
		log.trace("didReceivePayment()")
		assertMainThread()
		
		receivedPayments.append(payment)
		if !srvExtDone {
			startPostReceivedPaymentTimer()
		}
	}
	
	// --------------------------------------------------
	// MARK: Finish
	// --------------------------------------------------
	
	private func finish() {
		log.trace("finish()")
		assertMainThread()
		
		guard !srvExtDone else {
			return
		}
		srvExtDone = true
		
		guard let contentHandler, let remoteNotificationContent else {
			log.error("finish(): invalid state")
			return
		}
		
		totalTimer?.invalidate()
		totalTimer = nil
		connectionTimer?.invalidate()
		connectionTimer = nil
		postReceivedPaymentTimer?.invalidate()
		postReceivedPaymentTimer = nil
		stopXpc()
		stopPhoenix()
		
		updateRemoteNotificationContent(remoteNotificationContent)
		displayLocalNotificationsForAdditionalPayments()
		contentHandler(remoteNotificationContent)
	}
	
	private func updateRemoteNotificationContent(
		_ content: UNMutableNotificationContent
	) {
		log.trace("updateRemoteNotificationContent()")
		
		// The first thing we need to do is switch on the type of notification that we received
		
		switch pushNotificationReason {
		case .incomingPayment:
			// We expected to receive 1 or more incoming payments
			
			if let item = NotificationServiceQueue.shared.dequeue() {
				updateNotificationContent_localNotification(content, item)
			} else if let payment = popFirstReceivedPayment() {
				updateNotificationContent_receivedPayment(content, payment)
			} else {
				updateNotificationContent_missedPayment(content)
			}
		
		case .incomingOnionMessage:
			// This is probably an incoming Bolt 12 payment.
			// But it could be anything, so let's code defensively.
			
			if let item = NotificationServiceQueue.shared.dequeue() {
				updateNotificationContent_localNotification(content, item)
			} else if let payment = popFirstReceivedPayment() {
				updateNotificationContent_receivedPayment(content, payment)
			} else {
				updateNotificationContent_unknown(content)
			}
			
		case .pendingSettlement:
			updateNotificationContent_pendingSettlement(content)
		
		case .unknown:
			updateNotificationContent_unknown(content)
		}
	}
	
	private func displayLocalNotificationsForAdditionalPayments() {
		log.trace("displayLocalNotificationsForAdditionalPayments()")
		
		for additionalPayment in receivedPayments {
			log.debug("processing additional payment...")
			
			let identifier = UUID().uuidString
			let content = UNMutableNotificationContent()
			updateNotificationContent_receivedPayment(content, additionalPayment)
			
			// Display local notification
			let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
			UNUserNotificationCenter.current().add(request)
			
			// Add to queue
			NotificationServiceQueue.shared.enqueue(identifier: identifier, content: content)
		}
	}
	
	// --------------------------------------------------
	// MARK: Notification Content
	// --------------------------------------------------
	
	private func updateNotificationContent_localNotification(
		_ content: UNMutableNotificationContent,
		_ item: NotificationServiceQueue.Item
	) {
		log.trace("updateNotification_localNotification()")
		
		content.title = item.content.title
		content.body = item.content.body
		content.badge = item.content.badge
		content.targetContentIdentifier = item.content.targetContentIdentifier
		
		UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [item.identifier])
	}
	
	private func updateNotificationContent_receivedPayment(
		_ content: UNMutableNotificationContent,
		_ payment: Lightning_kmpIncomingPayment
	) {
		log.trace("updateNotificationContent_incomingPayment()")
		
		content.title = String(localized: "Received payment", comment: "Push notification title")
			
		if !GroupPrefs.shared.discreetNotifications {
			let paymentInfo = WalletPaymentInfo(
				payment: payment,
				metadata: WalletPaymentMetadata.empty(),
				contact: nil
			)
			
			let amountString = formatAmount(msat: payment.amount.msat)
			if let desc = paymentInfo.paymentDescription(), desc.count > 0 {
				content.body = "\(amountString): \(desc)"
			} else {
				content.body = amountString
			}
		}
		
		content.targetContentIdentifier = payment.id.description()
		
		// The user can independently enable/disable:
		// - alerts
		// - badges
		// So we may only be able to badge the app icon, and that's it.
		
		GroupPrefs.shared.badgeCount += 1
		content.badge = NSNumber(value: GroupPrefs.shared.badgeCount)
	}
	
	private func updateNotificationContent_missedPayment(
		_ content: UNMutableNotificationContent
	) {
		log.trace("updateNotificationContent_missedPayment()")
		
		content.title = String(localized: "Missed incoming payment", comment: "")
	}
	
	private func updateNotificationContent_pendingSettlement(
		_ content: UNMutableNotificationContent
	) {
		log.trace("updateNotificationContent_pendingSettlement")
		
		content.title = String(localized: "Please start Phoenix", comment: "")
		content.body = String(localized: "An incoming settlement is pending.", comment: "")
	}
	
	private func updateNotificationContent_unknown(
		_ content: UNMutableNotificationContent
	) {
		log.trace("updateNotificationContent_unknown()")
		
		let fiatCurrency = GroupPrefs.shared.fiatCurrency
		let exchangeRate = PhoenixManager.shared.exchangeRate(fiatCurrency: fiatCurrency)
		
		if let exchangeRate {
			let fiatAmt = Utils.formatFiat(amount: exchangeRate.price, fiatCurrency: exchangeRate.fiatCurrency)
			
			content.title = String(localized: "Current bitcoin price", comment: "")
			content.body = fiatAmt.string
			
		} else {
			content.title = String(localized: "Current bitcoin price", comment: "")
			content.body = "?"
		}
	}
	
	// --------------------------------------------------
	// MARK: Utils
	// --------------------------------------------------
	
	private func popFirstReceivedPayment() -> Lightning_kmpIncomingPayment? {
		
		if receivedPayments.isEmpty {
			return nil
		} else {
			return receivedPayments.removeFirst()
		}
	}
	
	private func formatAmount(msat: Int64) -> String {
		
		let bitcoinUnit = GroupPrefs.shared.bitcoinUnit
		let fiatCurrency = GroupPrefs.shared.fiatCurrency
		let exchangeRate = PhoenixManager.shared.exchangeRate(fiatCurrency: fiatCurrency)
		
		let bitcoinAmt = Utils.formatBitcoin(msat: msat, bitcoinUnit: bitcoinUnit)
		var amountString = bitcoinAmt.string
		
		if let exchangeRate {
			let fiatAmt = Utils.formatFiat(msat: msat, exchangeRate: exchangeRate)
			amountString += " (≈\(fiatAmt.string))"
		}
		
		return amountString
	}
}
