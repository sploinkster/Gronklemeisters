#!/bin/bash

#display start message and disable command history (run silently)
unset HISTFILE
echo "\n Haiiii!! :333 starting security measures\n"


#variable defs
CURRENT_SCRIPT="$0";
SECRET_BACKUP_DIR="/.changebackupname";
SECRET_MYSQL_PASS="changeme";

#exit safely (leave no trace)
function finish {
    echo "Securely shredding ${CURRENT_SCRIPT}"; shred -u ${CURRENT_SCRIPT};
    sudo sh -c "echo > /var/log/syslog";
    # potentially reset histfile to monitor redteam?
}



#Slide 17 from 2024-09-13 Linux Security.pdf (backups)
echo "backing up /var, /etc, /opt, and /home to hidden directory $SECRET_BACKUP_DIR"

mkdir $SECRET_BACKUP_DIR
cp -ar /var $SECRET_BACKUP_DIR
cp -ar /etc $SECRET_BACKUP_DIR
cp -ar /opt $SECRET_BACKUP_DIR
cp -ar /home $SECRET_BACKUP_DIR
sudo chattr +i -R $SECRET_BACKUP_DIR

#Slide 18 from 2024-09-13 Linux Security.pdf (change passwords, to-do*)

#Slide 20 from 2024-09-13 Linux Security.pdf (remove sshkeys, to-do*)
#shred -u ~/.ssh/authorized_keys
#sudo su
#shred -u /root/.ssh/authorized_keys
#audit SSH configuration directory /etc/ssh/sshd and /etc/ssh/sshd.d/

#Slide 27 from 2024-09-13 Linux Security.pdf (install ufw firewall (add extra inbound/outbound rules))
#https://linuxconfig.org/how-to-install-and-use-ufw-firewall-on-linux
apt-get install ufw -y
ufw allow ssh
ufw allow http
ufw allow mysql
ufw enable

#Slide 24 from 2024-09-13 Linux Security.pdf (remove sshkeys, to-do*)
#https://www.digitalocean.com/community/tutorials/how-to-install-mysql-on-ubuntu-20-04
apt install mysql-server
systemctl start mysql.service
mysqldump -u root --all-databases > /backup/db.sql

mysql
select * from mysql.user;
ALTER USER 'root'@'localhost' IDENTIFIED BY "$SECRET_MYSQL_PASS"; FLUSH PRIVILEGES;
#ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY "$SECRET_MYSQL_PASS"'; FLUSH PRIVILEGES;
#exit

mysql_secure_installation


trap finish EXIT
