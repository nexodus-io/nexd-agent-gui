import { MenuItemConstructorOptions, nativeImage } from 'electron';
import { exec } from 'child_process';
import path from 'path';



export const checkWg0Interface = async (): Promise<MenuItemConstructorOptions> => {
    const redCircle = "\uD83D\uDD34";
    const greenCircle = "\ud83d\udfe2";

    return new Promise((resolve) => {
        exec('systemctl status nexodus', (err, stdout) => {
            if (err || !stdout.includes('active (running)')) {
                console.log('Nexodus service is not running');
                resolve({
                    label: `${redCircle}   Not Connected`,
                    enabled: false,
                });
                return;
            }

            exec('ip link show wg0', (err, stdout) => {
                if (err || !stdout.includes('wg0')) {
                    console.log('Error checking wg0 interface:');
                    resolve({
                        label: `${redCircle} Not Connected`,
                        enabled: false,
                    });
                    return;
                }

                exec('ip address show wg0', (err, stdout) => {
                    if (err) {
                        console.log('Error fetching IPs:');
                        resolve({
                            label: `${greenCircle}   Connected\n    but IPs not found`,
                            enabled: true,
                        });
                        return;
                    }

                    const ipv4Match = stdout.match(/inet (\d+\.\d+\.\d+\.\d+)/);
                    const ipv6Match = stdout.match(/inet6 ([a-f0-9:]+)/);

                    const ipv4 = ipv4Match ? ipv4Match[1] : 'N/A';
                    const ipv6 = ipv6Match ? ipv6Match[1] : 'N/A';

                    resolve({
                        label: `${greenCircle} Connected\nIPv4: ${ipv4}\nIPv6: ${ipv6}`,
                        enabled: true,
                    });
                });
            });
        });
    });
};
