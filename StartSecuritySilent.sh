#!/bin/bash

# Silent mode
exec >/dev/null 2>&1

FILE_BACKUP_DIR="/root/.change_me_filebackup"
SQL_BACKUP_DIR="/.change_me_sqlbackup"
NEW_MYSQL_ROOT_PASSWORD="MyNewPass"

# --- Update System ---
apt-get update -y
apt-get upgrade -y

# --- Firewall Rules (UFW) ---
apt-get install ufw -y
ufw deny 4444
ufw allow 'Apache Secure' #443
ufw allow OpenSSH
ufw allow mysql
ufw allow ssh
ufw allow ftp
ufw allow http
ufw allow 20 tcp
ufw allow 990 tcp

ufw default deny incoming
ufw default allow outgoing
ufw enable

# --- Download Useful Tools ---
apt install ranger -y
apt install tmux -y
apt install curl -y
apt install whowatch -y

wget https://github.com/DominicBreuker/pspy/releases/download/v1.2.1/pspy64
chmod +x pspy64

# --- SSH Hardening ---
# Disabling root login and restricting SSH settings
sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/X11Forwarding yes/X11Forwarding no/' /etc/ssh/sshd_config
sed -i 's/UsePAM yes/UsePAM no/' /etc/ssh/sshd_config
sed -i 's/#AllowTcpForwarding yes/AllowTcpForwarding no/' /etc/ssh/sshd_config
sed -i 's/#ClientAliveInterval 0/ClientAliveInterval 300/' /etc/ssh/sshd_config
sed -i 's/#PubkeyAuthentication yes/PubkeyAuthentication yes/' /etc/ssh/sshd_config
sed -i 's/#MaxAuthTries 6/MaxAuthTries 3/' /etc/ssh/sshd_config

#SSH whitelist
echo "AllowUsers hkeating ubuntu" >> /etc/ssh/sshd_config
echo "Protocol 2" >> /etc/ssh/sshd_config

# Remove ssh keys and restart service
find /home/*/.ssh /root/.ssh -name "authorized_keys" -exec rm -f {} \;
service ssh restart

# --- Fail2Ban for SSH ---
apt-get install fail2ban -y
cat << EOF > /etc/fail2ban/jail.local
[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600
EOF
service fail2ban restart

# --- MySQL Security ---
# Backup all MySQL databases
mkdir -p "$SQL_BACKUP_DIR"
mysqldump -u root --all-databases > "$SQL_BACKUP_DIR/db.sql"

mysql_secure_installation <<EOF

y
y
y
y
y
EOF

# Log into MySQL, list users, change root password, and flush privileges
mysql -u root <<MYSQL_SCRIPT
SELECT * FROM mysql.user;
ALTER USER 'root'@'localhost' IDENTIFIED BY '$NEW_MYSQL_ROOT_PASSWORD';
FLUSH PRIVILEGES;
MYSQL_SCRIPT

# MySQL configuration: restrict remote access and ensure strong security settings
sed -i 's/bind-address.*/bind-address = 127.0.0.1/' /etc/mysql/mysql.conf.d/mysqld.cnf
systemctl restart mysql

# --- Apache/HTTP Hardening ---
# Disable Apache version disclosure and server signature
if [ -f /etc/apache2/apache2.conf ]; then
    sed -i 's/ServerTokens OS/ServerTokens Prod/' /etc/apache2/conf-available/security.conf
    sed -i 's/ServerSignature On/ServerSignature Off/' /etc/apache2/conf-available/security.conf
    a2enconf security
    systemctl reload apache2
fi

# Change apache file owner to root
sudo chown -R root:root /etc/apache2

# --- User Account Hardening ---
# Lock down unused accounts and ensure strong password policies
for user in $(awk -F: '($3 < 1000) { print $1 }' /etc/passwd); do
    if [[ "$user" != "your_user" && "$user" != "root" ]]; then
        usermod -L $user
    fi
done

# Lock root password
passwd -l root

# Enforce strong password policies
apt-get install libpam-cracklib -y
sed -i 's/pam_unix.so/pam_unix.so obscure sha512/' /etc/pam.d/common-password
echo "password requisite pam_cracklib.so retry=3 minlen=12 difok=3" >> /etc/pam.d/common-password

# --- General System Hardening ---
# Disable unused services
for service in telnet ftp rsh; do
    systemctl disable $service
    systemctl stop $service
done

# Allow only the scoring user
echo "hkeating" >> /etc/vsftpd.userlist
echo "userlist_enable=YES" >> /etc/vsftpd.userlist
echo "userlist_file=/etc/vsftpd.userlist" >> /etc/vsftpd.conf
echo "userlist_deny=NO" >> /etc/vsftpd.conf
echo "chroot_local_user=NO" >> /etc/vsftpd.conf

# General
echo "anonymous_enable=NO" >> /etc/vsftpd.conf
echo "local_enable=YES" >> /etc/vsftpd.conf
echo "write_enable=YES" >> /etc/vsftpd.conf
echo "xferlog_enable=YES" >> /etc/vsftpd.conf
echo "ascii_upload_enable=NO" >> /etc/vsftpd.conf
echo "ascii_download_enable=NO" >> /etc/vsftpd.conf
service vsftpd restart

# Remove nopasswdlogon group
sed -i -e '/nopasswdlogin/d' /etc/group

# Enable automatic security updates
apt-get install unattended-upgrades -y
dpkg-reconfigure --priority=low unattended-upgrades

# --- File Backups ---
mkdir -p "$FILE_BACKUP_DIR"

# Backup /etc, /var, /opt, and /home directories (modify as needed)
tar -czf "$FILE_BACKUP_DIR/etc-backup.tar.gz" /etc
tar -czf "$FILE_BACKUP_DIR/var-backup.tar.gz" /var
tar -czf "$FILE_BACKUP_DIR/opt-backup.tar.gz" /opt
tar -czf "$FILE_BACKUP_DIR/home-backup.tar.gz" /home

# Set the backup directory and files as immutable
chattr +i "$FILE_BACKUP_DIR"
chattr +i "$FILE_BACKUP_DIR/*"

# --- Set Permissions ---
# Ensure correct permissions for important config files
chmod 600 /etc/ssh/sshd_config
chmod 600 /etc/mysql/my.cnf
chmod 600 /etc/passwd
chmod 600 /etc/vsftpd.userlist
chmod 600 /etc/vsftpd.conf
# chattr +i /etc/vsftpd.userlist
# chattr +i /etc/vsftpd.conf

# --- Hide History ---
# Remove history of this session to hide actions from attackers
history -c
history -w
rm -f ~/.bash_history
unset HISTFILE 
# ^^^^ should we set histfile to track attackers???

# Script execution finished silently
