import Foundation
import Authorized
import Blessed
import os.log

/// Commands which the helper tool is able to run.
///
/// By making this an enum, any other values will fail to properly decode. This prevents non-approved values from being sent by some other (malicious) process on
/// the system or if the intended caller was compromised. This limits the potential damage by restricting the possible actions the helper tool is able to perform.
enum AllowedCommand: Codable, CaseIterable {
    case nexctlPeersPing
    case nexctlPeersLS
    case nexctlStat
    case whoami
    case nexdConnect
    case nexDisconnect
    case startNexdService
    case stopNexdService
    case viewNexdLogs
case openNexdLogs
    
    var displayName: String {
        switch self {
        case .nexctlPeersLS:
            return "Nexd Peers"
        case .nexctlPeersPing:
            return "Nexctl Peers Ping"
        case .nexctlStat:
            return "Nexd Status"
        case .whoami:
            return "Helper Account"
        case .nexdConnect:
            return "Connect Nexodus"
        case .nexDisconnect:
            return "Disconnect Nexodus"
        case .startNexdService:
            return "Start Nexodus Service"
        case .stopNexdService:
            return "Stop Nexodus Service"
        case .viewNexdLogs:
            return "View Nexodus Logs"
        case .openNexdLogs:
            return "Open Nexodus Logs"
        }
    }

    /// All of the cases with all possible argument values.
    static var allCases: [AllowedCommand] {
        var cases = [AllowedCommand]()
        // Nexctl Commands
        cases.append(.nexctlPeersPing)
        cases.append(.nexctlPeersLS)
        cases.append(.nexctlStat)
        cases.append(.whoami)

        // Nexodus commands
        cases.append(.nexdConnect)
        cases.append(.viewNexdLogs)
        cases.append(.nexDisconnect)
        cases.append(.openNexdLogs)
        cases.append(.startNexdService)
        cases.append(.stopNexdService)
        return cases
    }

    /// The location of this executable to be run.
    var launchPath: String {
        let path: String
        switch self {
        case .nexctlStat:
            path = "/bin/sh"
        case .nexctlPeersLS:
            path = "/bin/sh"
        case .nexctlPeersPing:
            path = "/bin/sh"
        case .nexdConnect:
            path = "/bin/sh"
        case .nexDisconnect:
            path = "/usr/bin/pkill"
        case .startNexdService:
            path = "/bin/sh"
        case .stopNexdService:
            path = "/bin/sh"
        case .openNexdLogs:
            path = "/bin/sh"
        case .viewNexdLogs:
            path = "/bin/cat"
        case .whoami:
            path = "/usr/bin/whoami"
        }
        print("[DEBUG] launchPath for \(self): \(path)")
        return path
    }

    /// The arguments to pass to the executable; can be an empty array if there are none.
    var arguments: [String] {
        let args: [String]
        switch self {
        case .nexctlPeersPing:
            let command = """
                          PATH=/opt/homebrew/bin:$PATH && \
                          /opt/homebrew/bin/nexctl nexd peers ping
                          """
            args = ["-c", command]
        case .nexctlPeersLS:
            let command = """
                          PATH=/opt/homebrew/bin:$PATH && \
                          /opt/homebrew/bin/nexctl nexd peers list
                          """
            args = ["-c", command]
        case .nexctlStat:
            let command = """
                          PATH=/opt/homebrew/bin:$PATH && \
                          /opt/homebrew/bin/nexctl nexd status
                          """
            args = ["-c", command]
            case .whoami:
                args = []
            case .nexdConnect:
                args = []
            case .nexDisconnect:
                args = []
            case .startNexdService:
                args = []
            case .stopNexdService:
                args = []
            case .viewNexdLogs:
                args = ["/var/lib/nexd/nexd-log.log"]
            case .openNexdLogs:
                args = []
        }
        print("[DEBUG] arguments for \(self): \(args)")
        return args
    }

    /// Whether running this command should result in the user having to authenticate.
    ///
    /// Which ones require authentication is completely arbitrary, this was just done for example purposes.
    var requiresAuth: Bool {
        switch self {
            case .nexctlPeersPing:
                return false
            case .nexctlPeersLS:
                return false
            case .nexctlStat:
                return false
            case .whoami:
                return false
            case .nexdConnect:
                return false
            case .nexDisconnect:
                return false
            case .startNexdService:
                return false
            case .stopNexdService:
                return false
            case .viewNexdLogs:
                return false
            case .openNexdLogs:
                return false
        }
    }
}

/// A message sent to the helper tool containing a command and an authorization instance if needed.
enum AllowedCommandMessage: Codable {
    case standardCommand(AllowedCommand)
    case authorizedCommand(AllowedCommand, Authorization)
    
    var command: AllowedCommand {
        switch self {
            case .standardCommand(let command):
                return command
            case .authorizedCommand(let command, _):
                return command
        }
    }
}

/// A reply containing the results of the helper tool running a command.
struct AllowedCommandReply: Codable {
    let terminationStatus: Int32
    let standardOutput: String?
    let standardError: String?
}

/// Errors that prevent an allowed command from being run.
enum AllowedCommandError: Error, Codable {
    /// The user did not grant authorization.
    case authorizationFailed
    /// The client did not request authorization, but it was required.
    case authorizationNotRequested
}

