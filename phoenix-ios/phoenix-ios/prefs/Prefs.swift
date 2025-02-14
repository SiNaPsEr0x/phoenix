import SwiftUI
import PhoenixShared
import Combine

fileprivate let filename = "Prefs"
#if DEBUG && false
fileprivate var log = LoggerFactory.shared.logger(filename, .trace)
#else
fileprivate var log = LoggerFactory.shared.logger(filename, .warning)
#endif

fileprivate enum Key: String {
	case theme
	case defaultPaymentDescription
	case recentTipPercents
	case isNewWallet
	case invoiceExpirationDays
	case hideAmounts = "hideAmountsOnHomeScreen"
	case showOriginalFiatAmount
	case recentPaymentsConfig
	case hasMergedChannelsForSplicing
	case swapInAddressIndex
	case hasUpgradedSeedCloudBackups_v2
	case serverMessageReadIndex
	case allowOverpayment
	case doNotShowChannelImpactWarning
}

fileprivate enum KeyDeprecated: String {
	case showChannelsRemoteBalance
	case recentPaymentSeconds
	case maxFees
	case hasUpgradedSeedCloudBackups_v1 = "hasUpgradedSeedCloudBackups"
}

/// Standard app preferences, stored in the iOS UserDefaults system.
///
/// Note that the values here are NOT shared with other extensions bundled in the app,
/// such as the notification-service-extension. For preferences shared with extensions, see GroupPrefs.
///
class Prefs {
	
	public static let shared = Prefs()
	
	private init() {
		UserDefaults.standard.register(defaults: [
			Key.isNewWallet.rawValue: true,
			Key.invoiceExpirationDays.rawValue: 7,
			Key.showOriginalFiatAmount.rawValue: true
		])
	}
	
	var defaults: UserDefaults {
		return UserDefaults.standard
	}
	
	// --------------------------------------------------
	// MARK: User Options
	// --------------------------------------------------
	
	lazy private(set) var themePublisher: AnyPublisher<Theme, Never> = {
		defaults.publisher(for: \.theme, options: [.initial, .new])
			.map({ (data: Data?) -> Theme in
				data?.jsonDecode() ?? self.defaultTheme
			})
			.removeDuplicates()
			.eraseToAnyPublisher()
	}()

	private let defaultTheme = Theme.system

	var theme: Theme {
		get { defaults.theme?.jsonDecode() ?? defaultTheme }
		set { defaults.theme = newValue.jsonEncode() }
	}
	
	var defaultPaymentDescription: String? {
		get { defaults.defaultPaymentDescription }
		set { defaults.defaultPaymentDescription = newValue }
	}
	
	var invoiceExpirationDays: Int {
		get { defaults.invoiceExpirationDays }
		set { defaults.invoiceExpirationDays = newValue	}
	}
	
	var invoiceExpirationSeconds: Int64 {
		return Int64(invoiceExpirationDays) * Int64(60 * 60 * 24)
	}
	
	var hideAmounts: Bool {
		get { defaults.hideAmounts }
		set { defaults.hideAmounts = newValue }
	}
	
	lazy private(set) var showOriginalFiatAmountPublisher: AnyPublisher<Bool, Never> = {
		defaults.publisher(for: \.showOriginalFiatAmount, options: [.initial, .new])
			.removeDuplicates()
			.eraseToAnyPublisher()
	}()
	
	var showOriginalFiatAmount: Bool {
		get { defaults.showOriginalFiatAmount }
		set { defaults.showOriginalFiatAmount = newValue }
	}
	
	lazy private(set) var recentPaymentsConfigPublisher: AnyPublisher<RecentPaymentsConfig, Never> = {
		defaults.publisher(for: \.recentPaymentsConfig, options: [.initial, .new])
			.map({ (data: Data?) -> RecentPaymentsConfig in
				data?.jsonDecode() ?? self.defaultRecentPaymentsConfig
			})
			.removeDuplicates()
			.eraseToAnyPublisher()
	}()
	
	let defaultRecentPaymentsConfig = RecentPaymentsConfig.mostRecent(count: 3)
	
	var recentPaymentsConfig: RecentPaymentsConfig {
		get { defaults.recentPaymentsConfig?.jsonDecode() ?? defaultRecentPaymentsConfig }
		set { defaults.recentPaymentsConfig = newValue.jsonEncode() }
	}
	
	lazy private(set) var hasMergedChannelsForSplicingPublisher: AnyPublisher<Bool, Never> = {
		defaults.publisher(for: \.hasMergedChannelsForSplicing, options: [.initial, .new])
			.removeDuplicates()
			.eraseToAnyPublisher()
	}()
	
	var hasMergedChannelsForSplicing: Bool {
		get { defaults.hasMergedChannelsForSplicing }
		set { defaults.hasMergedChannelsForSplicing = newValue }
	}
	
