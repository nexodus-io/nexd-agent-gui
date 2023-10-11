import { MenuItemConstructorOptions } from "electron";
import { exec } from "child_process";

export const checkWgInterfaceLinux =
  async (): Promise<MenuItemConstructorOptions> => {
    const redCircle = "\uD83D\uDD34";
    const greenCircle = "\ud83d\udfe2";

    return new Promise<MenuItemConstructorOptions>((resolve, reject) => {
      exec("systemctl status nexodus", (err, stdout) => {
        if (err || !stdout.includes("active (running)")) {
          resolve({
            label: `${redCircle}   Not Connected`,
            enabled: false,
          } as MenuItemConstructorOptions);
          return;
        }

        exec("ip link show wg0", (err, stdout) => {
          if (err || !stdout.includes("wg0")) {
            resolve({
              label: `${redCircle} Not Connected`,
              enabled: false,
            } as MenuItemConstructorOptions);
            return;
          }

          exec("ip address show wg0", (err, stdout) => {
            if (err) {
              resolve({
                label: `${greenCircle}   Connected\n    but IPs not found`,
                enabled: true,
              } as MenuItemConstructorOptions);
              return;
            }

            const ipv4Match = stdout.match(/inet (\d+\.\d+\.\d+\.\d+)/);
            const ipv6Match = stdout.match(/inet6 ([a-f0-9:]+)/);

            const ipv4 = ipv4Match ? ipv4Match[1] : "N/A";
            const ipv6 = ipv6Match ? ipv6Match[1] : "N/A";

            resolve({
              label: `${greenCircle} Connected\nIPv4: ${ipv4}\nIPv6: ${ipv6}`,
              enabled: true,
            } as MenuItemConstructorOptions);
          });
        });
      });
    });
  };
