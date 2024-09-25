#!/bin/bash

# Silent mode
exec >/dev/null 2>&1

# --- Update System ---
apt-get update -y
apt-get upgrade -y

# --- Firewall Rules (UFW) ---
apt-get install ufw -y
ufw allow 80/tcp  # HTTP
ufw allow 443/tcp # HTTPS
ufw allow 22/tcp  # SSH
ufw allow 3306/tcp # MySQL (if necessary)
ufw default deny incoming
ufw default allow outgoing
ufw enable

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
echo "AllowUsers your_user" >> /etc/ssh/sshd_config
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
mysql_secure_installation <<EOF

y
y
y
y
y
EOF

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

# --- User Account Hardening ---
# Lock down unused accounts and ensure strong password policies
for user in $(awk -F: '($3 < 1000) { print $1 }' /etc/passwd); do
    if [[ "$user" != "your_user" && "$user" != "root" ]]; then
        usermod -L $user
    fi
done

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

# Enable automatic security updates
apt-get install unattended-upgrades -y
dpkg-reconfigure --priority=low unattended-upgrades

# --- Hide History ---
# Remove history of this session to hide actions from attackers
history -c
history -w
rm -f ~/.bash_history
unset HISTFILE

# --- Set Permissions ---
# Ensure correct permissions for important config files
chmod 600 /etc/ssh/sshd_config
chmod 600 /etc/mysql/my.cnf

# Script execution finished silently
