# GoPhish Automated Installer Script version 3

This repository contains a Bash script that automates the deployment of a GoPhish phishing server, specifically tested and designed for an **Ubuntu 22.04 Droplet on DigitalOcean**. This project fulfills the "Automate With a Script" challenge from the SimplyCyber Academy.

The script uses an "all-in-one" approach: you run a single script on the server, which then generates a second script needed for your local client machine to create a persistent email relay tunnel.

## What the Script Does

The script automates all **server-side** tasks and provides clear guidance for necessary manual steps.

-   **System Preparation**: Updates the server and installs dependencies (`unzip`, `certbot`, `jq`).
-   **GoPhish Installation**: Downloads and extracts the official GoPhish binary.
-   **Guided DNS & SSL**: Pauses and provides explicit instructions for creating `A` and `TXT` records in your DNS provider to obtain a valid SSL certificate.
-   **Automated Configuration**: Modifies the `config.json` file for secure HTTPS, remote admin access, and CSRF protection.
-   **Persistent Service Creation**: Automatically creates a `systemd` service to ensure GoPhish runs persistently and starts on server reboot.
-   **Client Script Generation**: At the end of the process, it generates a new script for you to run on your local machine (e.g., Kali VM) to create a persistent reverse SSH tunnel.

---

## Part 1: Manual Pre-Setup (Google Workspace)

**ACTION REQUIRED**: Before running the installer script, you must manually configure a Google account to handle email sending.

### A. Configure Your Google Account for SMTP Relay

1.  **Enable 2-Factor Authentication (2FA)**
    This is **mandatory** before you can create an App Password.
    - Go to your Google Account: [myaccount.google.com](https://myaccount.google.com/)
    - Navigate to the **Security** tab.
    - In the "How you sign in to Google" section, click on **2-Step Verification** and follow the steps to enable it.

2.  **Generate an App Password**
    This is a special 16-character password for GoPhish to use.
    - On the same **Security** page, click on **App passwords**.
    - For "Select app," choose **Mail**. For "Select device," choose **Other (Custom name)**.
    - Give it a name like `GoPhish Server` and click **Generate**.
    - **IMPORTANT**: Copy the 16-character password shown in the yellow box and save it securely. You will need this later.

3.  **Configure SMTP Relay Service (for Google Workspace)**
    This tells Google to trust emails coming from your local machine.
    - Go to the Google Workspace Admin Console: [admin.google.com](https://admin.google.com/)
    - Search for `SMTP relay` and select the **SMTP relay service**.
    - Click **Configure**.
    - **Authentication**: Check "Only accept mail from the specified IP addresses". Click **Add IP Range** and enter the **public IP address of your Kali VM / local machine** (the one that will run the tunnel). Find it by running `curl ifconfig.me` on that machine.
    - **Encryption**: Check "Require TLS encryption".
    - Click **Save**.

---

## Part 2: Automated Deployment Workflow

### Prerequisites
- You have completed all steps in **Part 1**.
- A fresh **Ubuntu 22.04 Droplet on DigitalOcean**.
- Root access to the Droplet.
- A **DigitalOcean Cloud Firewall** rule allowing traffic from your personal IP to all TCP ports.

### Installation Steps

1.  **Run the Server Script**:
    -   Connect to your Droplet as the `root` user.
    -   Clone this repository and `cd` into the directory:
        ```bash
        git clone https://github.com/J0eychnpulpey/gophish-automated-installer.git
        cd gophish-automated-installer
        ```
    -   Make the script executable: `chmod +x install_gophish.sh`
    -   Run the script with your domain: `./install_gophish.sh your-domain.com`
    -   Follow the on-screen prompts for the manual DNS configuration in Namecheap.

2.  **Run the Client Tunnel Script**:
    -   At the end, the server script will generate a new script.
    -   Follow the instructions carefully:
        a. On your **local Kali VM**, set up passwordless SSH to your Droplet: `ssh-copy-id root@your_droplet_ip`.
        b. Copy the entire generated script block.
        c. Paste it into a new file on your **Kali VM** (e.g., `nano setup_tunnel.sh`).
        d. Make it executable (`chmod +x setup_tunnel.sh`) and run it (`sudo ./setup_tunnel.sh`).

## Post-Installation: Managing Services

Once the full process is complete, you will have two persistent services running:

1.  **GoPhish (on the DigitalOcean Droplet)**:
    -   Check Status: `systemctl status gophish`
    -   Stop: `systemctl stop gophish`
    -   Start: `systemctl start gophish`

2.  **The SSH Tunnel (on your local Kali VM)**:
    -   Check Status: `sudo systemctl status gophish-tunnel`
    -   Stop: `sudo systemctl stop gophish-tunnel`
    -   Start: `sudo systemctl start gophish-tunnel`

---
**Disclaimer**: This tool is for educational and authorized professional use only.
