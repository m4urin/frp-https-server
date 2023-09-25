#!/bin/bash

# Brief Description of the script
echo "This script automates the setup of FRP services with required packages and configurations to serve HTTPS content for your domain."

# Inform user about required packages
echo "The following packages are required: openssl, certbot, nginx"
read -p "Install dependencies? [Y/n]: " install_dependencies
install_dependencies=${install_dependencies:-Y}  # Default to Y if no input is provided

# Exit if user opts not to install dependencies
if [[ ! "$install_dependencies" =~ ^[Yy]$ ]]; then
    echo "Aborting due to unmet dependencies."
    exit 1
fi

# Installing dependencies
sudo apt-get update && sudo apt-get install -y certbot nginx openssl

# Prompt user to choose service type
read -p "Setup FPR [server/client]: " service_type
if [[ "$service_type" != "server" && "$service_type" != "client" ]]; then
    echo "Invalid service type, please select 'server' or 'client'. Aborting..."
    exit 1
fi

# Set the other service type
other_service=$([[ "$service_type" == "server" ]] && echo "client" || echo "server")

# Prompt user for download link or use default
read -p "FRP download link [default: https://github.com/fatedier/frp/releases/download/v0.51.3/frp_0.51.3_linux_amd64.tar.gz]: " download_link
download_link=${download_link:-"https://github.com/fatedier/frp/releases/download/v0.51.3/frp_0.51.3_linux_amd64.tar.gz"}  # Default link

# Download and extract the package
file_name=$(basename "$download_link")
cd "$(dirname "$0")" || { echo "Failed to change directory. Aborting..."; exit 1; }
wget "$download_link" || { echo "Failed to download package. Aborting..."; exit 1; }
mkdir -p /opt/frp
tar -xvzf "$file_name" --strip-components=1 -C /opt/frp
rm -f "$file_name"

# Handling Authentication and Secret Token
read -p "Secret token from $other_service [default: auto-generate]: " secret_token
if [ -z "$secret_token" ]; then
    secret_token=$(openssl rand -hex 32)
    echo "Generated secret token: $secret_token"
    echo "Please copy this token for $other_service configuration."
fi


# Server Configuration
if [ "$service_type" == "server" ]; then
    # Generate SSL Certificate
    echo "Generating SSL certificates for HTTPS."
    read -p "Domain name (e.g. example.com): " domain_name
    if [ -z "$domain_name" ]; then
        echo "Invalid domain name, cannot be empty. Aborting..."
        exit 1
    fi

    echo "Ensure your domain name points to this IP, is public, and available on port 80."
    read -p "Continue? [Y/n]: " continue_process
    continue_process=${continue_process:-Y}  # Default to Y if no input is provided

    if [[ ! "$continue_process" =~ ^[Yy]$ ]]; then
        echo "Aborting..."
        exit 1
    fi

    sudo certbot certonly --standalone -d "$domain_name" || { echo "Certbot failed. Aborting..."; exit 1; }

    # Configure Dashboard
    echo "Dashboard is accessible at 'https://$domain_name:7500'"
    dashboard_pwd=$(openssl rand -hex 16)
    echo "   username: admin"
    echo "   password: $dashboard_pwd"

    sed -e "s/SECRET_TOKEN/$secret_token/" -e "s/DASHBOARD_PWD/$dashboard_pwd/" templates/frps.ini > /opt/frp/frps.ini
    echo "Secret token and dashboard password are configurable in '/opt/frp/frps.ini'"

    sed "s/DOMAIN_NAME/$domain_name/g" templates/nginx_server.conf > /etc/nginx/sites-available/$domain_name
    echo "Nginx proxy configuration is in '/etc/nginx/sites-available/$domain_name'"

    # Activate Nginx Configuration
    ln -s /etc/nginx/sites-available/$domain_name /etc/nginx/sites-enabled/
    sudo nginx -t && sudo systemctl restart nginx || { echo "Nginx configuration test failed or unable to restart Nginx. Aborting..."; exit 1; }
fi

# Client Configuration
if [ "$service_type" == "client" ]; then
    sed -e "s/SECRET_TOKEN/$secret_token/" -e "s/DOMAIN_NAME/$domain_name/" templates/frpc.ini > /opt/frp/frpc.ini
    echo "Secret token and domain name are configurable in '/opt/frp/frpc.ini'"
fi

# Offer to Create a Systemctl Service
read -p "Would you like to create a systemctl service for your $service_type? [Y/n]: " create_service
create_service=${create_service:-Y}  # Default to Y if no input is provided

if [[ "$create_service" =~ ^[Yy]$ ]]; then
    if [ "$service_type" == "server" ]; then
        cp -f templates/frps.service /etc/systemd/system/frps.service
        sudo systemctl daemon-reload && sudo systemctl enable frps && sudo systemctl start frps || {
            echo "Failed to configure 'frps' service. Aborting..."
            exit 1
        }
        echo "Service 'frps' created and can be configured with '/opt/frp/frps.ini'"
    else
        cp -f templates/frpc.service /etc/systemd/system/frpc.service
        sudo systemctl daemon-reload && sudo systemctl enable frpc && sudo systemctl start frpc || {
            echo "Failed to configure 'frpc' service. Aborting..."
            exit 1
        }
        echo "Service 'frpc' created and can be configured with '/opt/frp/frpc.ini'"
    fi
else
    echo "Systemctl service creation skipped."
    if [ "$service_type" == "server" ]; then
        echo "You can start the service manually by running the following command:"
        echo "sudo /opt/frp/frps -c /opt/frp/frps.ini"
    else
        echo "You can start the service manually by running the following command:"
        echo "sudo /opt/frp/frpc -c /opt/frp/frpc.ini"
    fi
fi

echo "Installation and configuration completed successfully."
