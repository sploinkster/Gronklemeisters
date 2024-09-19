#!/bin/bash

currentscript="$0";
SECRET_BACKUP_DIR="/.changebackupname";

function finish {
    echo "Securely shredding ${currentscript}"; shred -u ${currentscript};
    sudo sh -c "echo > /var/log/syslog";
    # potentially reset histfile to monitor redteam?
}



unset HISTFILE
echo "\n Haiiii!! :333 starting security measures\n"


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

#Slide 27 from 2024-09-13 Linux Security.pdf (remove sshkeys, to-do*)
apt-get install ufw -y
ufw allow ssh
ufw allow http
ufw allow mysql
ufw enable



trap finish EXIT