	var hasUpgradedSeedCloudBackups: Bool {
		get { defaults.hasUpgradedSeedCloudBackups }
		set { defaults.hasUpgradedSeedCloudBackups = newValue }
	}
  
	lazy private(set) var serverMessageReadIndexPublisher: AnyPublisher<Int?, Never> = {
		defaults.publisher(for: \.serverMessageReadIndex, options: [.initial, .new])
			.map({ (number: NSNumber?) -> Int? in
				number?.intValue
			})
			.removeDuplicates()
			.eraseToAnyPublisher()
	}()
	
	var serverMessageReadIndex: Int? {
		get { defaults.serverMessageReadIndex?.intValue }
		set {
			if let number = newValue {
				defaults.serverMessageReadIndex = NSNumber(value: number)
			} else {
				defaults.serverMessageReadIndex = nil
			}
		}
	}
	
	lazy private(set) var allowOverpaymentPublisher: AnyPublisher<Bool, Never> = {
		defaults.publisher(for: \.allowOverpayment, options: [.initial, .new])
			.removeDuplicates()
			.eraseToAnyPublisher()
	}()
	
	var allowOverpayment: Bool {
		get { defaults.allowOverpayment }
		set { defaults.allowOverpayment = newValue }
	}

	var doNotShowChannelImpactWarning: Bool {
		get { defaults.doNotShowChannelImpactWarning }
		set { defaults.doNotShowChannelImpactWarning = newValue }
	}
	
	// --------------------------------------------------
	// MARK: Wallet State
	// --------------------------------------------------
	
	lazy private(set) var isNewWalletPublisher: AnyPublisher<Bool, Never> = {
		defaults.publisher(for: \.isNewWallet, options: [.initial, .new])
			.removeDuplicates()
			.eraseToAnyPublisher()
	}()
	
	/**
	 * Set to true, until the user has funded their wallet at least once.
	 * A false value does NOT indicate that the wallet has funds.
	 * Just that the wallet had either a non-zero balance, or a transaction, at least once.
	 */
	var isNewWallet: Bool {
		get { defaults.isNewWallet }
		set { defaults.isNewWallet = newValue }
	}
	
	var swapInAddressIndex: Int {
		get { defaults.swapInAddressIndex }
		set { defaults.swapInAddressIndex = newValue }
	}
	
	// --------------------------------------------------
	// MARK: Recent Tips
	// --------------------------------------------------
	
	/**
	 * The SendView includes a Quick Tips feature,
	 * where we remember recent tip-percentages used by the user.
	 */
	
	/// Most recent is at index 0
	var recentTipPercents: [Int] {
		get { defaults.recentTipPercents?.jsonDecode() ?? [] }
	}
	
	func addRecentTipPercent(_ percent: Int) {
		var recents = self.recentTipPercents
		if let idx = recents.firstIndex(of: percent) {
			recents.remove(at: idx)
		}
		recents.insert(percent, at: 0)
		while recents.count > 6 {
			recents.removeLast()
		}
		
		defaults.recentTipPercents = recents.jsonEncode()
	}

	// --------------------------------------------------
	// MARK: Backup
	// --------------------------------------------------
	
	lazy private(set) var backupTransactions: Prefs_BackupTransactions = {
		return Prefs_BackupTransactions()
	}()
	
	lazy private(set) var backupSeed: Prefs_BackupSeed = {
		return Prefs_BackupSeed()
	}()
	
	// --------------------------------------------------
	// MARK: Reset Wallet
	// --------------------------------------------------

	func resetWallet(_ walletId: WalletIdentifier) {

		// Purposefully not resetting:
		// - Key.theme: App feels weird when this changes unexpectedly.

		defaults.removeObject(forKey: Key.defaultPaymentDescription.rawValue)
		defaults.removeObject(forKey: Key.recentTipPercents.rawValue)
		defaults.removeObject(forKey: Key.isNewWallet.rawValue)
		defaults.removeObject(forKey: Key.invoiceExpirationDays.rawValue)
		defaults.removeObject(forKey: Key.hideAmounts.rawValue)
		defaults.removeObject(forKey: Key.showOriginalFiatAmount.rawValue)
		defaults.removeObject(forKey: Key.recentPaymentsConfig.rawValue)
		defaults.removeObject(forKey: Key.hasMergedChannelsForSplicing.rawValue)
		defaults.removeObject(forKey: Key.swapInAddressIndex.rawValue)
		defaults.removeObject(forKey: Key.hasUpgradedSeedCloudBackups_v2.rawValue)
		defaults.removeObject(forKey: Key.serverMessageReadIndex.rawValue)
		defaults.removeObject(forKey: Key.allowOverpayment.rawValue)
		defaults.removeObject(forKey: Key.doNotShowChannelImpactWarning.rawValue)

		defaults.removeObject(forKey: KeyDeprecated.showChannelsRemoteBalance.rawValue)
		defaults.removeObject(forKey: KeyDeprecated.recentPaymentSeconds.rawValue)
		defaults.removeObject(forKey: KeyDeprecated.maxFees.rawValue)
		defaults.removeObject(forKey: KeyDeprecated.hasUpgradedSeedCloudBackups_v1.rawValue)
		
		self.backupTransactions.resetWallet(walletId)
		self.backupSeed.resetWallet(walletId)
	}

