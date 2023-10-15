## Darwin Nexodus Agent GUI

This is a WIP nexd GUI for Darwin written in Swift. Contributions are welcome!

### Quickstart

- Install the Nexodus brew package for macOS described in the [Nexodus Quickstart](https://docs.nexodus.io/quickstart/)
- Download and install the Neoxodus Agent GUI from this repo [NexodusAgent.pkg](https://nexodus-io.s3.amazonaws.com/gui/NexodusAgent-macOS-10072023.pkg)
- Click on the `Naxodus Agent` app in the `/Applications` folder. The right click on the menubar and choose how you want to connect.
- Right-click on the menubar app to start the service. If the host is not authenticated yet, the copy auth selection in the menu will be clickable and will copy the one-time auth to your clipboard to paste in a browser.
- Note: if you are upgrading, you may need to kill the helper process until all scenarios are handled. This will clean things up prior to re-installing if you have an existing install. Once you clean those up, just re-install the new pkg.

```
sudo brew services stop nexodus-io/nexodus/nexodus
sudo pkill -9 -f "/Library/PrivilegedHelperTools/io.nexodus.nexodus-gui.helper"
sudo rm -rf /Applications/Nexodus\ Agent.app/
sudo rm /Library/PrivilegedHelperTools/io.nexodus.nexodus-gui.helper
```

<img src='../docs/images/darwin-gui-usage-1.png' width='325'>

- `Connect`Nexodus starts nexd. If there are no cached credentials, the app will watch the log files for a one-time code for login. If credentials are cached, nexd will connect.
- `Disconnect`Nexodus tears down nexd and kills the processes, nexd and wireguard-go.
- `Start Nexd Service` starts the brew service.
- `Stop Nexd Service` stops the brew service.
- `Copy Auth URL` will copy the one-time Auth URL from the logs to your clipboard. From there you paste the URL into a browser.
- `Debug` opens tools for debugging and and install/uninstaler for the helper.
- `View Logs` Open nexd logs in the host's default text editor.
- Once the device connects and is registered, the v4 and v6 IPs are in the menu if they are present on the Nexodus wireguard interface.
- `Exit` Terminates the app. If running the default service mode, the service will continue running. If you reopen the App you can stop the service or even manually stop the service with: `sudo brew services stop nexodus-io/nexodus/nexodus`.

### Agent Install Signing Workaround

The packages are not currently signed through the App store, so you will need to make an exception for the package. 

<img src='../docs/images/darwin-gui-install-1.png' width='450'>

To do this open the package and when prompted that it is from an unidentified developer, navigate to `System Preferences > Privacy and Security` click `Open Anyways`.

<img src='../docs/images/darwin-gui-install-2.png' width='500'>

### Agent Removal

To remove, simply stop the service and delete these two files.

```console
sudo rm -rf /Applications/Nexodus\ Agent.app/
sudo rm /Library/PrivilegedHelperTools/io.nexodus.nexodus-gui.helper
```

### Development Environment with xcode

There are two components to this App. The GUI App `Nexodus Agent.app` in `/Applications/` and a helper process that handles privileged executions as part of macOS escalated application framework `SMBJobless` located in `/Library/PrivilegedHelperTools/io.nexodus.nexodus-gui.helper`.

- Clone and open `NexodusAgentApp.xcodeproj` with your swift editor.
- Apple requires an account to develop in xcode, set up a provisioning profile to code sign your apps:
    - Open Xode preferences (Xcode > Preferences…)
    - Click the ‘Accounts’ tab
    - Login with your Apple ID (+ > Add Apple ID…)
    - Once you’ve successfully logged in, a new ‘Personal Team’ with the role ‘Free’ will appear beneath your Apple ID. Then you can switch sign locally to your personal team under `Signing & Capabilities`.
    - Alternatively, you can build using xcodebuilder in the same fashion as CI with the following with xcode v15.0+ but ultimately you'll want to be able to build in your IDE as well.

```
CI_SKIP_SIGNING=true xcodebuild -project NexodusAgentApp.xcodeproj -scheme NexodusAgentApp
CI_SKIP_SIGNING=true xcodebuild -project NexodusAgentApp.xcodeproj -scheme NexodusAgentHelper
```

- Finally, run the app by hitting the play button.

![no-alt-text](../docs/images/darwin-gui-dev-2.png)
