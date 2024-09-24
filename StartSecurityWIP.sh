#!/bin/bash

BACKUP_DIR="/root/.system_backups"

# Helper function to log actions
log_action() {
  echo "[INFO] $1"
}

# Backup important directories and mark them immutable
backup_and_immutable() {
  log_action "Creating backups of important directories..."
  mkdir -p "$BACKUP_DIR"

  # Backup /etc, /var/www, and /home directories (modify as needed)
  tar -czf "$BACKUP_DIR/etc-backup.tar.gz" /etc
  tar -czf "$BACKUP_DIR/www-backup.tar.gz" /var/www
  tar -czf "$BACKUP_DIR/home-backup.tar.gz" /home

  # Set the backup directory and files as immutable
  log_action "Marking backup files as immutable..."
  chattr +i "$BACKUP_DIR"
  chattr +i "$BACKUP_DIR/*"
}

# Remove other users (except root and specific user group)
remove_other_users() {
  log_action "Removing unnecessary users..."
  for user in $(awk -F: '$3 >= 1000 {print $1}' /etc/passwd); do
    if [ "$user" != "root" ]; then
      userdel -r "$user"
      log_action "Deleted user: $user"
    fi
  done
}

# Continually change passwords for all users
change_passwords() {
  log_action "Changing passwords for all users..."
  for user in $(awk -F: '$3 >= 1000 {print $1}' /etc/passwd); do
    if [ "$user" != "root" ]; then
      NEW_PASS=$(openssl rand -base64 12)
      echo "$user:$NEW_PASS" | sudo chpasswd
      log_action "Changed password for user: $user"
    fi
  done
}

