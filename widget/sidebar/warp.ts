import { exec, Variable } from "astal";

let warpStatus = Variable(JSON.parse(exec("warp-cli -j status")).status);
let pollingInterval: any;

const checkWarpStatus = () => {
  const currentStatus = JSON.parse(exec("warp-cli -j status")).status;
  warpStatus.set(currentStatus);

  if (currentStatus === "Connected" || currentStatus === "Disconnected") {
    console.log(`Warp is now ${currentStatus.toLowerCase()}.`);
    clearInterval(pollingInterval); // Stop polling
  } else if (currentStatus === "Connecting") {
    console.log("Warp is currently connecting...");
  }
};

const warpToggle = () => {
  exec(
    `warp-cli ${warpStatus.get() === "Connected" ? "disconnect" : "connect"}`,
  );
  pollingInterval = setInterval(checkWarpStatus, 1000); // Check every 1 seconds
};

export { warpStatus, warpToggle };
