#!/bin/bash
yum install httpd -y
systemctl enable --now httpd
echo "<h1>This is my first webserver and My machine hostname is $(hostname)</h1>" >> /var/www/html/index.html
systemctl restart httpd