#!/bin/bash

# update packages
sudo yum update

# apache install, enable, and status check
sudo yum -y install httpd
sudo systemctl start httpd
sudo systemctl enable httpd
sudo systemctl status httpd
echo "<html><body><h2>Hello World from $(hostname -f)</h2></body></html>" | sudo tee /var/www/html/index.html