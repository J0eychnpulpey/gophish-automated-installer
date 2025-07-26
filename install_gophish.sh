#!/bin/bash

# A guided script to install and configure GoPhish on Ubuntu 22.04
# MODIFIED: This version is designed to be run directly by the 'root' user.


# --- Colors for better outpt --- 
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

# Function to launch GoPhish and get credentials
launch_and_report() {
    print_step "Step 6: Launching GoPhish and capturing credentials..."
    cd gophish
    nohup ./gophish > ../gophish_output.log 2>&1 &
  
    echo "GoPhish is starting. Waiting 15 seconds to capture the temporary password..."
    sleep 15
  
    PASSWORD=$(grep "Please login with the username admin" ../gophish_output.log | awk '{print $NF}')
    PUBLIC_IP=$(curl -s ifconfig.me)

    if [ -z "$PASSWORD" ]; then
        echo -e "${YELLOW}Could not capture password automatically. Please check 'gophish_output.log' for errors or credentials.${NC}"
    else
        echo -e "\n${GREEN}--- GoPhish Deployment Complete! ---${NC}"
        echo -e "Admin Portal URL: ${YELLOW}http://"$PUBLIC_IP":3333${NC} (Note: HTTP, not HTTPS)"
        echo -e "Phishing URL:     ${YELLOW}https://$DOMAIN${NC}"
        echo -e "Username:         ${YELLOW}admin${NC}"
        echo -e "Password:         ${GREEN}${PASSWORD}${NC}"
        echo -e "\nNOTE: You will be required to change this password on first login."
        echo "GoPhish is running in the background. To stop it, run: pkill gophish"
    fi
    cd ..
}


# --- Main script execution ---
get_domain_name "$1"
install_dependencies
setup_gophish
manual_a_record_setup
generate_ssl
configure_gophish
launch_and_report
