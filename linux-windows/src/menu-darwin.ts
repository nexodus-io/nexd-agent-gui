import sudo from "sudo-prompt";
import { updateContextMenu } from "./main";
import sharedState from "./shared-state";

export let globalAuthUrl: string | null = null;

// Function to start Nexodus Service
export const menuConnectClickDarwin = () => {
  console.log("Starting Nexodus Service...");
  const commands = [
    "brew services start nexodus-io/nexodus/nexodus",
    "sleep 5",
    "nexctl nexd status",
  ];
  const commandString = commands.join("; ");
  const options = {
    name: "Nexodus Service",
  };

  sudo.exec(commandString, options, (error, stdout, stderr) => {
    if (error) {
      console.error(`Error executing command: ${error}`);
      return;
    }

    const stdoutStr = stdout.toString();
    console.log(`stdout: ${stdoutStr}`);
    console.error(`stderr: ${stderr}`);

    const urlMatch = stdoutStr.match(/(https:\/\/[^\s]+)/);
    if (urlMatch && urlMatch[1]) {
      globalAuthUrl = urlMatch[1];
      // Update the shared state if a URL is found
      sharedState.setGlobalAuthUrl(globalAuthUrl);
      console.log(`Found Auth URL: ${globalAuthUrl}`);
      // Update the menu to add an open URL option
      updateContextMenu();
    } else {
      globalAuthUrl = null;
      sharedState.setGlobalAuthUrl(null);
      console.log("No Auth URL found.");
    }

    updateContextMenu();
  });
};

// Function to stop Nexodus Service
export const menuDisconnectClickDarwin = () => {
  console.log("Stopping Nexodus Service...");
  const commandString = "brew services stop nexodus-io/nexodus/nexodus";
  const options = {
    name: "Nexodus Service Stop",
  };

  sudo.exec(commandString, options, (error, stdout, stderr) => {
    if (error) {
      console.error(`Error executing command: ${error}`);
      return;
    }

    console.log(`stdout: ${stdout}`);
    console.error(`stderr: ${stderr}`);
    updateContextMenu();
  });
};