	// --------------------------------------------------
	// MARK: Migration
	// --------------------------------------------------
	
	public func performMigration(
		_ targetBuild: String,
		_ completionPublisher: CurrentValueSubject<Int, Never>
	) -> Void {
		log.trace("performMigration(to: \(targetBuild))")
		
		// NB: The first version released in the App Store was version 1.0.0 (build 17)
		
		if targetBuild.isVersion(equalTo: "44") {
			performMigration_toBuild44()
		}
	}
	
	private func performMigration_toBuild44() {
		log.trace("performMigration_toBuild44()")
		
		let oldKey = KeyDeprecated.recentPaymentSeconds.rawValue
		let newKey = Key.recentPaymentsConfig.rawValue
		
		if defaults.object(forKey: oldKey) != nil {
			let seconds = defaults.integer(forKey: oldKey)
			if seconds <= 0 {
				let newValue = RecentPaymentsConfig.inFlightOnly
				defaults.set(newValue.jsonEncode(), forKey: newKey)
			} else {
				let newValue = RecentPaymentsConfig.withinTime(seconds: seconds)
				defaults.set(newValue.jsonEncode(), forKey: newKey)
			}
			
			defaults.removeObject(forKey: oldKey)
		}
	}
}

extension UserDefaults {

	@objc fileprivate var theme: Data? {
		get { data(forKey: Key.theme.rawValue) }
		set { set(newValue, forKey: Key.theme.rawValue) }
	}

	@objc fileprivate var defaultPaymentDescription: String? {
		get { string(forKey: Key.defaultPaymentDescription.rawValue) }
		set { setValue(newValue, forKey: Key.defaultPaymentDescription.rawValue) }
	}

	@objc fileprivate var invoiceExpirationDays: Int {
		get { integer(forKey: Key.invoiceExpirationDays.rawValue) }
		set { set(newValue, forKey: Key.invoiceExpirationDays.rawValue) }
	}

	@objc fileprivate var hideAmounts: Bool {
		get { bool(forKey: Key.hideAmounts.rawValue) }
		set { set(newValue, forKey: Key.hideAmounts.rawValue) }
	}
	
	@objc fileprivate var showOriginalFiatAmount: Bool {
		get { bool(forKey: Key.showOriginalFiatAmount.rawValue) }
		set { set(newValue, forKey: Key.showOriginalFiatAmount.rawValue) }
	}
	
	@objc fileprivate var recentPaymentsConfig: Data? {
		get { data(forKey: Key.recentPaymentsConfig.rawValue) }
		set { set(newValue, forKey: Key.recentPaymentsConfig.rawValue) }
	}

	@objc fileprivate var isNewWallet: Bool {
		get { bool(forKey: Key.isNewWallet.rawValue) }
		set { set(newValue, forKey: Key.isNewWallet.rawValue) }
	}

	@objc fileprivate var recentTipPercents: Data? {
		get { data(forKey: Key.recentTipPercents.rawValue) }
		set { set(newValue, forKey: Key.recentTipPercents.rawValue) }
	}
	
	@objc fileprivate var hasMergedChannelsForSplicing: Bool {
		get { bool(forKey: Key.hasMergedChannelsForSplicing.rawValue) }
		set { set(newValue, forKey: Key.hasMergedChannelsForSplicing.rawValue) }
	}
	
	@objc fileprivate var swapInAddressIndex: Int {
		get { integer(forKey: Key.swapInAddressIndex.rawValue) }
		set { set(newValue, forKey: Key.swapInAddressIndex.rawValue) }
	}
  
	@objc fileprivate var hasUpgradedSeedCloudBackups: Bool {
		get { bool(forKey: Key.hasUpgradedSeedCloudBackups_v2.rawValue) }
		set { set(newValue, forKey: Key.hasUpgradedSeedCloudBackups_v2.rawValue) }
	}
	
	@objc fileprivate var serverMessageReadIndex: NSNumber? {
		get { object(forKey: Key.serverMessageReadIndex.rawValue) as? NSNumber }
		set { set(newValue, forKey: Key.serverMessageReadIndex.rawValue) }
	}
	
	@objc fileprivate var allowOverpayment: Bool {
		get { bool(forKey: Key.allowOverpayment.rawValue) }
		set { set(newValue, forKey: Key.allowOverpayment.rawValue) }
	}

	@objc fileprivate var doNotShowChannelImpactWarning: Bool {
		get { bool(forKey: Key.doNotShowChannelImpactWarning.rawValue) }
		set { set(newValue, forKey: Key.doNotShowChannelImpactWarning.rawValue) }
	}
}
