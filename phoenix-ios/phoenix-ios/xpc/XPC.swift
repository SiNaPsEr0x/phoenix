import Foundation
import Combine
import notify

fileprivate let filename = "XPC"
#if DEBUG && true
fileprivate var log = LoggerFactory.shared.logger(filename, .trace)
#else
fileprivate var log = LoggerFactory.shared.logger(filename, .warning)
#endif

enum XpcActor: CustomStringConvertible {
	case mainApp
	case notifySrvExt
	
	var description: String {
		switch self {
			case .mainApp      : return "mainApp"
			case .notifySrvExt : return "notifySrvExt"
		}
	}
}

enum XpcMessage: CustomStringConvertible {
	case available
	case unavailable
	
	var description: String {
		switch self {
			case .available   : return "available"
			case .unavailable : return "unavailable"
		}
	}
}

fileprivate let msgPing_mainApp: UInt64             = 0b0001
fileprivate let msgPong_mainApp: UInt64             = 0b0010
fileprivate let msgUnavailable_mainApp: UInt64      = 0b0011

fileprivate let msgPing_notifySrvExt: UInt64        = 0b0100
fileprivate let msgPong_notifySrvExt: UInt64        = 0b1000
fileprivate let msgUnavailable_notifySrvExt: UInt64 = 0b1100


/**
 * This class uses mach messaging to communicate between the main app & notifySrvExt background process.
 * The communication is minimal, and is designed to allow each process to know if the other is running.
 *
 * Architecture notes:
 *
 * To use mach messaging, we have to create a channel using a name.
 * However, any other process on the system (including other apps)
 * can use this channel if they know the name.
 * For this reason, we don't use a hard-coded name.
 * Instead we randomly generate a name (using a UUID), and write the name to a file.
 * The file is stored in the shared container for Phoenix,
 * so it can only be read by the main app & notifySrv process.
 *
 * There are only 3 messages we send/receive on the channel:
 * - ping
 * - pong
 * - unavailable
 *
 * Each message is unique per-process, so it can easily be determined which process sent the message.
 * When the process starts, it posts a ping message to the channel.
 * When a process receives a ping message from the other process, it responds with a pong.
 * When a process suspends, it posts an unavailable message.
 *
 * Using these simple primitives, we're able to determine if the other process is active.
 */
class XPC {
	
	private let actor: XpcActor
	
	private let queue = DispatchQueue(label: "XPC")
	private let channelPrefix = "co.acinq.phoenix"
	private let groupIdentifier = "group.co.acinq.phoenix"
	
	private var channel: String? = nil
	private var notifyToken: Int32 = NOTIFY_TOKEN_INVALID
	private var suspendCount: UInt32 = 1 // You have to call resume() to start XPC
	
	public let receivedMessagePublisher = PassthroughSubject<XpcMessage, Never>()

	init(actor: XpcActor) {
		log.trace("init(\(actor))")
		
		self.actor = actor
		
		DispatchQueue.global(qos: .utility).async {
			self.readChannelID()
		}
	}
	
	deinit {
		log.trace("deinit()")
		
		if notify_is_valid_token(notifyToken) {
			notify_cancel(notifyToken)
			notifyToken = NOTIFY_TOKEN_INVALID
		}
	}
	
	// --------------------------------------------------
	// MARK: Public Functions
	// --------------------------------------------------
	
	public func suspend() {
		
		queue.async { [self] in
			log.trace("suspend()")
			
			guard suspendCount < UInt32.max else {
				log.warning("suspend(): suspendCount is already at UInt32.max")
				return
			}
			
			suspendCount += 1
			log.debug("suspendCount = \(suspendCount)")

			if suspendCount == 1, notify_is_valid_token(notifyToken) {
				sendUnavailableMessage()
				
				log.debug("notify_suspend()")
				notify_suspend(notifyToken)
			}
		}
	}
	
	public func resume() {
		
		queue.async { [self] in
			log.trace("resume()")
			
			guard suspendCount > 0 else {
				log.warning("resume(): suspendCount is already at 0")
				return
			}
			
			suspendCount -= 1
			log.debug("suspendCount = \(suspendCount)")
			
			if suspendCount == 0, notify_is_valid_token(notifyToken) {
				log.debug("notify_resume()")
				notify_resume(notifyToken)
				
				sendPingMessage()
			}
		}
	}
	
	// --------------------------------------------------
	// MARK: Logic
	// --------------------------------------------------
	
	private func readChannelID() {
		log.trace("readChannelID()")
		
		let fm = FileManager.default
		guard let groupDir = fm.containerURL(forSecurityApplicationGroupIdentifier: groupIdentifier) else {
			fatalError("FileManager returned nil containerUrl !")
		}
		
		let fileURL = groupDir.appendingPathComponent("xpc.id", isDirectory: false)
		let fileCoordinator = NSFileCoordinator()
		
		var uuid = UUID()
		var error: NSError? = nil
		
		// `NSFileCoordinator.coordinate()`:
		// This method executes **synchronously**,
		// blocking the current thread until the reader/write block finishes executing.
		//
		fileCoordinator.coordinate(readingItemAt: fileURL, writingItemAt: fileURL, error: &error) { readURL, writeURL in
			
			var fileContent: String? = nil
			if fm.fileExists(atPath: readURL.path) {
				do {
					fileContent = try String(contentsOf: readURL, encoding: .utf8)
				} catch {
					log.error("Error reading xpc.id: \(String(describing: error))")
				}
			}
			
			// E621E1F8-C36C-495A-93FC-0C247A3E6E5F
			// 123456789012345678901234567890123456
			//          ^         ^         ^
			
			var existingUUID: UUID? = nil
			if let fileContent = fileContent {
				
				let uuidString = String(fileContent.prefix(36))
				existingUUID = UUID(uuidString: uuidString)
			}
			
			if let existingUUID = existingUUID {
				uuid = existingUUID
			} else {
				
				let uuidData = uuid.uuidString.data(using: .utf8)
				do {
					try uuidData?.write(to: writeURL)
				} catch {
					log.error("Error writing xpc.id: \(String(describing: error))")
				}
			}
		}
		
		if let error = error {
			log.error("NSFileCoordinator: error: \(String(describing: error))")
		}
		
		let channelID = uuid.uuidString
		queue.async {
			self.registerChannel(channelID)
		}
	}
	
