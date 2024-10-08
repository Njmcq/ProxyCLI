# ProxyCLI

## Overview

**ProxyCLI** is a shell script designed to easily manage proxy configurations on Ubuntu and Debian-based Linux distributions. This utility allows users to easily manage the network's proxy settings, including checking the current status, enabling/disabling the proxy, managing these settings with a timed delay, and saving frequently-used proxy configurations.

## Features

- **Check Proxy Status:** Determine if the proxy is currently active or inactive.
- **Add Proxy Settings:** Enable the proxy with the correct server and port.
- **Remove Proxy Settings:** Disable the proxy by removing the relevant settings from the system.
- **Timer-Controlled Proxy Management:** Temporarily disable the proxy for a specified duration, with automatic reactivation once the timer expires.
- **Save and Load Proxy Configurations:** Users who frequently require a certain proxy configuration can easily save a proxy to a dedicated JSON file, and load them straight into ProxyCLI without having to manually enter the configuration.

## Usage

### Running the Script

To use the script, simply run it in your terminal:

```bash
./ProxyCLI.sh
```

You will be presented with a menu where you can choose from the following options:

1. **Check proxy status:** Displays whether the proxy is active and shows the server and port information.
2. **Add proxy settings:** Asks the user to input a proxy server address and port number, and then activates it.
3. **Remove proxy settings:** Deactivates the proxy by removing the settings from your system.
4. **Start timer to disable proxy:** Temporarily disables the proxy for a specified number of seconds and then re-enables it.
5. **Save current proxy:** Save the active proxy to a JSON file in the current directory.
6. **Load saved proxy:** Select a proxy to load and apply from a pre-existing JSON file of saved proxy configurations.
7. **Delete saved proxy:** Delete a proxy configuration from a pre-existing JSON file of saved proxy configurations.
8. **Exit:** Closes the script.

### Timer Behaviour

Before starting the timer, the script checks if the proxy is already inactive. If it is, the user is warned that the timer will re-enable the proxy once it concludes. This ensures that the proxy is only disabled and re-enabled when necessary.

### Requirements

- The script is specifically configured for use with HTTP and HTTPS proxy configurations.
- The script must be run with `sudo` privileges to modify system-wide proxy settings, including **_apt_** and **_environment_**.
- `jq` is required to load saved proxies.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
