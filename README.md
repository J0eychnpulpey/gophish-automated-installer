# GoPhish Automated Installer Script version 2

This repository contains a Bash script that automates the deployment of a GoPhish phishing server, specifically tested and designed for an **Ubuntu 22.04 Droplet on DigitalOcean**. This project fulfills the "Automate With a Script" challenge from the SimplyCyber course.

## What the Script Does

The script automates the full deployment process on a DigitalOcean Droplet by performing the following actions:

-   **System Preparation**: Updates the server and installs necessary dependencies (`unzip`, `certbot`, `jq`).
-   **GoPhish Installation**: Downloads and extracts the official GoPhish binary.
-   **Guided DNS & SSL**: Provides clear, step-by-step instructions for the user to configure DNS and complete the Certbot challenge for a free SSL certificate.
-   **Automated Configuration**: Modifies the `config.json` file for secure HTTPS, remote admin access, and CSRF protection.
-   **Service Creation**: **Creates a `systemd` service to ensure GoPhish runs persistently and automatically starts on server reboot.**
-   **Launch**: Starts the GoPhish service and provides the user with the admin URL and temporary password.

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
4.  Run the script, providing your domain name as an argument. **Make sure you are inside the `gophish-automated-installer` directory when you run it.**
    ```bash
    ./install_gophish.sh your-domain.com
    ```
5.  Follow the on-screen prompts for DNS configuration.

Once the script completes, it will display the URL and credentials for your GoPhish admin portal.

## Post-Installation: Managing the Service

Your GoPhish instance is now running as a persistent system service. This means it will automatically start every time the server boots.

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
**Disclaimer**: This tool is for educational and authorized professional use only.
