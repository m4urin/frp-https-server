# Reverse Proxy HTTPS Server Setup Assistant

## Introduction
This project provides an automated and interactive installer aimed at simplifying the process of setting up a secure HTTPS server with certificates. The script is especially useful for serving HTTPS webpages from a local server situated behind a NAT or firewall.

Setting up an HTTPS server over `frp` can be complex due to the requirement for the client to hold private certificate keys. However, transferring these keys from the server to the client is not optimal, as it's preferable for the server to handle HTTPS. To maintain a secure connection between the client and `frp` server, a TLS connection is used with a secret token. While `frp` can serve the websites in HTTPS, Nginx is utilized as an additional proxy for handling HTTPS with the obtained certificates.

## Prerequisites
### Public server:
- A system with a public IP and available ports: 80 (HTTP), 443 (HTTPS), 7000 (TCP, bind with private server), and 8443 (TCP, FRP dashboard).
- A registered domain name (e.g. `example.com`) that is configured to refer to the public IP of this system. This is required for obtaining certificates via [Let's Encrypt](https://letsencrypt.org/).

### Private server (client behind a NAT):
- A client serving HTTP (not HTTPS) requests on localhost:80.

### Network Configuration:
- During the setup, port 80 must be available and open to the internet for obtaining certificates via Let's Encrypt.
- Ports 7001 (HTTP proxy) and 7002 (HTTPS proxy) must be available on the server for the Nginx proxy server to function properly. These can be altered in the code if necessary.

## Installation
Clone the repository to your local machine:
```sh
git clone https://github.com/m4urin/frp-https-server.git
```
Navigate to the cloned directory and run `setup.sh`:
```sh
cd https-tunnel-server && sudo bash setup.sh
```

This will take you through the process of setting up the server and the creation of the certificates.


## Configuration

The installer tries to handle the configuration, but can they can be adjusted later:

### FRP (fast reverse proxy)
The configuration files for `frp` are stored in `/opt/frp`:

- For Server: `/opt/frp/frps.ini`
- For Client: `/opt/frp/frpc.ini`

You can modify these files to tweak the settings to your preference, and restart the service for the changes to take effect.

### Certificates
The certificates obtained from Let's Encrypt are stored in `/etc/letsencrypt/live/[your_domain_name]/`. 
Let's Encrypt automatically sets up a timer to renew the certificates when close to expiration.

### Ports
The ports configured for Nginx proxy can be altered in the code, located at ports 7001 (HTTP proxy) and 7002 (HTTPS proxy) by default.
These are not the ports for users or the clients, just between the server and the nginx instance.

### Running the server

After installation, if you selected to create a `systemctl` service during the installation process, the FRP server/client will start automatically upon system boot. 

When changing `frps.ini`/`frpc.ini`  on the server/client, restart with:
```sh
sudo systemctl restart [frps/frpc]
```
and show the status with:
```sh
sudo systemctl status [frps/frpc]
```

If you did not select to create a service, you can start them manually by running the following commands:

For Server:
```sh
sudo /opt/frp/frps -c /opt/frp/frps.ini
```

For Client:
```sh
sudo /opt/frp/frpc -c /opt/frp/frpc.ini
```

### Dashboard
If you have configured the server, the FRP dashboard can be accessed through
`https://[your_domain_name]:7500` 
using the username `admin` and the password generated during the installation process.
The username, password and port can be changed in `/opt/frp/frps.ini`

### Nginx
Nginx configuration for the server is stored in `/etc/nginx/sites-available/[your_domain_name]` and can be modified to suit your needs. 
After modifying, ensure to reload Nginx to apply the changes:
```sh
sudo systemctl reload nginx
```

## Usage
### Example
```python
#app.py

from flask import Flask
app = Flask(__name__)

@app.route('/')
def home():
    return 'Hello, World!'

if __name__ == '__main__':
    app.run(host='127.0.0.1', port=80)
```

`app.py` running on `localhost:80`:
```sh
sudo systemctl reload frpc
python app.py
```

## Future work
- add subdomains

## Troubleshooting
If you encounter any issues during installation or usage, please refer to the FRP [official documentation](https://github.com/fatedier/frp) and the Nginx [official documentation](http://nginx.org/en/docs/).

For issues specifically related to this setup script, please check the existing issues or create a new one in this repository’s [Issue Tracker](https://github.com/m4urin/https-tunnel-server/issues). Thanks in advance!

## Contributing
If you would like to contribute anything to this project, feel free to submit a pull request. I welcome any bug fixes, and other contributions.

## License
This project is licensed under the Apache License, Version 2.0 - see the [LICENSE](LICENSE) file for details.
