import fs from "fs";
import os from "os";
import { shell } from "electron";
import path from "path";
import { exec } from "child_process";

export const openLogs = async () => {
  // Generate a temporary log file path for both OS
  const tempLogFilePath = path.join(os.tmpdir(), "nexodus_logs.txt");

  // Determine the operating system
  const currentOS = os.platform();

  if (currentOS === "win32") {
    // Set the path for the Windows log file
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

        // Open the log file in the default text editor
        shell.openPath(tempLogFilePath).catch((err) => {
          console.error("Failed to open log file:", err);
        });
      });
  } else {
    // Assume Linux OS
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

        // Open the log file in the default text editor
        shell.openPath(tempLogFilePath).catch((err) => {
          console.error("Failed to open log file:", err);
        });
      },
    );
  }
};
