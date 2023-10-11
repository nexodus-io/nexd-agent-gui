import Cocoa
import os.log
import SecureXPC
import SwiftUI

@main
struct UtilityApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Nexodus Agent", image: "nexodus-logo-square-48x48-menubar") {
            AppMenu()
        }.menuBarExtraStyle(.window)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var windowController: NSWindowController?

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        return false
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        NSApp.delegate = self
        NSApp.setActivationPolicy(.accessory)
    }

    func showWindow() {
        print("Attempting to show window...")
        if windowController == nil {
            print("Window controller is nil. Instantiating from storyboard...")
            let storyboard = NSStoryboard(name: "Main", bundle: nil)
            windowController = storyboard.instantiateInitialController() as? NSWindowController
            if windowController == nil {
                print("Failed to instantiate window controller from storyboard.")
                return
            }
            windowController?.window?.delegate = self
        } else {
            print("Window controller already exists.")
        }

        NSApplication.shared.activate(ignoringOtherApps: true)
        windowController?.window?.makeKeyAndOrderFront(nil)
        windowController?.window?.level = .normal
        windowController?.window?.center()
    }
}

struct AppMenu: View {
    @StateObject private var nexdManager = NexdManager()
    @State private var showAlert = false
    @State private var oneTimeCode: String = ""
    @State private var authURL: String = ""
    @State private var showLogFile = false
    @State private var ipAddress: String = "Not Connected"
    @StateObject private var ipAddressManager = IPAddressManager()
    @State private var isLogDebuggingEnabled: Bool = false
    @State private var isCopyAuthURLButtonClicked: Bool = false
    @State private var exitMode: Bool = false
    @State private var serviceMode = 0
    @State private var preferredTheme: Bool = true
    // Button color states
    @State private var startButtonForegroundColor: Color = .primary
    @State private var startButtonBackgroundColor: Color = .clear
    @State private var stopButtonForegroundColor: Color = .primary
    @State private var stopButtonBackgroundColor: Color = .clear
    @State private var authButtonForegroundColor: Color = .primary
    @State private var authButtonBackgroundColor: Color = .clear
    @State private var openAuthButtonForegroundColor: Color = .primary
    @State private var openAuthButtonBackgroundColor: Color = .clear
    @State private var logsButtonForegroundColor: Color = .primary
    @State private var logsButtonBackgroundColor: Color = .clear
    @State private var settingsButtonForegroundColor: Color = .primary
    @State private var settingsButtonBackgroundColor: Color = .clear
    @State private var diagnosticsButtonForegroundColor: Color = .primary
    @State private var diagnosticsButtonBackgroundColor: Color = .clear
    @State private var helpButtonForegroundColor: Color = .primary
    @State private var helpButtonBackgroundColor: Color = .clear
    @State private var quitButtonForegroundColor: Color = .primary
    @State private var quitButtonBackgroundColor: Color = .clear
    // Button color states
    @State var isStartButtonClicked: Bool = false
    @State var isStopButtonClicked: Bool = false
    @State var isAuthButtonClicked: Bool = false
    @State var isOpenAuthButtonClicked: Bool = false
    @State var isLogsButtonClicked: Bool = false
    @State var isSettingsButtonClicked: Bool = false
    @State var isDiagnosticsButtonClicked: Bool = false
    @State var isHelpButtonClicked: Bool = false
    @State var isQuitButtonClicked: Bool = false

    private let sharedConstants = try? SharedConstants()
    private var xpcClient: XPCClient {
        guard let sharedConstants = sharedConstants else {
            fatalError("Failed to initialize SharedConstants.")
        }
        return XPCClient.forMachService(named: sharedConstants.machServiceName)
    }

    var appDelegate: AppDelegate? {
        return NSApp.delegate as? AppDelegate
    }

