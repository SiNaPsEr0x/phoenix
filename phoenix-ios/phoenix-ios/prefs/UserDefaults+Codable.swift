import SwiftUI
import PhoenixShared

extension Encodable {
	func jsonEncode() -> Data? {
		return try? JSONEncoder().encode(self)
	}
}

extension Data {
	func jsonDecode<Element: Decodable>() -> Element? {
		return try? JSONDecoder().decode(Element.self, from: self)
	}
}

/**
 * Here we define various types stored in UserDefaults, which conform to `Codable`.
 */

enum CurrencyType: String, CaseIterable, Codable {
	case fiat
	case bitcoin
}

enum Theme: String, CaseIterable, Codable {
	case light
	case dark
	case system
	
	func localized() -> String {
		switch self {
		case .light  : return NSLocalizedString("Light", comment: "App theme option")
		case .dark   : return NSLocalizedString("Dark", comment: "App theme option")
		case .system : return NSLocalizedString("System", comment: "App theme option")
		}
	}
	
	func toInterfaceStyle() -> UIUserInterfaceStyle {
		switch self {
		case .light  : return .light
		case .dark   : return .dark
		case .system : return .unspecified
		}
	}
	
	func toColorScheme() -> ColorScheme? {
		switch self {
		case .light  : return ColorScheme.light
		case .dark   : return ColorScheme.dark
		case .system : return nil
		}
	}
}

enum PushPermissionQuery: String, Codable {
	case neverAskedUser
	case userDeclined
	case userAccepted
}

struct ElectrumConfigPrefs: Equatable, Codable {
	let host: String
	let port: UInt16
	let pinnedPubKey: String?
	let requireOnionIfTorEnabled: Bool?
	
	private let version: Int // for potential future upgrades
	
	init(host: String, port: UInt16, pinnedPubKey: String?, requireOnionIfTorEnabled: Bool?) {
		self.host = host
		self.port = port
		self.pinnedPubKey = pinnedPubKey
		self.requireOnionIfTorEnabled = requireOnionIfTorEnabled
		self.version = 3
	}
	
	var serverAddress: Lightning_kmpServerAddress {
		if let pinnedPubKey = pinnedPubKey {
			return Lightning_kmpServerAddress(
				host : host,
				port : Int32(port),
				tls  : Lightning_kmpTcpSocketTLS.PINNED_PUBLIC_KEY(pubKey: pinnedPubKey)
			)
		} else {
			return Lightning_kmpServerAddress(
				host : host,
				port : Int32(port),
				tls  : Lightning_kmpTcpSocketTLS.TRUSTED_CERTIFICATES(expectedHostName: nil)
			)
		}
	}

	var customConfig: ElectrumConfig.Custom {
		return ElectrumConfig.Custom.companion.create(
			server: self.serverAddress,
			requireOnionIfTorEnabled: requireOnionIfTorEnabled ?? true
		)
	}
}

struct LiquidityPolicy: Equatable, Codable {
	
	let enabled: Bool
	let maxFeeSats: Int64?
	let maxFeeBasisPoints: Int32?
	let skipAbsoluteFeeCheck: Bool?
	
	static func defaultPolicy() -> LiquidityPolicy {
		return LiquidityPolicy(
			enabled: true,
			maxFeeSats: nil,          // use default value defined in phoenix-shared
			maxFeeBasisPoints: nil,   // use default value defined in phoenix-shared
			skipAbsoluteFeeCheck: nil // use default value defined in phoenix-shared
		)
	}
	
	var effectiveInboundLiquidityTargetSats: Int64? {
		return NodeParamsManager.companion.defaultLiquidityPolicy.inboundLiquidityTarget?.sat
	}
	
	var effectiveInboundLiquidityTarget: Bitcoin_kmpSatoshi? {
		if let sats = effectiveInboundLiquidityTargetSats {
			return Bitcoin_kmpSatoshi(sat: sats)
		} else {
			return nil
		}
	}
	
	var effectiveMaxFeeSats: Int64 {
		return maxFeeSats ?? NodeParamsManager.companion.defaultLiquidityPolicy.maxAbsoluteFee.sat
	}
	
	var effectiveMaxFee: Bitcoin_kmpSatoshi {
		return Bitcoin_kmpSatoshi(sat: effectiveMaxFeeSats)
	}
	
	var effectiveMaxFeeBasisPoints: Int32 {
		return maxFeeBasisPoints ?? NodeParamsManager.companion.defaultLiquidityPolicy.maxRelativeFeeBasisPoints
	}
	
	var effectiveSkipAbsoluteFeeCheck: Bool {
		return skipAbsoluteFeeCheck ?? NodeParamsManager.companion.defaultLiquidityPolicy.skipAbsoluteFeeCheck
	}
	
	var effectiveMaxAllowedFeeCredit: Lightning_kmpMilliSatoshi {
		return NodeParamsManager.companion.defaultLiquidityPolicy.maxAllowedFeeCredit
	}
	
	func toKotlin() -> Lightning_kmpLiquidityPolicy {
		
		if enabled {
			
			return Lightning_kmpLiquidityPolicy.Auto(
				inboundLiquidityTarget: effectiveInboundLiquidityTarget,
				maxAbsoluteFee: effectiveMaxFee,
				maxRelativeFeeBasisPoints: effectiveMaxFeeBasisPoints,
				skipAbsoluteFeeCheck: effectiveSkipAbsoluteFeeCheck,
				maxAllowedFeeCredit: effectiveMaxAllowedFeeCredit,
				considerOnlyMiningFeeForAbsoluteFeeCheck: false // keep this in check with the default value in lightning-kmp
			)
			
		} else {
			
			return Lightning_kmpLiquidityPolicy.Disable()
		}
	}
}

enum RecentPaymentsConfig: Equatable, Codable, Identifiable {
	case withinTime(seconds: Int)
	case mostRecent(count: Int)
	case inFlightOnly
	
	var id: String {
		switch self {
		case .withinTime(let seconds):
			return "withinTime(seconds=\(seconds))"
		case .mostRecent(let count):
			return "mostRecent(count=\(count)"
		case .inFlightOnly:
			return "inFlightOnly"
		}
	}
}
