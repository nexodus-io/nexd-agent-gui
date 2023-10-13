import { MenuItemConstructorOptions } from "electron";
import { exec } from "child_process";

export const checkWgInterfaceWin =
  async (): Promise<MenuItemConstructorOptions> => {
    const redCircle = "\uD83D\uDD34";
    const greenCircle = "\ud83d\udfe2";

    return new Promise<MenuItemConstructorOptions>((resolve, reject) => {
      exec('netsh interface ip show config "wg0"', (err, stdout) => {
        if (err || !stdout.includes("IP Address:")) {
          resolve({
            label: `${redCircle} Not Connected`,
            enabled: false,
          });
          return;
        }

        const ipPart = stdout
          .split("\n")
          .find((line) => line.trim().startsWith("IP Address:"));
        const ip = ipPart?.split(":")[1].trim();
        resolve({
          label: `${greenCircle} Connected\nIPv4: ${ip}`,
          enabled: true,
        });
      });
    });
  };