    func applyTheme() {
        if preferredTheme {
            NSApplication.shared.appearance = NSAppearance(named: .darkAqua)
        } else {
            NSApplication.shared.appearance = NSAppearance(named: .aqua)
        }
    }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading) {
                ///
                /// Title
                ///
                HStack {
                    Text("Nexodus Agent").font(.system(size: 15)).padding(.leading, 5)
                    Spacer()
                }
                Picker("", selection: $serviceMode) {
                    Text("Service Mode").tag(0).tint(.orange)
                    Text("Process Mode").tag(1).tint(.orange)
                }.pickerStyle(.segmented).labelsHidden().tint(.orange)
                    .padding(3)
                    .onHover { isOnMouseOver in
                        isOnMouseOver ? NSCursor.pointingHand.push() : NSCursor.pop()
                    }
                ///
                /// Start Nexd
                ///
                Button(action: {
                    isStartButtonClicked = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isStartButtonClicked = false
                    }
                    startNexdService()
                }) {
                    HStack {
                        Image(systemName: "play.fill")
                            .foregroundColor(isStartButtonClicked ? Color.gray : startButtonForegroundColor)
                        Text("Start Nexodus Service")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(3)
                    .frame(height: 25)
                    .background(RoundedRectangle(cornerRadius: 5)
                        .foregroundColor(isStartButtonClicked ? Color.gray.opacity(0.4) : startButtonBackgroundColor))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .onHover { isOnMouseOver in
                    startButtonForegroundColor = isOnMouseOver ? .white : Color.primary
                    startButtonBackgroundColor = isOnMouseOver ? Color(red: 70/255, green: 148/255, blue: 247/255) : .clear
                    isOnMouseOver ? NSCursor.pointingHand.push() : NSCursor.pop()
                }
                ///
                /// Stop Nexd
                ///
                Button(action: {
                    isStopButtonClicked = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isStopButtonClicked = false
                    }
                    stopNexdService()
                }) {
                    HStack {
                        Image(systemName: "stop.fill")
                            .foregroundColor(isStopButtonClicked ? Color.gray : stopButtonForegroundColor)
                        Text("Stop Nexodus Service")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(3)
                    .frame(height: 25)
                    .background(RoundedRectangle(cornerRadius: 5)
                        .foregroundColor(isStopButtonClicked ? Color.gray.opacity(0.4) : stopButtonBackgroundColor))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .onHover { isOnMouseOver in
                    stopButtonForegroundColor = isOnMouseOver ? .white : Color.primary
                    stopButtonBackgroundColor = isOnMouseOver ? Color(red: 70/255, green: 148/255, blue: 247/255) : .clear
                    isOnMouseOver ? NSCursor.pointingHand.push() : NSCursor.pop()
                }
                Divider()
                ///
                /// Display the status and IPs once connected
                ///
                nexdStatusDisplay()
                Divider()
                ///
                /// Authentication
                ///
                HStack(spacing: 10) {
                    let isAuthURLAvailable = !authURL.isEmpty
                    let sharedOpacity = isAuthURLAvailable ? 1.0 : 0.4
                    
                    // 'Copy Auth URL" button
                    Button(action: {
                        isCopyAuthURLButtonClicked = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isCopyAuthURLButtonClicked = false
                        }
                        menuCopyAuthURLToClipboard()
                    }) {
                        HStack {
                            Image(systemName: "doc.on.doc.fill")
                                .foregroundColor(isAuthURLAvailable ? (isCopyAuthURLButtonClicked ? Color.gray : stopButtonForegroundColor) : Color.gray.opacity(0.7))
                            Text("Copy Auth URL")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .opacity(sharedOpacity) // Apply shared opacity
                        .padding(3)
                        .frame(height: 25)
                        .background(RoundedRectangle(cornerRadius: 5)
                                        .foregroundColor(isCopyAuthURLButtonClicked ? Color.gray.opacity(0.4) : authButtonBackgroundColor))
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .disabled(!isAuthURLAvailable)
                    .onHover { isOnMouseOver in
                        guard isAuthURLAvailable else { return }
                        authButtonForegroundColor = isOnMouseOver ? .white : Color.primary
                        authButtonBackgroundColor = isOnMouseOver ? Color(red: 70/255, green: 148/255, blue: 247/255) : .clear
                        isOnMouseOver ? NSCursor.pointingHand.push() : NSCursor.pop()
                    }
                    
                    // 'Open Auth URL' button
                    Button(action: {
                        isOpenAuthButtonClicked = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isOpenAuthButtonClicked = false
                        }
                        menuOpenAuthURLInBrowser()
                    }) {
                        HStack {
                            Image(systemName: "book.pages.fill")
                                .foregroundColor(isAuthURLAvailable ? (isOpenAuthButtonClicked ? Color.gray : openAuthButtonForegroundColor) : Color.gray.opacity(0.4))
                            Text("Open Auth URL")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .opacity(sharedOpacity)
                        .padding(3)
                        .frame(height: 25)
                        .background(RoundedRectangle(cornerRadius: 5)
                                        .foregroundColor(isOpenAuthButtonClicked ? Color.gray.opacity(0.4) : openAuthButtonBackgroundColor))
                    }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .disabled(!isAuthURLAvailable)
                    .onHover { isOnMouseOver in
                        guard isAuthURLAvailable else { return }
                        openAuthButtonForegroundColor = isOnMouseOver ? .white : Color.primary
                        openAuthButtonBackgroundColor = isOnMouseOver ? Color(red: 70/255, green: 148/255, blue: 247/255) : .clear
                        isOnMouseOver ? NSCursor.pointingHand.push() : NSCursor.pop()
                    }
                }

                Divider()
                ///
                /// Exit Node Client
                ///
                HStack {
                    Text("Enable Exit Node Client").opacity(0.7)
                    Spacer()
                    Toggle("", isOn: $exitMode)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                }
                .padding(.leading, 3)
                Divider()
                ///
                /// Logs
                ///
                Button(action: {
                    isLogsButtonClicked = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isLogsButtonClicked = false
                    }
                    openNexdLogs()
                }) {
                    HStack {
                        Image(systemName: "rectangle.stack.fill")
                            .foregroundColor(isLogsButtonClicked ? Color.gray : .primary)
                        Text("Open Logs")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(3)
                    .frame(height: 25)
                    .background(RoundedRectangle(cornerRadius: 5)
                        .foregroundColor(isLogsButtonClicked ? Color.gray.opacity(0.4) : logsButtonBackgroundColor))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .onHover { isOnMouseOver in
                    logsButtonForegroundColor = isOnMouseOver ? .white : Color.primary
                    logsButtonBackgroundColor = isOnMouseOver ? Color(red: 70/255, green: 148/255, blue: 247/255) : .clear
                }
                ///
                /// Settings
                ///
                Button(action: {
                    isSettingsButtonClicked = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isSettingsButtonClicked = false
                    }
                    menuSettings()
                }) {
                    HStack {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(isSettingsButtonClicked ? Color.gray : .primary)
                        Text("Settings")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(3)
                    .frame(height: 25)
                    .background(RoundedRectangle(cornerRadius: 5)
                        .foregroundColor(isSettingsButtonClicked ? Color.gray.opacity(0.4) : settingsButtonBackgroundColor))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .onHover { isOnMouseOver in
                    settingsButtonForegroundColor = isOnMouseOver ? .white : Color.primary
                    settingsButtonBackgroundColor = isOnMouseOver ? Color(red: 70/255, green: 148/255, blue: 247/255) : .clear
                }
                ///
                /// Diagnostics
                ///
                Button(action: {
                    isDiagnosticsButtonClicked = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isDiagnosticsButtonClicked = false
                    }
                    menuSettings()
                }) {
                    HStack {
                        Image(systemName: "wrench.adjustable.fill")
                            .foregroundColor(isDiagnosticsButtonClicked ? Color.gray : .primary)
                        Text("Diagnostics")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(3)
                    .frame(height: 25)
                    .background(RoundedRectangle(cornerRadius: 5)
                        .foregroundColor(isDiagnosticsButtonClicked ? Color.gray.opacity(0.4) : diagnosticsButtonBackgroundColor))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .onHover { isOnMouseOver in
                    diagnosticsButtonForegroundColor = isOnMouseOver ? .white : Color.primary
                    diagnosticsButtonBackgroundColor = isOnMouseOver ? Color(red: 70/255, green: 148/255, blue: 247/255) : .clear
                }
                ///
                /// Appearance
                ///
                HStack {
                    Image(systemName: preferredTheme ? "moon.fill" : "sun.max.fill").padding(.leading, 3.5)
                    Text(preferredTheme ? "Appearance" : "Appearance").opacity(0.7)
                    Spacer()
                    Toggle("", isOn: $preferredTheme)
                        .toggleStyle(SwitchToggleStyle(tint: .blue))
                        .labelsHidden()
                }
                .onChange(of: preferredTheme) { _ in
                    applyTheme()
                }
                ///
                /// Help
                ///
                Link(destination: URL(string: "https://github.com/nexodus-io/nexodus")!) {
                    HStack {
                        Image("GitHub")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14, height: 14)
                        Text(" Nexodus Help")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(3)
                    .frame(height: 25)
                    .background(RoundedRectangle(cornerRadius: 5)
                        .foregroundColor(isHelpButtonClicked ? Color.gray.opacity(0.4) : helpButtonBackgroundColor))
                    .onTapGesture {
                        isHelpButtonClicked = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            isHelpButtonClicked = false
                        }
                    }
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .onHover { isOnMouseOver in
                    helpButtonForegroundColor = isOnMouseOver ? .white : Color.primary
                    helpButtonBackgroundColor = isOnMouseOver ? Color(red: 70/255, green: 148/255, blue: 247/255) : .clear
                }
                ///
                /// Quit
                ///
                Button(action: {
                    isQuitButtonClicked = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isQuitButtonClicked = false
                    }
                    quitApp()
                }) {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right.fill")
                            .foregroundColor(isQuitButtonClicked ? Color.gray : quitButtonForegroundColor)
                        Text("Quit")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(3)
                    .frame(height: 25)
                    .background(RoundedRectangle(cornerRadius: 5)
                        .foregroundColor(isQuitButtonClicked ? Color.gray.opacity(0.4) : quitButtonBackgroundColor))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity)
                .onHover { isOnMouseOver in
                    quitButtonForegroundColor = isOnMouseOver ? .white : Color.primary
                    quitButtonBackgroundColor = isOnMouseOver ? Color(red: 70/255, green: 148/255, blue: 247/255) : .clear
                }
            }
        }
        .padding(15)
        .onAppear {
            // Initialize with the default dark theme
            preferredTheme = true
            applyTheme()
        }
    }

    func diagnostics() {
        print("diagnostics called.")
    }

    func menuCopyAuthURLToClipboard() {
        // Check if the authURL is not empty
        if !authURL.isEmpty {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(authURL, forType: .string)
            isCopyAuthURLButtonClicked = true
        } else {
            print("Auth URL is empty or not set.")
        }
    }

    func menuOpenAuthURLInBrowser() {
        // Check if the authURL is not empty
        if !authURL.isEmpty {
            if let url = URL(string: authURL) {
                NSWorkspace.shared.open(url)
            } else {
                print("Invalid Auth URL format.")
            }
        } else {
            print("Auth URL is empty or not set.")
        }
    }

    func menuConnect() {
        print("[DEBUG] menuConnect() called.")
        sendCommand(.nexdConnect) {}
        // Wait for 5 seconds and then read the file (TODO: should be a retry instead of a fixed timer)
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            print("[DEBUG] Checking file for auth details.")
            self.checkFileForAuthDetails()
        }
    }

    func menuDisconnect() {
        sendCommand(.nexDisconnect) {}
    }

    // New function to start Nexd service
    func startNexdService() {
        print("[DEBUG] startNexdService() called.")
        sendCommand(.startNexdService) {
            print("Nexd Service started.")
        }
        // Wait for 4 seconds and then read the file (TODO: should be a retry instead of a fixed timer)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            print("[DEBUG] Checking file for auth details.")
            self.checkNexctlForAuthDetails()
        }
    }

    // New function to stop Nexd service
    func stopNexdService() {
        print("[DEBUG] stopNexdService() called.")
        sendCommand(.stopNexdService) {
            print("Nexd Service stopped.")
        }
    }

    func openNexdLogs() {
        sendCommand(.openNexdLogs) {}
    }

    func menuSettings() {
        print("[DEBUG] opening settings")
        DispatchQueue.main.async {
            if let appDelegate = NSApp.delegate as? AppDelegate {
                appDelegate.showWindow()
            } else {
                print("Failed to cast NSApp.delegate to AppDelegate.")
            }
        }
    }

    func quitApp() {
        // TODO: Add back for process mode
        // sendCommand(.nexDisconnect) {
        exit(0)
    }

    func checkFileForAuthDetails() {
        guard let fileContents = try? String(contentsOfFile: "/var/lib/nexd/nexd-log.log") else { return }
        getAuthURL(fileContents)
    }

    func checkNexctlForAuthDetails() {
        print("[DEBUG] Running 'nexctl nexd status' command through XPC helper...")
        sendNexctlStatCommand { output in
            if let output = output {
                print("Command Output: \(output)")
                getAuthURL(output)
            } else {
                print("Failed to get command output.")
            }
        }
    }

    func sendNexctlStatCommand(completion: @escaping (String?) -> Void) {
        sendCommandWithOutput(.nexctlStat) { result in
            switch result {
            case .success(let output):
                completion(output)
            case .failure(let error):
                print("Error: \(error)")
                completion(nil)
            }
        }
    }

    func getAuthURL(_ output: String) {
        if let codeMatch = output.range(of: "Your one-time code is: ([A-Z\\-]+)", options: .regularExpression) {
            // Extract only the code for debug logs
            oneTimeCode = String(output[codeMatch.lowerBound ..< codeMatch.upperBound].dropFirst(24))
            print("[DEBUG] Extracted one-time code: \(oneTimeCode)")
        } else {
            print("[DEBUG] No one-time code found in the logs.")
        }

        if let urlMatch = output.range(of: "https://auth.try.nexodus.io/[^\\s]+", options: .regularExpression) {
            authURL = String(output[urlMatch.lowerBound ..< urlMatch.upperBound])
            print("[DEBUG] Extracted URL: \(authURL)")
        } else {
            print("[DEBUG] No auth URL found in the logs.")
            // If the URL isn't found, clear the authURL
            authURL = ""
        }
    }

    private func nexdStatusDisplay() -> some View {
        Group {
            VStack(alignment: .leading) {
                // Connection status
                HStack {
                    if ipAddressManager.isConnected {
                        Text(Image(systemName: "globe"))
                            .foregroundColor(Color(red: 0/255, green: 204/255, blue: 0/255))
                        Text("Connected").opacity(0.8)
                    } else {
                        Text(Image(systemName: "globe"))
                            .foregroundColor(Color(red: 178/255, green: 43/255, blue: 33/255))
                        Text("Not Connected").opacity(0.8)
                    }
                }
                .padding([.top, .bottom], 1)
                .padding([.leading, .trailing], 15)
                // IP Addresses
                if ipAddressManager.isConnected {
                    HStack {
                        if let ipv4 = ipAddressManager.ipv4Address {
                            Text("IPv4: \(ipv4)").frame(maxWidth: .infinity, alignment: .leading).opacity(0.8)
                        }
                        Spacer()
                        if let ipv6 = ipAddressManager.ipv6Address {
                            Text("IPv6: \(ipv6)").frame(maxWidth: .infinity, alignment: .trailing).opacity(0.8)
                        }
                    }
                    .padding([.top, .bottom], 1)
                    .padding([.leading, .trailing], 15)
                }
            }
        }.onAppear {
            print("Is connected: \(ipAddressManager.isConnected)")
            print("IPv4: \(ipAddressManager.ipv4Address ?? "None")")
            print("IPv6: \(ipAddressManager.ipv6Address ?? "None")")
        }
    }

    enum CommandResult {
        case success(String)
        case failure(Error)
    }

    // Send a command and return stdout
    func sendCommandWithOutput(_ command: AllowedCommand, completion: @escaping (CommandResult) -> Void) {
        let message: AllowedCommandMessage = .standardCommand(command)

        print("[DEBUG] Sent message command \(command) to the XPC helper meow...")
        DispatchQueue.global(qos: .userInitiated).async {
            self.xpcClient.sendMessage(message, to: SharedConstants.allowedCommandRoute) { response in
                DispatchQueue.main.async {
                    print("[DEBUG] Received response from XPC client.")
                    switch response {
                    case .success(let allowedCommandReply):
                        print("[DEBUG] Success response: \(allowedCommandReply)")
                        if command == .nexDisconnect {
                            self.authURL = ""
                            self.ipAddress = "Not Connected"
                        }
                        // Use standardOutput field directly
                        if let outputString = allowedCommandReply.standardOutput {
                            completion(.success(outputString))
                        } else {
                            completion(.failure(NSError(domain: "Custom", code: -1, userInfo: ["Description": "Output not available"])))
                        }
                    case .failure(let error):
                        print("[DEBUG] Error response: \(error)")
                        completion(.failure(error))
                    }
                }
            }
        }
    }

    // Send a command and ignore stdout
    func sendCommand(_ command: AllowedCommand, completion: @escaping () -> Void) {
        let message: AllowedCommandMessage
        message = .standardCommand(command)

        print("[DEBUG] Sent message command \(command) to the XPC helper meow...")
        DispatchQueue.global(qos: .userInitiated).async {
            self.xpcClient.sendMessage(message, to: SharedConstants.allowedCommandRoute) { response in
                DispatchQueue.main.async {
                    print("[DEBUG] Received response from XPC client.")
                    switch response {
                    case .success(let value):
                        print("[DEBUG] Success response: \(value)")
                        if command == .nexDisconnect {
                            self.authURL = ""
                            self.ipAddress = "Not Connected"
                        }
                    case .failure(let error):
                        print("[DEBUG] Error response: \(error)")
                    }
                    completion()
                }
            }
        }
    }
}

