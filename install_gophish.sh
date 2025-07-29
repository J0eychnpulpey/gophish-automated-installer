#!/bin/bash

# A guided script to install and configure GoPhish on Ubuntu 22.04
# VERSION: Production-Ready - All-in-One
# This script sets up the GoPhish server and generates a client-side script
# for the persistent reverse SSH tunnel.

# --- Colors for better output ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# --- Script functions ---

# Function to print a step header
print_step() {
    echo -e "\n${BLUE}>>> $1${NC}"
}

# Function to get the domain name from the user
get_domain_name() {
    if [ -z "$1" ]; then
        echo -e "${YELLOW}Usage: ./install_gophish.sh yourdomain.com${NC}"
        exit 1
    fi
    DOMAIN=$1
    echo "Domain set to: $DOMAIN"
}

# Function to install dependencies
install_dependencies() {
    print_step "Step 1: Installing dependencies (unzip, certbot, jq)..."
    apt-get update -y > /dev/null
    apt-get install -y unzip certbot jq > /dev/null
    echo -e "${GREEN}Dependencies installed successfully.${NC}"
}

# Function to download and set up GoPhish
setup_gophish() {
    print_step "Step 2: Downloading and setting up GoPhish..."
    if [ -d "gophish" ]; then
        echo -e "${YELLOW}'gophish' directory already exists. Skipping download.${NC}"
        return
    fi
    GOPHISH_VERSION="v0.12.1"
    wget "https://github.com/gophish/gophish/releases/download/${GOPHISH_VERSION}/gophish-${GOPHISH_VERSION}-linux-64bit.zip" -O gophish.zip > /dev/null 2>&1
    unzip gophish.zip -d gophish > /dev/null
    rm gophish.zip
    chmod +x gophish/gophish
    echo -e "${GREEN}GoPhish downloaded and extracted.${NC}"
}

# Function for manual DNS A record setup
manual_a_record_setup() {
    print_step "Step 3: Manual DNS Configuration (A Record)"
    PUBLIC_IP=$(curl -s ifconfig.me)
  
    echo -e "${YELLOW}ACTION REQUIRED: You must now manually create a DNS 'A' Record.${NC}"
    echo "1. Log in to your Namecheap account."
    echo "2. Go to 'Domain List' -> 'Manage' -> 'Advanced DNS'."
    echo "3. Click 'ADD NEW RECORD' and create an 'A Record' with these values:"
    echo -e "   - Type:  ${GREEN}A Record${NC}"
    echo -e "   - Host:  ${GREEN}@${NC}"
    echo -e "   - Value: ${GREEN}${PUBLIC_IP}${NC}"
    echo -e "   - TTL:   ${GREEN}Automatic or 1 min${NC}"
  
    read -p $'\n\033[1;33mPress Enter here after you have created the A record and saved the changes...\033[0m'
  
    echo "Waiting 60 seconds for DNS to start propagating..."
    sleep 60
}

