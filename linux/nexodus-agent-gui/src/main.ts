import {app, BrowserWindow, Menu, MenuItemConstructorOptions, nativeImage, shell, Tray} from 'electron';
import path from 'path';
import sudo from 'sudo-prompt';
import {checkWg0Interface} from "./networkUtils";
import {openLogs} from "./logUtils";

// Initialize the application
if (require('electron-squirrel-startup')) {
    app.quit();
}

let tray: Tray | null = null;
let globalAuthUrl: string | null = null;
let needsUpdate = false;

let connectionStatus: MenuItemConstructorOptions = {
    label: 'Not Connected',
    enabled: false
};

const menuItems: MenuItemConstructorOptions[] = [
    {
        label: 'Start Nexodus Service',
        type: 'normal',
        click: () => {
            console.log('Starting Nexodus Service...');
            const commands = [
                'systemctl enable nexodus',
                'systemctl start nexodus',
                'sleep 6',
                'nexctl nexd status',
            ];
            const commandString = commands.join('; ');

            const options = {
                name: 'Nexodus Service',
            };

            sudo.exec(commandString, options, (error, stdout, stderr) => {
                if (error) {
                    console.error(`Error executing command: ${error}`);
                    return;
                }

                const stdoutStr = stdout.toString();
                console.log(`stdout: ${stdoutStr}`);
                console.error(`stderr: ${stderr}`);

                // Parse stdout to extract the URL
                const urlMatch = stdoutStr.match(/(https:\/\/[^\s]+)/);
                if (urlMatch && urlMatch[1]) {
                    globalAuthUrl = urlMatch[1]; // Update the global auth URL
                    console.log(`Found Auth URL: ${globalAuthUrl}`);
                } else {
                    globalAuthUrl = null; // No URL was found
                    console.log('No Auth URL found.');
                }

                updateContextMenu();
            });
        },
    },
    {
        label: 'Stop Nexodus Service',
        type: 'normal',
        click: () => {
            console.log('Stopping Nexodus Service...');
            const commandString = 'systemctl stop nexodus';
            const options = {
                name: 'Nexodus Service Stop',
            };

            sudo.exec(commandString, options, (error, stdout, stderr) => {
                if (error) {
                    console.error(`Error executing command: ${error}`);
                    return;
                }

                console.log(`stdout: ${stdout}`);
                console.error(`stderr: ${stderr}`);
                // Optionally, update the menu here if needed
                updateContextMenu();
            });
        },
    },
    {
        label: '',
        type: 'separator'
    },
    {
        label: '',
        type: 'separator'
    },
    {
        label: 'View Logs',
        type: 'normal',
        click: async () => {
            await openLogs();
        },
    },
    {
        label: 'Settings',
        type: 'normal',
    },
    {
        label: 'Quit',
        type: 'normal',
        click: () => {
            console.log('Exiting Nexodus...');
            app.quit();
        }
    }
];


const refreshTrayStatus = async () => {
    console.log('Refreshing tray status...');
    const newConnectionStatus = await checkWg0Interface();
    if (newConnectionStatus.label !== connectionStatus.label || newConnectionStatus.enabled !== connectionStatus.enabled) {
        connectionStatus.label = newConnectionStatus.label;
        connectionStatus.enabled = newConnectionStatus.enabled;
        needsUpdate = true;  // Set flag to indicate that the menu should be updated
    }
    console.log(`Updated connectionStatus to: ${JSON.stringify(connectionStatus)}`);
    maybeUpdateContextMenu(); // New function to conditionally update the context menu
};

const maybeUpdateContextMenu = () => {
    if (needsUpdate) {
        updateContextMenu();
        needsUpdate = false; // Reset flag
    }
};


const updateContextMenu = () => {
    console.log('Updating context menu...');
    const separatorIndex = menuItems.findIndex(item => item.type === 'separator');
    const itemsBeforeSeparator = menuItems.slice(0, separatorIndex + 1);
    const itemsAfterSeparator = menuItems.slice(separatorIndex + 1);

    // Ordering of the menu
    const newMenuItems: MenuItemConstructorOptions[] = [
        ...itemsBeforeSeparator,
        connectionStatus
    ];

    if (globalAuthUrl) {
        newMenuItems.push({
            label: 'Open Auth URL',
            type: 'normal',
            click: () => shell.openExternal(globalAuthUrl!),
            enabled: true,
        });
    }

    newMenuItems.push(...itemsAfterSeparator);

    const newContextMenu = Menu.buildFromTemplate(newMenuItems);
    tray!.setContextMenu(newContextMenu);
};

app.on('ready', () => {
    createTray();
    // Call checkWg0Interface initially
    checkWg0Interface();
    // Initial checks and refresh intervals
    refreshTrayStatus();
    // refreshAuthUrl();
    // Set intervals to call refresh functions
    setInterval(async () => { await refreshTrayStatus(); }, 4000);
    setInterval(async () => { await checkWg0Interface(); }, 4000);
});


const createTray = () => {
    const iconPath = path.join(__dirname, 'nexodus-logo-32x32.png');
    let image = nativeImage.createFromPath(iconPath);
    const platform = process.platform;
    let size = {width: 32, height: 32};

    if (platform === 'darwin') {
        size = {width: 20, height: 20};
    } else if (platform === 'win32') {
        size = {width: 16, height: 16};
    } else if (platform === 'linux') {
        size = {width: 22, height: 22};
    }

    image = image.resize(size);

    if (image.isEmpty()) {
        console.error("The image data is empty");
        return;
    }

    tray = new Tray(image);
    const contextMenu = Menu.buildFromTemplate(menuItems);
    tray.setToolTip('This is my application.');
    tray.setContextMenu(contextMenu);
};


app.on('window-all-closed', () => {
    if (process.platform !== 'darwin') {
        app.quit();
    }
});

app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
        createWindow();
    }
});

const createWindow = () => {
    const mainWindow = new BrowserWindow({
        width: 800,
        height: 600,
        webPreferences: {
            preload: path.join(__dirname, 'preload.js'),
        },
    });

    if (MAIN_WINDOW_VITE_DEV_SERVER_URL) {
        mainWindow.loadURL(MAIN_WINDOW_VITE_DEV_SERVER_URL);
    } else {
        mainWindow.loadFile(path.join(__dirname, `../renderer/${MAIN_WINDOW_VITE_NAME}/index.html`));
    }

    mainWindow.webContents.openDevTools();
};
