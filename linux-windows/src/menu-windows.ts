import { app, dialog } from "electron";
import { exec, spawn } from "child_process";
import * as fs from "fs";
import * as path from "path";
import { updateContextMenu } from "./main";
import sharedState from "./shared-state";

// File path for log
const logFilePath = path.join("C:", "nexodus_logs.txt");

export async function menuConnectClickWin() {
  console.log("Connect Clicked");

  const nexdProcess = spawn("C:\\nexd.exe");

  nexdProcess.stdout.on("data", (data: Buffer) => {
    const infoLog = `[INFO] ${data.toString().trim()}`;
    fs.appendFileSync(logFilePath, infoLog + "\n");
  });

  nexdProcess.stderr.on("data", (data: Buffer) => {
    const errorLog = `[ERROR] ${data.toString().trim()}`;
    fs.appendFileSync(logFilePath, errorLog + "\n");
  });

  console.log("Connect Checking for AUTH");

  await checkForAuthURL();
}

// Implementing MenuDisconnect_Click
export function menuDisconnectClickWin() {
  clearLogFile();
  killProcesses();
  console.log("Disconnected Successfully");
  // Uncomment for a popup in windows
  // dialog.showMessageBox({message: 'Nexodus Disconnected Successfully.', type: 'info'});
}

// Implementing ClearLogFile
function clearLogFile() {
  if (fs.existsSync(logFilePath)) {
    fs.truncateSync(logFilePath, 0);
  }
}

async function checkForAuthURL() {
  let elapsedTime = 0;
  const maxWaitTime = 180;
  console.log("Checking logs for Auth URL");
  while (elapsedTime < maxWaitTime) {
    const url = getAuthUrlFromLogFile();
    if (url) {
      // Update the globalAuthUrl
      sharedState.setGlobalAuthUrl(url);

      // Update the tray icon menu
      updateContextMenu();

      dialog.showMessageBox({
        message: `Authentication URL Provided: ${url}`,
        type: "info",
      });
      return;
    }
    await new Promise((resolve) => setTimeout(resolve, 5000));
    elapsedTime += 5;
  }
}

function getAuthUrlFromLogFile(): string | null {
  if (fs.existsSync(logFilePath)) {
    const lines = fs.readFileSync(logFilePath, "utf-8").split("\n");
    for (const line of lines) {
      if (line.includes("https://auth")) {
        const startIndex = line.indexOf("https://auth");
        return line.substr(startIndex).trim();
      }
    }
  }
  return null;
}

function killProcesses() {
  const processesToKill = ["nexd", "wireguard"];
  for (const processName of processesToKill) {
    exec(`taskkill /IM ${processName}.exe /F`, (error, stdout, stderr) => {
      if (error) {
        // If the process is not running, just log the error to console
        console.log({
          message: `Warning stopping ${processName}: ${error.message}`,
          type: "error",
        });
      }
    });
  }
}
