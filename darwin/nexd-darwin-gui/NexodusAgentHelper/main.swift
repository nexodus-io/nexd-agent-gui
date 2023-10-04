import Foundation
import SecureXPC
import os

let helperLog = OSLog(subsystem: "io.nexodus.nexodus-gui.helper", category: "HelperTool")

os_log("starting helper tool. PID %{public}d. PPID %{public}d.", log: helperLog, getpid(), getppid())
os_log("version: %{public}@", log: helperLog, String(describing: try HelperToolInfoPropertyList.main.version.rawValue))

// Command line arguments were provided, so process them
if CommandLine.arguments.count > 1 {
    // Remove the first argument, which represents the name (typically the full path) of this helper tool
    var arguments = CommandLine.arguments
    _ = arguments.removeFirst()
    os_log("run with arguments: %{public}@", log: helperLog, arguments.description)
    
    if let firstArgument = arguments.first {
        if firstArgument == Uninstaller.commandLineArgument {
            try Uninstaller.uninstallFromCommandLine(withArguments: arguments)
        } else {
            os_log("argument not recognized: %{public}@", log: helperLog, firstArgument)
        }
    }
} else if getppid() == 1 { // Otherwise if started by launchd, start up server
    os_log("parent is launchd, starting up server", log: helperLog)
    
    let server = try XPCServer.forMachService()
    server.registerRoute(SharedConstants.allowedCommandRoute, handler: AllowedCommandRunner.run(message:))
    server.registerRoute(SharedConstants.uninstallRoute, handler: Uninstaller.uninstallFromXPC)
    server.registerRoute(SharedConstants.updateRoute, handler: Updater.updateHelperTool(atPath:))
    server.setErrorHandler { error in
        if case .connectionInvalid = error {
            // Ignore invalidated connections as this happens whenever the client disconnects which is not a problem
        } else {
            os_log("error: %{public}@", log: helperLog, error.localizedDescription)
        }
    }
    server.startAndBlock()
} else { // Otherwise started via command line without arguments, print out help info
    print("Usage: \(try CodeInfo.currentCodeLocation().lastPathComponent) <command>")
    print("\nCommands:")
    print("\t\(Uninstaller.commandLineArgument)\tUnloads and deletes from disk this helper tool and configuration.")
}