# Audit and remove SSH keys, including for root
audit_and_remove_ssh_keys() {
  log_action "Auditing and removing all SSH keys..."
  find /home/*/.ssh /root/.ssh -name "authorized_keys" -exec rm -f {} \;
  log_action "Removed all SSH authorized keys"
}

# Audit sudoers file
audit_sudoers() {
  log_action "Auditing the sudoers file..."
  visudo -cf /etc/sudoers && log_action "Sudoers file is OK" || log_action "Sudoers file has issues, check manually!"
  cat /etc/sudoers.d/* | grep -vE "^#|^$" # Print active sudoers rules
}

# Audit running services
audit_services() {
  log_action "Auditing running services..."
  service --status-all | grep '[ + ]' # Lists all active services
}

# Make MySQL database backups and flush privileges
backup_mysql() {

  sudo apt-get install -y mysql-server
  
  # Ensure MySQL is running
  sudo systemctl enable mysql
  sudo systemctl start mysql
  
  # Secure MySQL installation
  sudo mysql_secure_installation <<EOF
  
  y
  root_password
  root_password
  y
  y
  y
  y
  EOF
  
  # Enforce stronger MySQL password policies
  sudo mysql -e "SET GLOBAL validate_password.policy=STRONG;"
  sudo mysql -e "SET GLOBAL validate_password.length=12;"
  sudo mysql -e "SET GLOBAL validate_password.mixed_case_count=1;"
  sudo mysql -e "SET GLOBAL validate_password.number_count=1;"
  sudo mysql -e "SET GLOBAL validate_password.special_char_count=1;"
  
  # Disable remote root login
  sudo mysql -e "DELETE FROM mysql.user WHERE User='root' AND Host!='localhost';"
  sudo mysql -e "FLUSH PRIVILEGES;"

  log_action "Backing up MySQL databases..."
  mkdir -p "$BACKUP_DIR/mysql_backups"
  for db in $(mysql -u root -e 'SHOW DATABASES;' | grep -v 'Database\|information_schema\|performance_schema'); do
    mysqldump -u root --databases "$db" > "$BACKUP_DIR/mysql_backups/${db}_backup.sql"
    log_action "Backed up database: $db"
  done
}

# Secure http services
secure_http() {
  # Set up SSL/TLS for Apache/HTTP services (using self-signed certs or existing ones)
  log_action "Securing HTTP services with SSL/TLS..."
  sudo apt-get install -y apache2 openssl
  sudo a2enmod ssl
  sudo mkdir -p /etc/apache2/ssl
  sudo openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/apache2/ssl/apache.key -out /etc/apache2/ssl/apache.crt -subj "/C=US/ST=YourState/L=YourCity/O=YourOrg/CN=yourdomain.com"
  sudo sed -i '/SSLCertificateFile/s/^#//g' /etc/apache2/sites-available/default-ssl.conf
  sudo sed -i '/SSLCertificateKeyFile/s/^#//g' /etc/apache2/sites-available/default-ssl.conf
  sudo sed -i 's|SSLCertificateFile.*|SSLCertificateFile /etc/apache2/ssl/apache.crt|' /etc/apache2/sites-available/default-ssl.conf
  sudo sed -i 's|SSLCertificateKeyFile.*|SSLCertificateKeyFile /etc/apache2/ssl/apache.key|' /etc/apache2/sites-available/default-ssl.conf
  sudo a2ensite default-ssl
  sudo systemctl restart apache2
  
  # Ensure MySQL, Apache, and SSH services remain running and accessible
  log_action "Ensuring necessary services are up..."
  sudo systemctl enable ssh
  sudo systemctl enable apache2
  sudo systemctl enable mysql
}

# Check for webshells
check_webshells() {
  log_action "Checking for potential webshells..."
  find /var/www -name "*.php" -exec grep -l "base64_decode\|eval\|system\|shell_exec\|exec" {} \;
}

# Check for weird open ports, processes, and logged-in users
check_and_kill_unusual_processes() {
  log_action "Checking for unusual open ports, processes, and logged-in users..."
  
  # List and kill weird open ports (look for suspicious ones)
  ss -tuln | grep -vE ':22|:80|:443|:3306' # Show all open ports except common ones
  log_action "Listing unusual open ports..."
  
  # List running processes and kill weird ones
  ps aux | grep -vE 'root|sshd|apache|mysql|htop|bash|ps'
  
  # Check logged-in users
  log_action "Checking logged-in users..."
  who
  
  # Kill any suspicious users
  log_action "Killing suspicious users/processes if found..."
  pkill -9 -u <suspicious_user>
}

# Run htop/ps and netstat/ss to manually check processes and ports
manual_process_port_check() {
  log_action "Running htop for manual process check..."
  htop
  
  log_action "Running ss/netstat for manual open port check..."
  ss -tuln
}

# Update the system
log_action "Updating system packages..."
sudo apt-get update -y && sudo apt-get upgrade -y

# Enable automatic security updates
log_action "Enabling automatic security updates..."
sudo apt-get install -y unattended-upgrades
sudo dpkg-reconfigure --priority=low unattended-upgrades

# Configure firewall with UFW (Uncomplicated Firewall)
log_action "Setting up UFW firewall..."
sudo apt-get install -y ufw
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow http
sudo ufw allow https
sudo ufw allow mysql
sudo ufw enable

# SSH hardening
log_action "Hardening SSH settings..."
sudo sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sudo sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sudo sed -i 's/#PermitEmptyPasswords yes/PermitEmptyPasswords no/' /etc/ssh/sshd_config
sudo sed -i 's/#MaxAuthTries 6/MaxAuthTries 3/' /etc/ssh/sshd_config
sudo sed -i 's/#ClientAliveInterval 0/ClientAliveInterval 300/' /etc/ssh/sshd_config
sudo sed -i 's/#ClientAliveCountMax 3/ClientAliveCountMax 0/' /etc/ssh/sshd_config
sudo systemctl restart sshd

# Enable SSH logging and banner
log_action "Enabling SSH logging and banner..."
sudo sed -i 's/#LogLevel INFO/LogLevel VERBOSE/' /etc/ssh/sshd_config
sudo echo "Unauthorized access is prohibited." > /etc/issue.net
sudo sed -i 's/#Banner none/Banner \/etc\/issue.net/' /etc/ssh/sshd_config
sudo systemctl restart sshd

# Disable unused network services
log_action "Disabling unused services..."
sudo systemctl stop avahi-daemon
sudo systemctl disable avahi-daemon
sudo systemctl stop cups
sudo systemctl disable cups

# Secure shared memory
log_action "Securing shared memory..."
sudo echo "tmpfs /run/shm tmpfs defaults,noexec,nosuid 0 0" >> /etc/fstab
sudo mount -o remount /run/shm

# Add a strong password policy
log_action "Setting strong password policies..."
sudo apt-get install -y libpam-cracklib
sudo sed -i 's/pam_unix.so/& minlen=12 remember=5/' /etc/pam.d/common-password
sudo sed -i 's/# enforce_for_root/enforce_for_root/' /etc/security/faillock.conf

# Lock down sudoers file (only allow sudo group members to use sudo)
log_action "Locking down sudo permissions..."
sudo echo "%sudo   ALL=(ALL:ALL) ALL" > /etc/sudoers.d/99_sudo

# Remove unused packages and dependencies
log_action "Removing unnecessary packages..."
sudo apt-get autoremove -y

# Audit logs and file integrity monitoring
log_action "Setting up audit logs and integrity monitoring..."
sudo apt-get install -y auditd audispd-plugins
sudo systemctl enable auditd
sudo systemctl start auditd
sudo auditctl -e 1

# Install fail2ban to prevent brute force attacks
log_action "Installing fail2ban..."
sudo apt-get install -y fail2ban
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# Restrict cron jobs to root
log_action "Restricting cron to root only..."
sudo touch /etc/cron.allow
sudo echo "root" > /etc/cron.allow
sudo chown root:root /etc/cron.allow
sudo chmod 600 /etc/cron.allow

# Disable USB storage devices (if applicable)
log_action "Disabling USB storage devices..."
sudo echo "blacklist usb-storage" > /etc/modprobe.d/usb-storage.conf
sudo update-initramfs -u


# System hardening tasks
backup_and_immutable
remove_other_users
change_passwords
audit_and_remove_ssh_keys
audit_sudoers
audit_services
secure_http
backup_mysql
check_webshells
check_and_kill_unusual_processes
manual_process_port_check

log_action "System hardening complete!"
