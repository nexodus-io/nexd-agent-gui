import fs from 'fs';
import os from 'os';
import { shell } from 'electron';
import path from "path";
import {exec} from "child_process";

export const openLogs = async () => {
    // Generate a temporary log file path
    const logFilePath = path.join(os.tmpdir(), 'nexodus_logs.txt');

    exec('journalctl -u nexodus.service --no-pager', (err, stdout, stderr) => {
        if (err) {
            console.error('Error fetching logs:', err);
            fs.writeFileSync(logFilePath, `Error fetching logs: ${err}\n`);
        } else {
            console.log('Successfully fetched logs.');
            fs.writeFileSync(logFilePath, stdout);
        }

        // Open the log file in the default text editor
        shell.openPath(logFilePath).catch(err => {
            console.error('Failed to open log file:', err);
        });
    });
};
