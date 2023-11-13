import fs from "fs";
import os from "os";
import { shell } from "electron";
import path from "path";
import { exec } from "child_process";

export const openLogs = async () => {
  // Generate a temporary log file path for both OS
  const tempLogFilePath = path.join(os.tmpdir(), "nexodus_logs.txt");

  const currentOS = os.platform();

  if (currentOS === "win32") {
    const winLogFilePath = "C:\\nexodus_logs.txt";
    // Read from the Windows log file and write it to the temp log file
    fs.promises
      .readFile(winLogFilePath, "utf8")
      .then((data) => {
        console.log("Successfully fetched logs.");
        fs.writeFileSync(tempLogFilePath, data);
        // Open the log file in the default text editor
        shell.openPath(tempLogFilePath).catch((err) => {
          console.error("Failed to open log file:", err);
        });
      })
      .catch((err) => {
        console.error("Error fetching logs:", err);
        fs.writeFileSync(tempLogFilePath, `Error fetching logs: ${err}\n`);
        shell.openPath(tempLogFilePath).catch((err) => {
          console.error("Failed to open log file:", err);
        });
      });
  } else if (currentOS === "darwin") {
    // Darwin-specific log file paths
    const darwinStdoutLogPath = "/opt/homebrew/var/log/nexd-stdout.log";
    const darwinStderrLogPath = "/opt/homebrew/var/log/nexd-stderr.log";
    // Read from the Darwin log files and write it to the temp log file
    Promise.all([
      fs.promises.readFile(darwinStdoutLogPath, "utf8"),
      fs.promises.readFile(darwinStderrLogPath, "utf8"),
    ])
      .then(([stdoutData, stderrData]) => {
        console.log("Successfully fetched logs.");
        const combinedLogs = `STDOUT:\n${stdoutData}\n\nSTDERR:\n${stderrData}`;
        fs.writeFileSync(tempLogFilePath, combinedLogs);

        // Open the log file in the default text editor
        shell.openPath(tempLogFilePath).catch((err) => {
          console.error("Failed to open log file:", err);
        });
      })
      .catch((err) => {
        console.error("Error fetching logs:", err);
        fs.writeFileSync(tempLogFilePath, `Error fetching logs: ${err}\n`);
        shell.openPath(tempLogFilePath).catch((err) => {
          console.error("Failed to open log file:", err);
        });
      });
  } else {
    // Cap the lines to avoid max buffer on stdout
    exec(
      "journalctl -u nexodus.service --no-pager -n 1000",
      (err, stdout, stderr) => {
        if (err) {
          console.error("Error fetching logs:", err);
          fs.writeFileSync(tempLogFilePath, `Error fetching logs: ${err}\n`);
        } else {
          console.log("Successfully fetched logs.");
          fs.writeFileSync(tempLogFilePath, stdout);
        }
        shell.openPath(tempLogFilePath).catch((err) => {
          console.error("Failed to open log file:", err);
        });
      },
    );
  }
};
