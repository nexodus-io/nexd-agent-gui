import Foundation
import SwiftUI

@main
struct UtilityApp: App {
    var body: some Scene {
        MenuBarExtra {
            AppMenu()
        } label: {
            Image("nexodus-logo-square-48x48-menubar")
        }
        WindowGroup {}
    }
}

class NexdManager: ObservableObject {
    var process: Process?
}

struct AppMenu: View {
    @StateObject private var nexdManager = NexdManager()
    @State private var showAlert = false
    @State private var oneTimeCode: String = ""
    @State private var authURL: String = ""
    @State private var showLogFile = false
    @State private var ipAddress: String = "Not Connected"
    @StateObject private var ipAddressManager = IPAddressManager()

    func menuConnect() {
        executeShellWithSudo()

        // Fetch IP after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            let addresses = getIPAddresses()
            if let ipv4 = addresses.0 {
                self.ipAddress = "IPv4: \(ipv4)"
                if let ipv6 = addresses.1 {
                    self.ipAddress += "\nIPv6: \(ipv6)"
                }
            } else if let ipv6 = addresses.1 {
                self.ipAddress = "IPv6: \(ipv6)"
            } else {
                self.ipAddress = "Unable to fetch IP"
            }
        }
    }

    func menuDisconnect() {
        nexdManager.process?.terminate()
        nexdManager.process = nil
        killProcesses(named: ["/opt/homebrew/bin/nexd", "/opt/homebrew/bin/nexd-wireguard-go"])
        authURL = ""
        ipAddress = "Not Connected"
    }

    func menuCopyAuthURLToClipboard() {
        // Check if the authURL is not empty
        if !authURL.isEmpty {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(authURL, forType: .string)
        } else {
            print("Auth URL is empty or not set.")
        }
    }

    func menuSettings() {} // Not Implemented

    func menuExit() {
        exit(0)
    }

    var body: some View {
        // Menu items are added here
        VStack {
            // Connect option starts nexd
            Button(action: menuConnect, label: { Text("Connect Nexodus") })

            // Disconnect tears down nexd and kills the processes, nexd and wireguard-go
            Button(action: menuDisconnect, label: { Text("Disconnect Nexodus") })

            // Copy Auth URL will copy
            Button("Copy Auth URL", action: menuCopyAuthURLToClipboard)
                .disabled(authURL.isEmpty) // Disable the button if authURL is empty

            Divider()

            // Settings menu entry (not implemented)
            Button(action: menuSettings, label: { Text("Settings") })

            // Open nexd logs in the host's default text editor
            Button("Show Log", action: { openLogFileInEditor() })

            // Display the v4 and v6 IPs if present
            ipAddressDisplay()

            Divider()

            // Exit the app
            Button(action: menuExit, label: { Text("Exit") })
        }
    }

    func executeShellWithSudo() {
        let task = Process()

        let script = """
        do shell script "PATH=/opt/homebrew/bin:$PATH; /opt/homebrew/bin/nexd > /tmp/nexd_output.txt 2>&1" with administrator privileges
        """

        task.launchPath = "/usr/bin/osascript"
        task.arguments = ["-e", script]
        task.launch()

        // Wait for 6 seconds and then read the file (TODO: should be a retry instead of a fixed timer)
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
            self.checkFileForAuthDetails()
        }
    }

    func checkFileForAuthDetails() {
        guard let fileContents = try? String(contentsOfFile: "/tmp/nexd_output.txt") else { return }
        processOutput(fileContents)
    }

    func processOutput(_ output: String) {
        if let codeMatch = output.range(of: "Your one-time code is: ([A-Z\\-]+)", options: .regularExpression) {
            oneTimeCode = String(output[codeMatch.lowerBound ..< codeMatch.upperBound].dropFirst(24)) // Extract only the code
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

    private func ipAddressDisplay() -> some View {
        Group {
            if ipAddressManager.isConnected {
                HStack {
                    // This is an attempt to add a green circle denoting the node has an IP and is connected but it isn't working ¯\_(ツ)_/¯
                    Circle().fill(Color.green).frame(width: 10, height: 10)
                    VStack(alignment: .leading) {
                        if let ipv4 = ipAddressManager.ipv4Address {
                            Text("IPv4: \(ipv4)")
                        }
                        if let ipv6 = ipAddressManager.ipv6Address {
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
}

func killProcesses(named names: [String]) {
    let task = Process()

    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyyMMddHHmmss"
    let dateString = dateFormatter.string(from: Date())
    let backupPath = "/tmp/nexd_output_\(dateString).txt"

    let combinedScripts = names.map { "/usr/bin/pkill -f \($0)" }.joined(separator: "; ")

    let script = """
    do shell script "\(combinedScripts); if [ -f /tmp/nexd_output.txt ]; then mv /tmp/nexd_output.txt \(backupPath); fi; touch /tmp/nexd_output.txt" with administrator privileges
    """

    task.launchPath = "/usr/bin/osascript"
    task.arguments = ["-e", script]
    task.launch()
    task.waitUntilExit()
}

func openLogFileInEditor() {
    let task = Process()

    let script = """
    do shell script "sudo -u root /usr/bin/open -a TextEdit /tmp/nexd_output.txt" with administrator privileges
    """

    task.launchPath = "/usr/bin/osascript"
    task.arguments = ["-e", script]
    task.launch()
}

// TODO: popup not working, this simply opens the log file in the default text editor
struct LogFileView: View {
    var logContents: String = ""
    init() {
        let logFilePath = "/tmp/nexd_output.txt"
        if FileManager.default.fileExists(atPath: logFilePath) {
            if let data = try? Data(contentsOf: URL(fileURLWithPath: logFilePath)) {
                logContents = String(data: data, encoding: .utf8) ?? "Failed to load log contents."
            } else {
                logContents = "Error reading the log file."
            }
        } else {
            logContents = "Log file does not exist."
        }
    }

    var body: some View {
        ScrollView {
            Text(logContents)
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 400, height: 300)
    }
}

class IPAddressManager: ObservableObject {
    @Published var ipAddress: String? = "Not Connected"
    @Published var ipv4Address: String? = nil
    @Published var ipv6Address: String? = nil
    @Published var isConnected: Bool = false

    init() {
        Timer.scheduledTimer(withTimeInterval: 20.0, repeats: true) { [weak self] _ in
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
