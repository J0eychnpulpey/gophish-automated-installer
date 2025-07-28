# GoPhish Automated Installer Script

This repository contains a Bash script that automates the deployment of a GoPhish phishing server, specifically tested and designed for an **Ubuntu 22.04 Droplet on DigitalOcean**. This project fulfills the "Automate With a Script" challenge from the SimplyCyber Academy: [Tyler Ramsbey Hands On Phishing Course](https://academy.simplycyber.io/l/pdp/hands-on-phishing).

## What the Script Does

The script automates the full deployment process on a DigitalOcean Droplet by performing the following actions:

-   **System Preparation**: Updates the server and installs necessary dependencies (`unzip`, `certbot`, `jq`).
-   **GoPhish Installation**: Downloads and extracts the official GoPhish binary into a `gophish` directory.
-   **Guided DNS & SSL**: Provides clear, step-by-step instructions for the user to:
    1.  Create an `A` record in their DNS provider (e.g., Namecheap) to point the domain to the Droplet's IP address.
    2.  Create a `TXT` record to complete the Certbot DNS challenge for a free SSL certificate.
-   **Automated Configuration**: Modifies the `config.json` file to:
    -   Enable a secure HTTPS phishing server on port 443.
    -   Enable a remote-accessible HTTP admin portal on port 3333.
    -   Add the Droplet's IP to the `trusted_origins` list to prevent common CSRF errors.
-   **Launch**: Starts the GoPhish service in the background and provides the user with the admin URL and temporary password.

## How to Use It

### Prerequisites
1.  **A Server**: A fresh **Ubuntu 22.04 Droplet on DigitalOcean**.
2.  **Access**: Root access to the Droplet.
3.  **Domain Name**: A domain name registered with a DNS provider like Namecheap.
4.  **Firewall**: A **DigitalOcean Cloud Firewall** rule allowing traffic from your personal IP to all TCP ports on the Droplet.

### Installation Steps
1.  Connect to your Droplet as the `root` user.
2.  Clone this repository to your server:
    ```bash
    git clone https://github.com/J0eychnpulpey/gophish-automated-installer.git
    cd gophish-automated-installer
    ```
3.  Make the script executable:
    ```bash
    chmod +x install_gophish.sh
    ```
4.  Run the script, providing your domain name as an argument:
    ```bash
    ./install_gophish.sh your-domain.com
    ```
5.  Follow the on-screen prompts. The script will pause and tell you exactly what DNS records to create in your DNS provider's dashboard. After you create each record, press `Enter` in the terminal to continue.

Once the script completes, it will display the URL and credentials for your GoPhish admin portal.

## Post-Installation

Once the script is complete, your GoPhish instance will be running as a **persistent system service**. This means it will automatically start every time the server boots.

You can manage the GoPhish service using the standard `systemctl` commands:

-   **Check the status and see recent logs**:
    ```bash
    systemctl status gophish
    ```
-   **Stop the GoPhish service**:
    ```bash
    systemctl stop gophish
    ```
-   **Start the GoPhish service**:
    ```bash
    systemctl start gophish
    ```
-   **Restart the service after making changes**:
    ```bash
    systemctl restart gophish
    ```
-   **View all historical logs**:
    ```bash
    journalctl -u gophish.service
    ```



---

### Troubleshooting Common Issues
*(This section remains the same as before, as the solutions are platform-agnostic but are now framed within the context of a DigitalOcean environment.)*

#### 1. Problem: `bash: ./install_gophish.sh: Permission denied`

-   **Cause**: The script file does not have "execute" permissions.
-   **Solution**: Add the execute permission:
    ```bash
    chmod +x install_gophish.sh
    ```

#### 2. Problem: After login, the browser shows `Forbidden - CSRF token invalid`

-   **Cause**: A browser caching issue or a mismatch in the request origin.
-   **Solution**: The script includes a permanent fix for this. If it still occurs, do a "hard refresh" of your browser: `Ctrl + Shift + R` (Windows/Linux) or `Cmd + Shift + R` (Mac).

#### 3. Problem: Can't connect to the server at all (Connection Timed Out)

-   **Cause**: Your personal public IP address has changed, but your **DigitalOcean Cloud Firewall** still has the old IP address whitelisted.
-   **Solution**: Update the "Sources" field in your DigitalOcean Firewall's inbound rule with your current public IP address.

#### 4. Problem: Certbot doesn't ask me to create a TXT record

-   **Cause**: The server still has old certificate data in `/etc/letsencrypt`.
-   **Solution**: Perform a **Full Reset** to start completely fresh. This involves deleting the application files and the `/etc/letsencrypt` directory on your Droplet, and removing the DNS records from Namecheap. Then, re-run the script.

---
**Disclaimer**: This tool is for educational and authorized professional use only.
