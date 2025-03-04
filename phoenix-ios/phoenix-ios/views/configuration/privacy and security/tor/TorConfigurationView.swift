import SwiftUI

fileprivate let filename = "TorConfigurationView"
#if DEBUG && true
fileprivate var log = LoggerFactory.shared.logger(filename, .trace)
#else
fileprivate var log = LoggerFactory.shared.logger(filename, .warning)
#endif

struct TorConfigurationView: View {

	@State var toggleState = GroupPrefs.shared.isTorEnabled
	@State var isTorEnabled = GroupPrefs.shared.isTorEnabled
	
	@State var ignoreToggleStateChange = false

	@EnvironmentObject var popoverState: PopoverState
	@EnvironmentObject var smartModalState: SmartModalState
	
	@ViewBuilder
	var body: some View {
		
		content()
			.navigationTitle(NSLocalizedString("Tor", comment: "Navigation bar title"))
			.navigationBarTitleDisplayMode(.inline)
	}
	
	@ViewBuilder
	func content() -> some View {
		
		List {
			section_toggle()
			if isTorEnabled {
				section_info()
			}
		}
		.listStyle(.insetGrouped)
		.listBackgroundColor(.primaryBackground)
	}
	
	@ViewBuilder
	func section_toggle() -> some View {
		
		Section {
			Toggle(isOn: $toggleState.animation()) {
				Text("Use Tor")
			}.onChange(of: toggleState) {
				self.toggleStateChanged($0)
			}
		}
	}
	
	@ViewBuilder
	func section_info() -> some View {
		
		Section {
			VStack(alignment: HorizontalAlignment.leading, spacing: 15) {
				Text(
					"""
					This requires installing a third-party Tor Proxy VPN app such as Orbot.
					"""
				)
				.padding(.top, 5)
				
				HStack(alignment: VerticalAlignment.center, spacing: 0) {
					Spacer()
					Button {
						openLink()
					} label: {
						Text("Learn more")
					}
				}
				.padding(.top, 5)
			}
			
		} header: {
			Text("How it works")
		}
	}
	
	// --------------------------------------------------
	// MARK: Actions
	// --------------------------------------------------

	func toggleStateChanged(_ isEnabled: Bool) {
		log.trace("toggleStateChanged: \(isEnabled)")
		
		if ignoreToggleStateChange {
			ignoreToggleStateChange = false
			
		} else if isEnabled {
			smartModalState.display(dismissable: false) {
				UsingTorSheet(
					didCancel: usingTorSheet_didCancel,
					didConfirm: usingTorSheet_didConfirm
				)
			}
		} else {
			smartModalState.display(dismissable: false) {
				DisablingTorSheet(
					didCancel: disablingTorSheet_didCancel,
					didConfirm: disablingTorSheet_didConfirm
				)
			}
		}
	}
	
	func usingTorSheet_didCancel() {
		log.trace("usingTorSheet_didCancel()")
		
		ignoreToggleStateChange = true
		toggleState = false
	}
	
	func usingTorSheet_didConfirm() {
		log.trace("usingTorSheet_didConfirm()")
		
		isTorEnabled = true
		GroupPrefs.shared.isTorEnabled = true
		
		popoverState.display(dismissable: false) {
			RestartPopover()
		}
	}
	
	func disablingTorSheet_didCancel() {
		log.trace("disablingTorSheet_didCancel()")
		
		ignoreToggleStateChange = true
		toggleState = true
	}
	
	func disablingTorSheet_didConfirm() {
		log.trace("disablingTorSheet_didConfirm()")
		
		isTorEnabled = false
		GroupPrefs.shared.isTorEnabled = false
		
		popoverState.display(dismissable: false) {
			RestartPopover()
		}
	}
	
	func openLink() {
		log.trace("openLink()")
		
		guard let link = URL(string: "https://phoenix.acinq.co/faq#how-to-use-tor-on-phoenix") else {
			return
		}
		
		if UIApplication.shared.canOpenURL(link) {
			UIApplication.shared.open(link)
		}
	}
}
