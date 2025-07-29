#!/bin/bash

# A guided script to install and configure GoPhish on Ubuntu 22.04

# --- Colors for better output ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# --- Script functions ---
# (Functions 1-5 remain unchanged)
print_step() { echo -e "\n${BLUE}>>> $1${NC}"; }
get_domain_name() { if [ -z "$1" ]; then echo -e "${YELLOW}Usage: ./install_gophish.sh yourdomain.com${NC}"; exit 1; fi; DOMAIN=$1; echo "Domain set to: $DOMAIN"; }
install_dependencies() { print_step "Step 1: Installing dependencies..."; apt-get update -y > /dev/null; apt-get install -y unzip certbot jq > /dev/null; echo -e "${GREEN}Dependencies installed.${NC}"; }
setup_gophish() { print_step "Step 2: Setting up GoPhish..."; if [ -d "gophish" ]; then echo -e "${YELLOW}'gophish' exists. Skipping.${NC}"; return; fi; GOPHISH_VERSION="v0.12.1"; wget "https://github.com/gophish/gophish/releases/download/${GOPHISH_VERSION}/gophish-${GOPHISH_VERSION}-linux-64bit.zip" -O gophish.zip > /dev/null 2>&1; unzip gophish.zip -d gophish > /dev/null; rm gophish.zip; chmod +x gophish/gophish; echo -e "${GREEN}GoPhish downloaded.${NC}"; }
manual_a_record_setup() { print_step "Step 3: Manual DNS (A Record)"; PUBLIC_IP=$(curl -s ifconfig.me); echo -e "${YELLOW}ACTION REQUIRED: Create a DNS 'A' Record.${NC}"; echo "1. In Namecheap, go to 'Advanced DNS'."; echo "2. Create an 'A Record' with:"; echo -e "   - Host: ${GREEN}@${NC}"; echo -e "   - Value: ${GREEN}${PUBLIC_IP}${NC}"; read -p $'\n\033[1;33mPress Enter after creating the record...\033[0m'; echo "Waiting 60s for DNS..."; sleep 60; }
generate_ssl() { print_step "Step 4: Generating SSL Certificate"; echo "------------------------------------------------------------------"; echo -e "${YELLOW}ACTION REQUIRED: Certbot will now run.${NC}"; echo "It will ask you to create a DNS TXT record. Follow its instructions."; echo "------------------------------------------------------------------"; read -p $'\n\033[1;33mPress Enter to begin Certbot...\033[0m'; certbot certonly --manual --preferred-challenges dns -d "$DOMAIN" --register-unsafely-without-email --agree-tos; if [ ! -f "/etc/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then echo -e "${YELLOW}Certbot failed. Cannot continue.${NC}"; exit 1; fi; echo -e "${GREEN}SSL Certificate generated.${NC}"; }
configure_gophish() { print_step "Step 5: Updating GoPhish config..."; CERT_PATH="/etc/letsencrypt/live/$DOMAIN/fullchain.pem"; KEY_PATH="/etc/letsencrypt/live/$DOMAIN/privkey.pem"; PUBLIC_IP=$(curl -s ifconfig.me); jq --arg ip "$PUBLIC_IP" --arg cert_path "$CERT_PATH" --arg key_path "$KEY_PATH" '.admin_server.listen_url = "0.0.0.0:3333" | .admin_server.use_tls = false | .admin_server.trusted_origins = [$ip] | .phish_server.listen_url = "0.0.0.0:443" | .phish_server.use_tls = true | .phish_server.cert_path = $cert_path | .phish_server.key_path = $key_path' gophish/config.json > gophish/config.tmp && mv gophish/config.tmp gophish/config.json; echo -e "${GREEN}config.json updated.${NC}"; }
create_gophish_service() { print_step "Step 6: Creating GoPhish service..."; SCRIPT_DIR=$(pwd); cat > /etc/systemd/system/gophish.service <<EOF
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
systemctl daemon-reload; systemctl enable gophish > /dev/null 2>&1; systemctl start gophish; echo "GoPhish service created. Waiting 15s..."; sleep 15; if ! systemctl is-active --quiet gophish; then echo -e "${YELLOW}GoPhish service failed. Check 'journalctl -u gophish.service'${NC}"; exit 1; fi; PASSWORD=$(journalctl -u gophish.service -n 20 --no-pager | grep "Please login" | tail -n 1 | awk '{print $NF}'); PUBLIC_IP=$(curl -s ifconfig.me); if [ -z "$PASSWORD" ]; then echo -e "${YELLOW}Could not capture password. Check logs.${NC}"; else echo -e "\n${GREEN}--- GoPhish Server Deployed! ---${NC}"; echo -e "Admin URL: ${YELLOW}http://"$PUBLIC_IP":3333${NC}"; echo -e "Username:  ${YELLOW}admin${NC}"; echo -e "Password:  ${GREEN}${PASSWORD}${NC}"; fi; }

# ---- FINAL, BUG-FIXED FUNCTION ----
# This function generates the client-side script with a reliable method for creating the service file.
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
    
    # Generate the client-side script. Using printf is more robust than nested heredocs.
    TUNNEL_SCRIPT_CONTENT=$(cat <<EOF
#!/bin/bash
# This script creates a persistent reverse SSH tunnel as a systemd service.
# Run this on your local machine (e.g., Kali VM), NOT the GoPhish server.

REMOTE_USER="root"
REMOTE_HOST="${PUBLIC_IP}"
LOCAL_PORT="2525"
REMOTE_SMTP="smtp-relay.gmail.com"
REMOTE_PORT="587"
SERVICE_NAME="gophish-tunnel"
SERVICE_FILE="/etc/systemd/system/\${SERVICE_NAME}.service"

echo ">>> Creating systemd service file for persistent SSH tunnel..."

# Using printf to create the service file robustly
sudo printf '%s\n' \
    '[Unit]' \
    'Description=GoPhish Reverse SSH Tunnel Service' \
    'After=network-online.target' \
    'Wants=network-online.target' \
    '' \
    '[Service]' \
    "User=\$(whoami)" \
    "ExecStart=/usr/bin/ssh -N -R \${LOCAL_PORT}:\${REMOTE_SMTP}:\${REMOTE_PORT} \${REMOTE_USER}@\${REMOTE_HOST} -o ServerAliveInterval=60 -o ExitOnForwardFailure=yes -o StrictHostKeyChecking=no" \
    'Restart=always' \
    'RestartSec=10' \
    '' \
    '[Install]' \
    'WantedBy=default.target' \
    > "\${SERVICE_FILE}"

echo ">>> Enabling and starting the tunnel service..."
sudo systemctl daemon-reload
sudo systemctl enable "\${SERVICE_NAME}" > /dev/null 2>&1
sudo systemctl start "\${SERVICE_NAME}"

echo ">>> Checking service status..."
sleep 3
sudo systemctl status "\${SERVICE_NAME}" --no-pager

echo -e "\n--- Persistent Tunnel Setup Complete! ---"
EOF
)
    echo "$TUNNEL_SCRIPT_CONTENT"
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