class NexdManager: ObservableObject {
    var process: Process?
}

extension AllowedCommand: Equatable {
    static func == (lhs: AllowedCommand, rhs: AllowedCommand) -> Bool {
        switch (lhs, rhs) {
        case (.nexctlPeersLS, .nexctlPeersLS): return true
        case (.nexctlPeersPing, .nexctlPeersPing): return true
        case (.whoami, .whoami): return true
        case (.nexctlStat, .nexctlStat): return true
        case (.nexdConnect, .nexdConnect): return true
        case (.nexDisconnect, .nexDisconnect): return true
        case (.startNexdService, .startNexdService): return true
        case (.stopNexdService, .stopNexdService): return true
        case (.viewNexdLogs, .viewNexdLogs): return true
        default: return false
        }
    }
}

class IPAddressManager: ObservableObject {
    @Published var ipAddress: String? = "Not Connected"
    @Published var ipv4Address: String? = nil
    @Published var ipv6Address: String? = nil
    @Published var isConnected: Bool = false

    init() {
        Timer.scheduledTimer(withTimeInterval: 6.0, repeats: true) { [weak self] _ in
            let addresses = getIPAddresses()
            self?.ipv4Address = addresses.0
            self?.ipv6Address = addresses.1
            self?.isConnected = addresses.0 != nil || addresses.1 != nil
        }
    }
}

// parse the v4 and v6 addresses
func getIPAddresses() -> (String?, String?) {
    var ipv4: String?
    var ipv6: String?

    var ifaddr: UnsafeMutablePointer<ifaddrs>?
    if getifaddrs(&ifaddr) == 0 {
        var ptr = ifaddr
        while ptr != nil {
            defer { ptr = ptr?.pointee.ifa_next }

            let interface = ptr?.pointee
            let addrFamily = interface?.ifa_addr.pointee.sa_family
            if let name = interface?.ifa_name, String(cString: name) == "utun8", let addr = interface?.ifa_addr {
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                getnameinfo(addr, socklen_t((interface?.ifa_addr.pointee.sa_len)!), &hostname, socklen_t(NI_MAXHOST), nil, socklen_t(0), NI_NUMERICHOST)
                if addrFamily == UInt8(AF_INET) {
                    ipv4 = String(cString: hostname)
                } else if addrFamily == UInt8(AF_INET6) {
                    ipv6 = String(cString: hostname)
                }
            }
        }
        freeifaddrs(ifaddr)
    }
    return (ipv4, ipv6)
}
