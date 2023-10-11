import Authorized
import Foundation

/// Runs an allowed command.
enum AllowedCommandRunner {
    /// Runs the allowed command and replies with the results.
    ///
    /// If authorization is needed, the user will be prompted.
    ///
    /// - Parameter message: Message containing the command to run, and if applicable the authorization.
    /// - Returns: The results of running the command.
    static func run(message: AllowedCommandMessage) throws -> AllowedCommandReply {
        print("[DEBUG] Running command: \(message.command)")
        // Prompt user to authorize if the client requested it
        if case .authorizedCommand(_, let authorization) = message {
            let rights = try authorization.requestRights([SharedConstants.exampleRight],
                                                         environment: [],
                                                         options: [.interactionAllowed, .extendRights])
            guard rights.contains(where: { $0.name == SharedConstants.exampleRight.name }) else {
                throw AllowedCommandError.authorizationFailed
            }
        } else if message.command.requiresAuth { // Authorization is required, but the client did not request it
            throw AllowedCommandError.authorizationNotRequested
        }

        // Launch process and wait for it to finish
        let process = Process()
        process.launchPath = message.command.launchPath
        process.arguments = message.command.arguments
        process.qualityOfService = QualityOfService.userInitiated

        // Set the PATH environment variable for nexd command
        var environment = ProcessInfo.processInfo.environment
        environment["PATH"] = "/opt/homebrew/bin:" + (environment["PATH"] ?? "")
        process.environment = environment

        let outputPipe = Pipe()
        defer { outputPipe.fileHandleForReading.closeFile() }
        process.standardOutput = outputPipe
        let errorPipe = Pipe()
        defer { errorPipe.fileHandleForReading.closeFile() }
        process.standardError = errorPipe
        process.launch()
        process.waitUntilExit()

        // Convert a pipe's data to a string if there was non-whitespace output
        let pipeAsString = { (pipe: Pipe) -> String? in
            let output = String(data: pipe.fileHandleForReading.availableData, encoding: String.Encoding.utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return output.isEmpty ? nil : output
        }

        // Special handling for the disconnect command
        switch message.command {
        case .nexDisconnect:
            print("[DEBUG] killing nexd for disconnect")
            killProcesses(named: ["/opt/homebrew/bin/nexd", "/opt/homebrew/bin/nexd-wireguard-go"])
            return AllowedCommandReply(terminationStatus: 0,
                                       standardOutput: "Processes terminated successfully.",
                                       standardError: nil)
        case .nexdConnect:
            print("[DEBUG] starting nexd.")
            let logFilePath = "/var/lib/nexd/nexd-log.log"

            // First command
            let prepLog = """
            chmod a+rx /var/lib/nexd/ && \
            touch \(logFilePath) && \
            chmod a+r \(logFilePath)
            """
            executeShellCommand(prepLog)
            // Second command
            let connect = """
            PATH=/opt/homebrew/bin:$PATH && \
            /opt/homebrew/bin/nexd > \(logFilePath) 2>&1
            """
            executeShellCommand(connect)
        case .startNexdService:
            let reply = manageNexdService(action: .start)
            return reply

        case .stopNexdService:
            let reply = manageNexdService(action: .stop)
            return reply
        case .openNexdLogs:
            print("[DEBUG] opening nexd logs.")
            let logPaths = findNexdLogs()
            
            for logPath in logPaths {
                executeShellCommand("open \(logPath)")
            }
        default:
            break
        }

        return AllowedCommandReply(terminationStatus: process.terminationStatus,
                                   standardOutput: pipeAsString(outputPipe),
                                   standardError: pipeAsString(errorPipe))
    }

    static func killProcesses(named names: [String]) {
        for name in names {
            let task = Process()
            task.launchPath = "/usr/bin/pkill"
            task.arguments = ["-f", name]
            task.launch()
            task.waitUntilExit()
        }
    }

    private static func executeShellCommand(_ command: String) {
        let task = Process()
        task.launchPath = "/bin/sh"
        task.arguments = ["-c", command]

        let outputPipe = Pipe()
        task.standardOutput = outputPipe
        let errorPipe = Pipe()
        task.standardError = errorPipe

        task.launch()
        task.waitUntilExit()

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""
        print("Command output: \(output)")

        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let errorOutput = String(data: errorData, encoding: .utf8) ?? ""
        print("Command error output: \(errorOutput)")
    }
}

enum ServiceAction {
    case start
    case stop
}

func manageNexdService(action: ServiceAction) -> AllowedCommandReply {
    print("[DEBUG] \(action == .start ? "Starting" : "Stopping") Nexodus service.")
    
    // Default to /opt/homebrew and override with HOMEBREW_PREFIX if it's set
    let homebrewPrefix = ProcessInfo.processInfo.environment["HOMEBREW_PREFIX"] ?? "/opt/homebrew"
    let brewBinaryPath = "\(homebrewPrefix)/bin/brew"
    
    let task = Process()
    task.launchPath = "/usr/bin/sudo"
    task.arguments = [brewBinaryPath, "services", action == .start ? "start" : "stop", "nexodus-io/nexodus/nexodus"]
    task.qualityOfService = .userInitiated

    let environment = ProcessInfo.processInfo.environment
    task.environment = environment

    let outputPipe = Pipe()
    task.standardOutput = outputPipe
    let errorPipe = Pipe()
    task.standardError = errorPipe

    task.launch()
    task.waitUntilExit()

    let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: outputData, encoding: .utf8) ?? ""

    let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
    let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

    return AllowedCommandReply(terminationStatus: task.terminationStatus,
                               standardOutput: output.isEmpty ? nil : output,
                               standardError: errorOutput.isEmpty ? nil : errorOutput)
}


// Function to find nexd logs from a specific location based on HOMEBREW_PREFIX
func findNexdLogs() -> [String] {
    // Default to /opt/homebrew and override with HOMEBREW_PREFIX if it's set
    let homebrewPrefix = ProcessInfo.processInfo.environment["HOMEBREW_PREFIX"] ?? "/opt/homebrew"
    let logLocation = "\(homebrewPrefix)/var/log/"

    var foundLogPaths: [String] = []
    
    let stdoutLogPath = "\(logLocation)nexd-stdout.log"
    let stderrLogPath = "\(logLocation)nexd-stderr.log"
        
    if FileManager.default.fileExists(atPath: stdoutLogPath) {
        foundLogPaths.append(stdoutLogPath)
    }
        
    if FileManager.default.fileExists(atPath: stderrLogPath) {
        foundLogPaths.append(stderrLogPath)
    }
    
    return foundLogPaths
}

