import { MenuItemConstructorOptions } from "electron";
import { exec } from "child_process";

export const checkWgInterfaceDarwin =
  async (): Promise<MenuItemConstructorOptions> => {
    const redCircle = "\uD83D\uDD34";
    const greenCircle = "\ud83d\udfe2";

    console.log("Checking wg interface for macOS...");

    return new Promise<MenuItemConstructorOptions>((resolve, reject) => {
      exec('ifconfig utun8 | grep "inet "', (err, stdout) => {
        if (err || !stdout.includes("inet ")) {
          console.log("Not connected to utun8.");
          resolve({
            label: `${redCircle} Not Connected`,
            enabled: false,
          });
          return;
        }

        const ipPart = stdout.trim().split(" ")[1];
        console.log(`Connected to utun8. IP Address: ${ipPart}`);

        resolve({
          label: `${greenCircle} Connected\nIPv4: ${ipPart}`,
          enabled: true,
        });
      });
    });
  };
