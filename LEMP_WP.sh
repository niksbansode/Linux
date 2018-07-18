#!/bin/bash

if ! which nginx > /dev/null 2>&1; then
	echo "Nginx is not installed!"
	echo "Installing Nginx ...."
	sudo apt-get install -y nginx > /dev/null 2>&1
	echo "Nginx is successfully installed."
fi
if ! which php > /dev/null 2>&1; then
	echo "PHP is not installed!"
	echo "Installing PHP ...."
	sudo apt-get install -y php-fpm php-mysql > /dev/null 2>&1
	sed -i 's/\;cgi\.fix_pathinfo=1/cgi\.fix_pathinfo=0/' /etc/php/7.0/fpm/php.ini
	sudo systemctl restart php7.0-fpm
	echo "PHP is successfully installed."	
fi
if ! which mysql > /dev/null 2>&1; then
	echo "Mysql is not installed!"
	echo "Installing Mysql...."
	export DEBIAN_FRONTEND="noninteractive"
	echo "mysql-server-5.7 mysql-server/root_password password root" | debconf-set-selections
	echo "mysql-server-5.7 mysql-server/root_password_again password root" | debconf-set-selections
	sudo apt-get install -y mysql-server-5.7 > /dev/null 2>&1
	sudo mysql_secure_installation
	echo "Mysql is successfully installed."
fi

echo "Please enter a domain name : "
read domainName

sudo sed -i "2i 127.0.0.1 ""${domainName}""" /etc/hosts

sudo mkdir -p /var/www/$domainName/html
sudo chmod -R 755 /var/www
sudo chown -R ubuntu:ubuntu /var/www/$domainName/html


echo "Downloading latest wordpress package...."
sudo wget -O /tmp/wordpress-latest.tar.gz http://wordpress.org/latest.tar.gz > /dev/null 2>&1
echo "Extracting wordpress package...."
sudo tar xvzf /tmp/wordpress-latest.tar.gz -C /var/www/$domainName/html > /dev/null 2>&1
sudo mv /var/www/$domainName/html/wordpress/* /var/www/$domainName/html
sudo rm -rf /var/www/$domainName/html/wordpress
sudo rm -f /tmp/wordpress-latest.tar.gz
echo "Wordpress is successfully extracted!"

mysql -u root -proot -e "create database \`""${domainName}""_db\`"
mysql -u root -proot -e "create user 'wordpressUser'@""$domainName"" identified by 'root'"
mysql -u root -proot -e "GRANT ALL PRIVILEGES ON \`""${domainName}""_db\`.* TO 'wordpressUser'@""$domainName"""
mysql -u root -proot -e "FLUSH PRIVILEGES"

sudo cp /var/www/$domainName/html/wp-config-sample.php /var/www/$domainName/html/wp-config.php
sudo sed -i "/DB_HOST/s/'[^']*'/'$domainName'/2" /var/www/$domainName/html/wp-config.php
sudo sed -i "/DB_USER/s/'[^']*'/'root'/2" /var/www/$domainName/html/wp-config.php
sudo sed -i "/DB_PASSWORD/s/'[^']*'/'root'/2" /var/www/$domainName/html/wp-config.php
sudo sed -i "/DB_NAME/s/'[^']*'/'""$domainName""_db'/2" /var/www/$domainName/html/wp-config.php
echo "Wordpress configured successfully!"

sudo cp /etc/nginx/sites-available/default /etc/nginx/sites-available/${domainName}
sudo sed -i 's/listen 80 default_server/listen 80/g' /etc/nginx/sites-available/${domainName}
sudo sed -i 's/listen \[\:\:\]\:80 default_server/listen \[\:\:\]\:80/g' /etc/nginx/sites-available/${domainName}
sudo sed -i 's/index.nginx-debian.html/index.php index.nginx-debian.html/g' /etc/nginx/sites-available/${domainName}
sudo sed -i "s:root /var/www/html:root /var/www/""${domainName}""/html:g" /etc/nginx/sites-available/${domainName}
sudo sed -i "s/server_name _/server_name ""${domainName}"" www.""${domainName}""/g" /etc/nginx/sites-available/${domainName}

sudo sed -i "s:#location.*php\$ {:location \~ \\\.php\$ {:g" /etc/nginx/sites-available/${domainName}
sudo sed -i "s:#\	include snippets/fastcgi-php\.conf\;:\	include snippets/fastcgi-php\.conf\;:g" /etc/nginx/sites-available/${domainName}
sudo sed -i "s:#\	fastcgi_pass unix\:/run/php/php7\.0-fpm\.sock\;:\	fastcgi_pass unix\:/run/php/php7\.0-fpm\.sock\;\n\      \}:g" /etc/nginx/sites-available/${domainName}

echo "Establishing symbolic link ..."
sudo ln -s /etc/nginx/sites-available/$domainName /etc/nginx/sites-enabled/
echo "linked!"
sudo sed -i 's/\# server_names_hash_bucket_size 64/server_names_hash_bucket_size 64/' /etc/nginx/nginx.conf

sudo systemctl restart nginx

echo "Opening wordpress...."
xdg-open http://${domainName}
