import Foundation
import EmbeddedPropertyList

/// Monitors the on disk location of the helper tool and its launchd property list.
///
/// Whenever those files change, the helper tool's embedded info property list is read and the launchd status is queried (via the public interface to launchctl). This
/// means this monitor has a limitation that if *only* the launchd registration changes then this monitor will not automatically pick up this changed. However, if
/// `determineStatus()` is called it will always reflect the latest state including querying launchd status.
class HelperToolMonitor {
    /// Encapsulates the installation status at approximately a moment in time.
    ///
    /// The individual properties of this struct can't be queried all at once, so it is possible for this to reflect a state that never truly existed simultaneously.
    struct InstallationStatus {
        
        /// Status of the helper tool executable as exists on disk.
        enum HelperToolExecutable {
            /// The helper tool exists in its expected location.
            ///
            /// Associated value is the helper tool's bundle version.
            case exists(BundleVersion)
            /// No helper tool was found.
            case missing
        }
        
        /// The helper tool is registered with launchd (according to launchctl).
        let registeredWithLaunchd: Bool
        /// The property list used by launchd exists on disk.
        let registrationPropertyListExists: Bool
        /// Whether an on disk representation of the helper tool exists in its "blessed" location.
        let helperToolExecutable: HelperToolExecutable
    }
    
    /// Directories containing installed helper tools and their registration property lists.
    private let monitoredDirectories: [URL]
    /// Mapping of monitored directories to corresponding dispatch sources.
    private var dispatchSources = [URL : DispatchSourceFileSystemObject]()
    /// Queue to receive callbacks on.
    private let directoryMonitorQueue = DispatchQueue(label: "directorymonitor", attributes: .concurrent)
    /// Name of the privileged executable being monitored
    private let constants: SharedConstants
    
    /// Creates the monitor.
    /// - Parameter constants: Constants defining needed file paths.
    init(constants: SharedConstants) {
        self.constants = constants
        self.monitoredDirectories = [constants.blessedLocation.deletingLastPathComponent(),
                                     constants.blessedPropertyListLocation.deletingLastPathComponent()]
    }
    
    /// Starts the monitoring process.
    ///
    /// If it's already been started, this will have no effect. This function is not thread safe.
    /// - Parameter changeOccurred: Called when the helper tool or registration property list file is created, deleted, or modified.
    func start(changeOccurred: @escaping (InstallationStatus) -> Void) {
        if dispatchSources.isEmpty {
            for monitoredDirectory in monitoredDirectories {
                let fileDescriptor = open((monitoredDirectory as NSURL).fileSystemRepresentation, O_EVTONLY)
                let dispatchSource = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fileDescriptor,
                                                                               eventMask: .write,
                                                                               queue: directoryMonitorQueue)
                dispatchSources[monitoredDirectory] = dispatchSource
                dispatchSource.setEventHandler {
                    changeOccurred(self.determineStatus())
                }
                dispatchSource.setCancelHandler {
                    close(fileDescriptor)
                    self.dispatchSources.removeValue(forKey: monitoredDirectory)
                }
                dispatchSource.resume()
            }
        }
    }

    /// Stops the monitoring process.
    ///
    /// If the process wa never started, this will have no effect. This function is not thread safe.
    func stop() {
        for source in dispatchSources.values {
            source.cancel()
        }
    }
    
    /// Determines the installation status of the helper tool
    /// - Returns: The status of the helper tool installation.
    func determineStatus() -> InstallationStatus {
        // Sleep for 50ms because on disk file changes, which triggers this call, can occur before launchctl knows about
        // the (de)registration
        Thread.sleep(forTimeInterval: 0.05)
        
        // Registered with launchd
        let process = Process()
        process.launchPath = "/bin/launchctl"
        process.arguments = ["print", "system/\(constants.helperToolLabel)"]
        process.qualityOfService = QualityOfService.userInitiated
        process.standardOutput = nil
        process.standardError = nil
        process.launch()
        process.waitUntilExit()
        let registeredWithLaunchd = (process.terminationStatus == 0)
        
        // Registration property list exists on disk
        let registrationPropertyListExists = FileManager.default
                                                        .fileExists(atPath: constants.blessedPropertyListLocation.path)
        
        let helperToolExecutable: InstallationStatus.HelperToolExecutable
        do {
            let infoPropertyList = try HelperToolInfoPropertyList(from: constants.blessedLocation)
            helperToolExecutable = .exists(infoPropertyList.version)
        } catch {
            helperToolExecutable = .missing
        }
        
        return InstallationStatus(registeredWithLaunchd: registeredWithLaunchd,
                                  registrationPropertyListExists: registrationPropertyListExists,
                                  helperToolExecutable: helperToolExecutable)
    }
}