# Function to generate SSL certificate
generate_ssl() {
    print_step "Step 4: Generating SSL Certificate with Certbot"
  
    echo "------------------------------------------------------------------"
    echo -e "${YELLOW}ACTION REQUIRED: Certbot will now run and pause.${NC}"
    echo "It will ask you to create a DNS TXT record. Please follow these steps:"
    echo
    echo -e "1. Look at the Certbot output for the line that says: ${GREEN}_acme-challenge.your.domain.${NC}"
    echo -e "2. Look for the long random string of text under the line: ${GREEN}with the following value:${NC}"
    echo
    echo -e "3. In Namecheap's 'Advanced DNS', click ${GREEN}'ADD NEW RECORD'${NC}."
    echo -e "   - For 'Type', select: ${GREEN}TXT Record${NC}"
    echo -e "   - For 'Host', enter the part before your domain (e.g., ${GREEN}_acme-challenge${NC})"
    echo -e "   - For 'Value', copy and paste the long random string from Certbot."
    echo -e "   - For 'TTL', set to:  ${GREEN}1 minute${NC}"
    echo
    echo -e "4. After you have saved the record in Namecheap, wait a minute, then come back here and follow Certbot's final instruction to ${GREEN}Press Enter to Continue${NC}."
    echo "------------------------------------------------------------------"
  
    read -p $'\n\033[1;33mPress Enter to begin the Certbot process...\033[0m'
  
    certbot certonly --manual --preferred-challenges dns -d "$DOMAIN" --register-unsafely-without-email --agree-tos
  
    if [ ! -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
        echo -e "${YELLOW}Certbot failed or was cancelled. Cannot continue.${NC}"
        exit 1
    fi
    echo -e "${GREEN}SSL Certificate generated successfully!${NC}"
}

# Function to configure GoPhish's config.json
configure_gophish() {
    print_step "Step 5: Updating GoPhish config.json..."
    CERT_PATH="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"
    KEY_PATH="/etc/letsencrypt/live/$DOMAIN/privkey.pem"
    PUBLIC_IP=$(curl -s ifconfig.me)

    # Use jq to modify the JSON. This now includes the public IP in trusted_origins.
    jq \
      --arg ip "$PUBLIC_IP" \
      --arg cert_path "$CERT_PATH" \
      --arg key_path "$KEY_PATH" \
      '.admin_server.listen_url = "0.0.0.0:3333" |
       .admin_server.use_tls = false |
       .admin_server.trusted_origins = [$ip] |
       .phish_server.listen_url = "0.0.0.0:443" |
       .phish_server.use_tls = true |
       .phish_server.cert_path = $cert_path |
       .phish_server.key_path = $key_path' \
      gophish/config.json > gophish/config.tmp && mv gophish/config.tmp gophish/config.json
  
    echo -e "${GREEN}config.json has been updated for HTTPS and CSRF protection.${NC}"
}

# This function creates a systemd service to run GoPhish persistently.
create_gophish_service() {
    print_step "Step 6: Creating and starting GoPhish service..."

    # Get the absolute path of the directory where the script is running
    SCRIPT_DIR=$(pwd)
    
    # Create the systemd service file with the correct, absolute paths
    cat > /etc/systemd/system/gophish.service <<EOF
[Unit]
Description=GoPhish Phishing Framework
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=${SCRIPT_DIR}/gophish
ExecStart=${SCRIPT_DIR}/gophish/gophish
Restart=always
RestartSec=3
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd, enable and start the service
    systemctl daemon-reload
    systemctl enable gophish > /dev/null 2>&1
    systemctl start gophish

    echo "GoPhish service created and started. Waiting 15s to initialize..."
    sleep 15
    
    # Check the status to make sure it's running
    if ! systemctl is-active --quiet gophish; then
        echo -e "${YELLOW}GoPhish service failed to start. Please check status with 'journalctl -u gophish.service'${NC}"
        exit 1
    fi

    # Capture password from the system journal
    PASSWORD=$(journalctl -u gophish.service -n 20 --no-pager | grep "Please login with the username admin" | tail -n 1 | awk '{print $NF}')
    PUBLIC_IP=$(curl -s ifconfig.me)

    if [ -z "$PASSWORD" ]; then
        echo -e "${YELLOW}Could not capture password automatically. Please check logs with 'journalctl -u gophish.service'${NC}"
    else
        echo -e "\n${GREEN}--- GoPhish Server Deployed! ---${NC}"
        echo -e "Admin Portal URL: ${YELLOW}http://"$PUBLIC_IP":3333${NC}"
        echo -e "Phishing URL:     ${YELLOW}https://$DOMAIN${NC}"
        echo -e "Username:         ${YELLOW}admin${NC}"
        echo -e "Password:         ${GREEN}${PASSWORD}${NC}"
    fi
}

# This function generates the client-side script for the user.
generate_tunnel_script() {
    print_step "Step 7: Generate Client-Side Tunnel Script"
    PUBLIC_IP=$(curl -s ifconfig.me)
    echo -e "${YELLOW}ACTION REQUIRED: The final step is to set up the persistent email tunnel on your local Kali VM.${NC}"
    echo "------------------------------------------------------------------"
    echo -e "1.  On your Kali VM, set up passwordless SSH to this server by running:"
    echo -e "    ${GREEN}ssh-copy-id root@${PUBLIC_IP}${NC}"
    echo -e "    (You will need to enter your server's root password one last time)."
    echo
    echo -e "2.  After that is done, copy the ENTIRE script block below (from #!/bin/bash to the end)."
    echo -e "3.  Paste it into a new file on your Kali VM, for example: ${GREEN}nano setup_tunnel.sh${NC}"
    echo -e "4.  Make it executable: ${GREEN}chmod +x setup_tunnel.sh${NC}"
    echo -e "5.  Run it with sudo: ${GREEN}sudo ./setup_tunnel.sh${NC}"
    echo "------------------------------------------------------------------"
    echo
    # The generated script starts here
    # A temporary file is used to safely inject the server's IP
    
    TUNNEL_SCRIPT=$(cat <<'EOF'
#!/bin/bash
# This script creates a persistent reverse SSH tunnel as a systemd service.
# Run this on your local machine (e.g., Kali VM), NOT the GoPhish server.

REMOTE_USER="root"
REMOTE_HOST="YOUR_SERVER_IP_HERE" # This is a placeholder
LOCAL_PORT="2525"
REMOTE_SMTP="smtp-relay.gmail.com"
REMOTE_PORT="587"
SERVICE_NAME="gophish-tunnel"
SERVICE_FILE="/etc/systemd/system/${SERVICE_NAME}.service"

echo ">>> Creating systemd service for persistent SSH tunnel..."

# Create the systemd service file
# Note: Requires passwordless SSH key authentication to be set up.
sudo bash -c "cat > ${SERVICE_FILE}" <<EOT
[Unit]
Description=GoPhish Reverse SSH Tunnel Service
After=network-online.target
Wants=network-online.target

[Service]
User=$(whoami)
ExecStart=/usr/bin/ssh -N -R ${LOCAL_PORT}:${REMOTE_SMTP}:${REMOTE_PORT} ${REMOTE_USER}@${REMOTE_HOST} -o ServerAliveInterval=60 -o ExitOnForwardFailure=yes -o StrictHostKeyChecking=no
Restart=always
RestartSec=10

[Install]
WantedBy=default.target
EOT

echo ">>> Enabling and starting the tunnel service..."
sudo systemctl daemon-reload
sudo systemctl enable ${SERVICE_NAME} > /dev/null 2>&1
sudo systemctl start ${SERVICE_NAME}

echo ">>> Checking service status..."
sleep 3
sudo systemctl status ${SERVICE_NAME} --no-pager

echo -e "\n--- Persistent Tunnel Setup Complete! ---"
EOF
)

    # Replace the placeholder IP with the actual server IP and print the script
    echo "${TUNNEL_SCRIPT/YOUR_SERVER_IP_HERE/$PUBLIC_IP}"
}

# --- Main script execution ---
get_domain_name "$1"
install_dependencies
setup_gophish
manual_a_record_setup
generate_ssl
configure_gophish
create_gophish_service
generate_tunnel_script
