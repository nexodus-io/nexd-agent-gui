using System;
using System.Diagnostics;
using System.IO;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Controls;

namespace nexodus_windows_agent_ui
{
    public partial class MainWindow : Window
    {
        private System.Windows.Controls.ContextMenu trayMenu;
        private System.Windows.Forms.ToolStripMenuItem copyAuthURLItem;

        public MainWindow()
        {
            InitializeComponent();

            // Clear the log file on startup
            ClearLogFile();

            // Prepare tray menu
            trayMenu = new System.Windows.Controls.ContextMenu();

            MenuItem connectItem = new MenuItem { Header = "Connect Nexodus" };
            connectItem.Click += MenuConnect_Click;
            trayMenu.Items.Add(connectItem);

            MenuItem disconnectItem = new MenuItem { Header = "Disconnect Nexodus" };
            disconnectItem.Click += MenuDisconnect_Click;
            trayMenu.Items.Add(disconnectItem);

            MenuItem exitItem = new MenuItem { Header = "Exit" };
            exitItem.Click += MenuExit_Click;
            trayMenu.Items.Add(exitItem);

            // Setup the tray icon
            System.Windows.Forms.NotifyIcon trayIcon = new System.Windows.Forms.NotifyIcon
            {
                Text = "Nexodus Windows Agent",
                Icon = new System.Drawing.Icon("nexodus-icon.ico"),
                Visible = true
            };

            trayIcon.ContextMenuStrip = new System.Windows.Forms.ContextMenuStrip();
            trayIcon.ContextMenuStrip.Items.Add("Connect Nexodus", null, (sender, args) => MenuConnect_Click(sender, args));
            trayIcon.ContextMenuStrip.Items.Add("Disconnect Nexodus", null, (sender, args) => MenuDisconnect_Click(sender, args));

            // Declare and add the "Settings" menu item
            System.Windows.Forms.ToolStripMenuItem settingsItem = new System.Windows.Forms.ToolStripMenuItem("Settings");
            settingsItem.Click += SettingsItem_Click;
            trayIcon.ContextMenuStrip.Items.Add(settingsItem);
            trayIcon.ContextMenuStrip.Items.Insert(trayIcon.ContextMenuStrip.Items.Count - 1, settingsItem);

            // Add "Copy Auth URL" menu item.
            copyAuthURLItem = new System.Windows.Forms.ToolStripMenuItem("Copy Auth URL", null, (sender, args) => CopyAuthURLToClipboard());
            trayIcon.ContextMenuStrip.Items.Add(copyAuthURLItem);

            trayIcon.ContextMenuStrip.Items.Add("Exit", null, (sender, args) => MenuExit_Click(sender, args));

            // Check the visibility of the "Copy Auth URL" menu item before displaying the menu.
            trayIcon.ContextMenuStrip.Opening += (sender, args) =>
            {
                string url = GetAuthUrlFromLogFile();
                copyAuthURLItem.Visible = url != null;
            };

            System.Timers.Timer timer = new System.Timers.Timer(10 * 1000);  // 10 seconds interval
            timer.Elapsed += async (sender, e) => await CheckAndUpdateIPAddressAsync(trayIcon);
            timer.Start();

            this.Closing += (sender, args) => { trayIcon.Dispose(); };
            System.Windows.Application.Current.Exit += Current_Exit;
        }