	private func registerChannel(_ channelID: String) {
		log.trace("register()")
		
		guard !notify_is_valid_token(notifyToken) else {
			log.debug("ignoring: channel is already registered")
			return
		}
		
		let channel = "\(channelPrefix).\(channelID)"
		self.channel = channel
		
		notify_register_dispatch(
			/* name      :*/ (channel as NSString).utf8String,
			/* out_token :*/ &notifyToken,
			/* queue     :*/ queue
		) {[weak self](token: Int32) in
			
			guard let self = self else {
				return
			}
			guard self.suspendCount == 0 else {
				log.info("ignoring received message: suspended")
				return
			}
			
			var msg: UInt64 = 0
			notify_get_state(token, &msg)
			
			self.receiveMessage(msg)
		}
		
		if notify_is_valid_token(notifyToken) {
			
			if suspendCount > 0 {
				log.debug("notify_suspend()")
				notify_suspend(notifyToken)
				
			} else {
				sendPingMessage()
			}
		}
	}
	
	private func receiveMessage(_ msg: UInt64) {
		
		let msgStr = messageToString(msg)
		switch actor {
		case .mainApp:
			
			switch msg {
			case msgPing_mainApp : fallthrough
			case msgPong_mainApp : fallthrough
			case msgUnavailable_mainApp:
				log.debug("ignorning own message: \(msgStr)")
				
			case msgPing_notifySrvExt:
				log.debug("received message: \(msgStr)")
				notifyReceivedMessage(.available)
				sendPongMessage()
				
			case msgPong_notifySrvExt:
				log.debug("received message: \(msgStr)")
				notifyReceivedMessage(.available)
				
			case msgUnavailable_notifySrvExt:
				log.debug("received message: \(msgStr)")
				notifyReceivedMessage(.unavailable)
				
			default:
				log.debug("received unknown message: \(msg)")
				
			} // </switch msg>
			
		case .notifySrvExt:
			
			switch msg {
			case msgPing_notifySrvExt: fallthrough
			case msgPong_notifySrvExt: fallthrough
			case msgUnavailable_notifySrvExt:
				log.debug("ignorning own message: \(msgStr)")
				
			case msgPing_mainApp:
				log.debug("received message: \(msgStr)")
				notifyReceivedMessage(.available)
				sendPongMessage()
				
			case msgPong_mainApp:
				log.debug("received message: \(msgStr)")
				notifyReceivedMessage(.available)
				
			case msgUnavailable_mainApp:
				log.debug("received message: \(msgStr)")
				notifyReceivedMessage(.unavailable)
				
			default:
				log.debug("received unknown message: \(msg)")
				
			} // </switch msg>
		} // </switch actor>
	}
	
	private func sendPingMessage() {
		switch actor {
			case .mainApp      : sendMessage(msgPing_mainApp)
			case .notifySrvExt : sendMessage(msgPing_notifySrvExt)
		}
	}
	
	private func sendPongMessage() {
		switch actor {
			case .mainApp      : sendMessage(msgPong_mainApp)
			case .notifySrvExt : sendMessage(msgPong_notifySrvExt)
		}
	}
	
	private func sendUnavailableMessage() {
		switch actor {
			case .mainApp      : sendMessage(msgUnavailable_mainApp)
			case .notifySrvExt : sendMessage(msgUnavailable_notifySrvExt)
		}
	}
	
	private func sendMessage(_ msg: UInt64) {
		log.trace("sendMessage(\(messageToString(msg)))")
		
		guard notify_is_valid_token(notifyToken), let channel = channel else {
			log.debug("sendMessage(\(messageToString(msg))): ignoring: channel not setup yet")
			return
		}
		
		notify_set_state(notifyToken, msg)
		notify_post((channel as NSString).utf8String)
	}
	
	// --------------------------------------------------
	// MARK: Utilities
	// --------------------------------------------------
	
	private func messageToString(_ msg: UInt64) -> String {
		
		switch msg {
			case msgPing_mainApp             : return "ping(from:mainApp)"
			case msgPong_mainApp             : return "pong(from:mainApp)"
			case msgUnavailable_mainApp      : return "unavailable(from:mainApp)"
			case msgPing_notifySrvExt        : return "ping(from:notifySrvExt)"
			case msgPong_notifySrvExt        : return "pong(from:notifySrvExt)"
			case msgUnavailable_notifySrvExt : return "unavailable(from:notifySrvExt)"
			default                          : return "unknown"
		}
	}
	
	private func notifyReceivedMessage(_ msg: XpcMessage) {
		log.trace("notifyReceivedMessage()")
		
		DispatchQueue.main.async {
			self.receivedMessagePublisher.send(msg)
		}
	}
}

