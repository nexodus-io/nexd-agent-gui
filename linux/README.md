## Linux Nexodus Agent GUI

This is a WIP nexd GUI for Linux written in Typescript using the [Electron](https://www.electronjs.org) framework. The app is currently a tray icon app that looks as follows.

<img src='../docs/images/linux-gui-usage-1.png' width='250'>

### Run

Install [Nexodus RPM or Deb](https://docs.nexodus.io/quickstart/) which installs the Nexodus systemd service and then download the gui binary and run the app.

- [nexodus-agent-gui-linux-amd64](https://nexodus-io.s3.amazonaws.com/gui/nexodus-agent-gui-linux-86_x64.zip)
- [nexodus-agent-gui-linux-arm64](https://nexodus-io.s3.amazonaws.com/gui/nexodus-agent-gui-linux-arm64.zip)

This uses [sudo-prompt](https://www.npmjs.com/package/sudo-prompt) for privileged escalation when stopping and starting the nexodus service.

- `Connect` starts the nexd service. If there are no cached credentials, the app will watch systemd logs for a one-time code for login. If credentials are cached, nexd will connect.
- `Disconnect` tears down nexd and kills the processes, `nexd.exe` and `wireguard.exe`.
- `Open Auth URL` will copy the one-time Auth URL from the logs to your clipboard. From there you open the URL into a browser.
- `Settings` menu entry (not implemented).
- `View Logs` Open nexd logs in the host's default text editor.
- Once the device connects and is registered, the v4 and v6 IPs are in the menu if they are present on the Nexodus wireguard interface.
- `Exit` Terminates the app. The systemd nexd service will continue to run.

### Dev

For development, build and run with the following.

```
git clone https://github.com/nexodus-io/nexd-agent-gui
cd linux/

# Install dependancies
npm install

# Run the app
npm run
```

### Packaging

To package the electron App, run the following.

```text
npm install --save-dev electron-packager

### ARM64
electron-packager . nexodus-agent-gui --platform=linux --arch=arm64

### x64
# electron-packager . nexodus-agent-gui --platform=linux --arch=x64
```
