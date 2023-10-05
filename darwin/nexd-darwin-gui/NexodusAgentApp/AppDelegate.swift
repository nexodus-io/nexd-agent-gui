import Cocoa
import os.log
import SecureXPC
import SwiftUI

@main
struct UtilityApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            AppMenu()
        } label: {
            Image("nexodus-logo-square-48x48-menubar")
        }
        WindowGroup {}
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var windowController: NSWindowController?

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil) // Hide the window
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

    var body: some View {
        VStack {
            Group {
                // Uncomment to enable the binary only connection option for now
                // Button(action: menuConnect, label: { Text("Connect Nexodus") })
                // Button(action: menuDisconnect, label: { Text("Disconnect Nexodus") })
                // Divider()
                Button(action: startNexdService, label: { Text("Start Nexd Service") })
                Button(action: stopNexdService, label: { Text("Stop Nexd Service") })
            }
            Group {
                Divider()
                nexdStatusDisplay()
                Button(action: menuCopyAuthURLToClipboard) {
                    HStack {
                        Image(systemName: "doc.on.doc")
                            .foregroundColor(Color(red: 66/255, green: 72/255, blue: 82/255))
                        Text("Copy Auth URL")
                    }
                }
                .disabled(authURL.isEmpty || isCopyAuthURLButtonClicked)
                .opacity(isCopyAuthURLButtonClicked ? 0.5 : 1)
                Divider()
                Button(action: openNexdLogs, label: { Text("Open Nexodus Logs") })
            }
            Group {
                Button(action: menuSettings, label: { Text("Debugging") })
                Button(action: menuExit, label: { Text("Exit") })
            }
        }
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

    func menuConnect() {
        print("menuConnect() called.")
        sendCommand(.nexdConnect) {}
        // Wait for 6 seconds and then read the file (TODO: should be a retry instead of a fixed timer)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            print("[DEBUG] Checking file for auth details.")
            self.checkFileForAuthDetails()
        }
    }

    func menuDisconnect() {
        sendCommand(.nexDisconnect) {}
    }

    // New function to start Nexd service
    func startNexdService() {
        print("startNexdService() called.")
        sendCommand(.startNexdService) {
            print("Nexd Service started.")
        }

        // Wait for 6 seconds and then read the file (TODO: should be a retry instead of a fixed timer)
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            print("[DEBUG] Checking file for auth details.")
            self.checkNexctlForAuthDetails()
        }
    }

    // New function to stop Nexd service
    func stopNexdService() {
        print("stopNexdService() called.")
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

    func menuExit() {
        sendCommand(.nexDisconnect) {
            exit(0)
        }
    }

    func checkFileForAuthDetails() {
        guard let fileContents = try? String(contentsOfFile: "/var/lib/nexd/nexd-log.log") else { return }
        processOutput(fileContents)
    }

    func checkNexctlForAuthDetails() {
        print("Running 'nexctl nexd status' command through XPC helper...")
        sendNexctlStatCommand { output in
            if let output = output {
                print("Command Output: \(output)")
                processOutput(output)
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

    func processOutput(_ output: String) {
        if let codeMatch = output.range(of: "Your one-time code is: ([A-Z\\-]+)", options: .regularExpression) {
            // Extract only the code for debug logs
            oneTimeCode = String(output[codeMatch.lowerBound ..< codeMatch.upperBound].dropFirst(24))
            print("Extracted one-time code: \(oneTimeCode)") // Debug
        } else {
            print("No one-time code found in the logs.") // Debug
        }

        if let urlMatch = output.range(of: "https://auth.try.nexodus.io/[^\\s]+", options: .regularExpression) {
            authURL = String(output[urlMatch.lowerBound ..< urlMatch.upperBound])
            print("Extracted URL: \(authURL)") // Debug
        } else {
            print("No auth URL found in the logs.") // Debug
            // If the URL isn't found, clear the authURL
            authURL = ""
        }

        // Forcing showAlert to true for debugging
        showAlert = true
    }

    private func nexdStatusDisplay() -> some View {
        Group {
            HStack {
                if ipAddressManager.isConnected {
                    Text(Image(systemName: "circle.fill")).foregroundColor(Color(red: 21/255, green: 116/255, blue: 51/255)) + Text("  Connected")
                } else {
                    Text(Image(systemName: "circle.fill")).foregroundColor(Color(red: 178/255, green: 53/255, blue: 43/255)) + Text("  Not Connected")
                }
            }
            if ipAddressManager.isConnected {
                VStack(alignment: .leading) {
                    if let ipv4 = ipAddressManager.ipv4Address {
                        HStack {
                            Text("IPv4: \(ipv4)")
                        }
                    }
                    if let ipv6 = ipAddressManager.ipv6Address {
                        HStack {
                            Text("IPv6: \(ipv6)")
                        }
                    }
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
        // Initialize the message here
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
                    completion() // completion closure here
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