        private void CopyAuthURLToClipboard()
        {
            string url = GetAuthUrlFromLogFile();
            if (url != null)
            {
                System.Windows.Clipboard.SetText(url);
                System.Windows.MessageBox.Show("Auth URL copied to clipboard.", "Success", MessageBoxButton.OK, MessageBoxImage.Information);
            }
            else
            {
                System.Windows.MessageBox.Show("Could not find Auth URL.", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
            }
        }

        private async void MenuConnect_Click(object sender, EventArgs e)
        {
            Process process = new Process();
            process.StartInfo.FileName = @"C:\nexd.exe";
            process.StartInfo.UseShellExecute = false;
            process.StartInfo.RedirectStandardOutput = true;
            process.StartInfo.RedirectStandardError = true;
            process.StartInfo.CreateNoWindow = true;

            process.OutputDataReceived += (s, eventData) =>
            {
                if (!String.IsNullOrEmpty(eventData.Data))
                {
                    // Append new log to the file.
                    File.AppendAllText(@"C:\nexd_output.txt", "[INFO] " + eventData.Data + Environment.NewLine);
                }
            };

            process.ErrorDataReceived += (s, eventData) =>
            {
                if (!String.IsNullOrEmpty(eventData.Data))
                {
                    // Append new log to the file.
                    File.AppendAllText(@"C:\nexd_output.txt", "[ERROR] " + eventData.Data + Environment.NewLine);
                }
            };

            process.Start();
            process.BeginOutputReadLine();
            process.BeginErrorReadLine();

            // Check for Auth URL periodically.
            await CheckForAuthURL();

            // If you need to wait for the process to finish, uncomment the line below, TBD.
            // await Task.Run(() => process.WaitForExit());
        }

        private void ClearLogFile()
        {
            string logFilePath = @"C:\nexd_output.txt";
            if (File.Exists(logFilePath))
            {
                // Clears the file content by setting its length to 0
                using FileStream stream = new FileStream(logFilePath, FileMode.Truncate);
                stream.SetLength(0);
            }
        }

        private async Task CheckForAuthURL()
        {
            // Set the maximum wait time to 3 minutes (180 seconds).
            const int maxWaitTime = 180;
            int elapsedTime = 0;

            // Continue checking for the URL until either it's found or the max wait time is exceeded.
            while (elapsedTime < maxWaitTime)
            {
                string url = GetAuthUrlFromLogFile();
                if (url != null)
                {
                    // Use the auth URL as necessary.
                    // Maybe pop it up in a message box for the user or open it in the default browser.
                    System.Windows.MessageBox.Show($"Authentication URL Provided: {url}", "Authentication Required", MessageBoxButton.OK, MessageBoxImage.Information);
                    return; // Exit the loop and function.
                }

                // If URL not found, wait for 5 seconds before checking again.
                await Task.Delay(TimeSpan.FromSeconds(5));
                elapsedTime += 5;
            }

            // Optional for Debugging: Notify the user that the authentication URL could not be found after waiting for 3 minutes.
            // System.Windows.MessageBox.Show("Could not find the authentication URL after waiting for 3 minutes.", "URL Not Found", MessageBoxButton.OK, MessageBoxImage.Warning);
        }

        private string GetAuthUrlFromLogFile()
        {
            string logFilePath = @"C:\nexd_output.txt";

            // If the file doesn't exist, create it and return null.
            if (!File.Exists(logFilePath))
            {
                File.Create(logFilePath).Close();  // Close method ensures that the file handle is released immediately.
                return null;
            }

            string[] lines = File.ReadAllLines(logFilePath);
            foreach (string line in lines)
            {
                if (line.Contains("https://auth"))
                {
                    // Extract the URL from the line.
                    int startIndex = line.IndexOf("https://auth");
                    string url = line.Substring(startIndex).Trim();
                    return url;
                }
            }
            return null;
        }


        private string ExtractAuthUrl(string logEntry)
        {
            // Split the string at the "sign in:" and take the second part.
            string[] parts = logEntry.Split(new string[] { "sign in:" }, StringSplitOptions.RemoveEmptyEntries);
            if (parts.Length > 1)
            {
                return parts[1].Trim();
            }
            return null;
        }

        private void SettingsItem_Click(object sender, EventArgs e)
        {
            // For now, just showing a message. You can open a settings window or another form here.
            System.Windows.MessageBox.Show("Settings clicked (not implemented)", "Information", MessageBoxButton.OK, MessageBoxImage.Information);
        }

        private void KillProcesses()
        {
            // List of process names to kill
            string[] processesToKill = { "nexd", "wireguard" };

            foreach (string processName in processesToKill)
            {
                Process[] processes = Process.GetProcessesByName(processName);
                foreach (Process process in processes)
                {
                    try
                    {
                        process.Kill();
                        process.WaitForExit(); // Optionally wait for the process to end
                    }
                    catch (Exception ex)
                    {
                        // Handle any errors that might occur during the killing process
                        System.Windows.MessageBox.Show($"Error stopping {processName}: {ex.Message}", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
                    }
                }
            }
        }

        private void MenuDisconnect_Click(object sender, EventArgs e)
        {
            // Clear the log file on disconnect
            ClearLogFile();

            // Kill processes on disconnect
            KillProcesses();
            System.Windows.MessageBox.Show("Nexodus Disconnected Successfully.", "Success", MessageBoxButton.OK, MessageBoxImage.Information);
        }

        private void MenuExit_Click(object sender, EventArgs e)
        {
            KillProcesses();  // Kill processes before exiting
            System.Windows.Application.Current.Shutdown();
        }

        private void Current_Exit(object sender, ExitEventArgs e)
        {
            KillProcesses();
        }

        private string GetIPAddressForWg0()
        {
            ProcessStartInfo psi = new ProcessStartInfo
            {
                FileName = "netsh",
                Arguments = "interface ip show config \"wg0\"",
                RedirectStandardOutput = true,
                UseShellExecute = false,
                CreateNoWindow = true
            };

            using (Process proc = Process.Start(psi))
            {
                string output = proc.StandardOutput.ReadToEnd();

                string[] lines = output.Split(new[] { Environment.NewLine }, StringSplitOptions.None);

                foreach (string line in lines)
                {
                    if (line.Trim().StartsWith("IP Address:"))
                    {
                        string ipPart = line.Split(new[] { ":" }, StringSplitOptions.RemoveEmptyEntries)[1];
                        return ipPart.Trim();
                    }
                }
            }

            return null;
        }

        private void UpdateMenuWithIPAddress(string ip, System.Windows.Forms.NotifyIcon trayIcon)
        {
            // Find and remove any previous IP address menu item
            for (int i = trayIcon.ContextMenuStrip.Items.Count - 1; i >= 0; i--)
            {
                if (trayIcon.ContextMenuStrip.Items[i].Text.StartsWith("IPv4:"))
                {
                    trayIcon.ContextMenuStrip.Items.RemoveAt(i);
                }
            }

            // If a valid IP address is provided, add it to the context menu
            if (!string.IsNullOrEmpty(ip))
            {
                // Insert the new IP address menu item at the desired position
                var ipMenuItem = new System.Windows.Forms.ToolStripMenuItem($"IPv4: {ip}") { Enabled = false };
                trayIcon.ContextMenuStrip.Items.Insert(3, ipMenuItem); // Inserting at index 3, change if needed
            }
        }

        private async Task CheckAndUpdateIPAddressAsync(System.Windows.Forms.NotifyIcon trayIcon)
        {
            await Task.Run(() =>
            {
                string ip = GetIPAddressForWg0();
                // Always invoke the UpdateMenuWithIPAddress, even if IP is null or empty
                Dispatcher.Invoke(() => UpdateMenuWithIPAddress(ip, trayIcon));
            });
        }
    }
}
