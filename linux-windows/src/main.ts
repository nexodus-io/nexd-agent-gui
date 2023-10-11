import {
  app,
  BrowserWindow,
  Menu,
  MenuItemConstructorOptions,
  nativeImage,
  shell,
  Tray,
} from "electron";
import path from "path";
// import { checkWg0Interface } from "./network-utils-linux";
import { openLogs } from "./log-utils-linux";
import { menuConnectClickLinux, menuDisconnectClickLinux } from "./menu-linux";
import { menuConnectClickWin, menuDisconnectClickWin } from "./menu-windows";
import { checkWgInterfaceWin } from "./network-utils-windows";
import { checkWgInterfaceLinux } from "./network-utils-linux";
import sharedState from "./shared-state";
import * as os from "os";

// Initialize the application
if (require("electron-squirrel-startup")) {
  app.quit();
}

export let tray: Tray | null = null;

let needsUpdate = false;
let currentContextMenu: Electron.Menu;

let connectionStatus: MenuItemConstructorOptions = {
  label: "Not Connected",
  enabled: false,
};

type CheckWgInterfaceFn = () => Promise<MenuItemConstructorOptions>;
type MenuClickFn = (
  menuItem: Electron.MenuItem,
  browserWindow: Electron.BrowserWindow,
  event: Electron.Event,
) => void;

// Determine OS to set appropriate functions
let menuConnectClick: MenuClickFn,
  menuDisconnectClick: MenuClickFn,
  wgInterfaceWatch: CheckWgInterfaceFn;

if (os.platform() === "win32") {
  menuConnectClick = menuConnectClickWin;
  menuDisconnectClick = menuDisconnectClickWin;
  wgInterfaceWatch = checkWgInterfaceWin;
} else {
  menuConnectClick = menuConnectClickLinux;
  menuDisconnectClick = menuDisconnectClickLinux;
  wgInterfaceWatch = checkWgInterfaceLinux;
}

const menuItems: MenuItemConstructorOptions[] = [
  {
    label: "Start Nexodus Service",
    type: "normal",
    click: menuConnectClick,
  },
  {
    label: "Stop Nexodus Service",
    type: "normal",
    click: menuDisconnectClick,
  },
  {
    label: "",
    type: "separator",
  },
  {
    label: "",
    type: "separator",
  },
  {
    label: "View Logs",
    type: "normal",
    click: async () => {
      await openLogs();
    },
  },
  {
    label: "Settings",
    type: "normal",
  },
  {
    label: "Quit",
    type: "normal",
    click: () => {
      console.log("Exiting Nexodus...");
      app.quit();
    },
  },
] as MenuItemConstructorOptions[];

const refreshTrayStatus = async () => {
  try {
    console.log("Refreshing tray status...");

    let newConnectionStatus: MenuItemConstructorOptions;

    // Identify the platform and run the appropriate function
    try {
      if (process.platform === "win32") {
        newConnectionStatus = await checkWgInterfaceWin();
      } else {
        newConnectionStatus = await checkWgInterfaceLinux();
      }
    } catch (error) {
      console.error("Error while checking WireGuard interface status:", error);
      return;
    }

    // Update the connection status if needed
    if (
      newConnectionStatus.label !== connectionStatus.label ||
      newConnectionStatus.enabled !== connectionStatus.enabled
    ) {
      connectionStatus.label = newConnectionStatus.label;
      connectionStatus.enabled = newConnectionStatus.enabled;
      needsUpdate = true; // Set flag to indicate that the menu should be updated
    }

    console.log(
      `Updated connectionStatus to: ${JSON.stringify(connectionStatus)}`,
    );

    // Possibly update the context menu
    maybeUpdateContextMenu();
  } catch (error) {
    console.error("Error in refreshTrayStatus:", error);
  }
};

// Cache the status and only rerender if something in the tray changed to avoid excessive flickering in linux
const maybeUpdateContextMenu = () => {
  try {
    if (needsUpdate) {
      updateContextMenu();
      needsUpdate = false; // Reset flag
    }
  } catch (error) {
    console.error("Error in maybeUpdateContextMenu:", error);
  }
};

export const updateContextMenu = () => {
  console.log("Updating context menu...");
  const separatorIndex = menuItems.findIndex(
    (item) => item.type === "separator",
  );
  const itemsBeforeSeparator = menuItems.slice(0, separatorIndex + 1);
  const itemsAfterSeparator = menuItems.slice(separatorIndex + 1);

  // Ordering of the menu
  const newMenuItems: MenuItemConstructorOptions[] = [
    ...itemsBeforeSeparator,
    connectionStatus,
  ];

  if (sharedState.globalAuthUrl) {
    newMenuItems.push({
      label: "Open Auth URL",
      type: "normal",
      click: () => shell.openExternal(sharedState.globalAuthUrl!),
      enabled: true,
    });
  }

  newMenuItems.push(...itemsAfterSeparator);

  const newContextMenu = Menu.buildFromTemplate(newMenuItems);
  tray!.setContextMenu(newContextMenu);
  currentContextMenu = newContextMenu; // Store the updated menu
};

app.on("ready", () => {
  createTray();
  // Initial checks and refresh intervals
  wgInterfaceWatch()
    .then(() => console.log("Initial wg0 check complete."))
    .catch((err) => console.error("Error in wg0 interface check:", err));
  // Set intervals to call refresh functions
  setInterval(async () => {
    await refreshTrayStatus();
  }, 4000);
  setInterval(async () => {
    await wgInterfaceWatch();
  }, 4000);
});

const createTray = () => {
  const iconPath = path.join(__dirname, "nexodus-logo-32x32.png");
  let image = nativeImage.createFromPath(iconPath);
  const platform = process.platform;
  let size = { width: 32, height: 32 };

  if (platform === "darwin") {
    size = { width: 20, height: 20 };
  } else if (platform === "win32") {
    size = { width: 20, height: 20 };
  } else if (platform === "linux") {
    size = { width: 22, height: 22 };
  }

  image = image.resize(size);

  if (image.isEmpty()) {
    console.error("The image data is empty");
    return;
  }

  tray = new Tray(image);
  const contextMenu = Menu.buildFromTemplate(menuItems);
  tray.setToolTip("Nexodus Agent");
  tray.setContextMenu(contextMenu);
  currentContextMenu = contextMenu; // Initialize the stored menu

  // Listen to tray icon clicks
  tray.on("click", (event, bounds) => {
    // Only for Windows
    if (process.platform === "win32") {
      const x = bounds.x - bounds.width / 2;
      const y = bounds.y;

      // Use the current context menu
      tray!.popUpContextMenu(currentContextMenu, {
        x: Math.round(x),
        y: Math.round(y),
      });
    } else {
      // Use the current context menu for other platforms
      tray!.popUpContextMenu(currentContextMenu);
    }
  });
};

app.on("window-all-closed", () => {
  if (process.platform !== "darwin") {
    app.quit();
  }
});

app.on("activate", () => {
  if (BrowserWindow.getAllWindows().length === 0) {
    createWindow();
  }
});

const createWindow = () => {
  const mainWindow = new BrowserWindow({
    width: 800,
    height: 600,
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
    },
  });

  if (MAIN_WINDOW_VITE_DEV_SERVER_URL) {
    mainWindow.loadURL(MAIN_WINDOW_VITE_DEV_SERVER_URL);
  } else {
    mainWindow.loadFile(
      path.join(__dirname, `../renderer/${MAIN_WINDOW_VITE_NAME}/index.html`),
    );
  }

  mainWindow.webContents.openDevTools();
};
