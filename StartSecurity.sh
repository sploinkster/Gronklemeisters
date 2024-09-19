#!/bin/bash

currentscript="$0";
function finish {
    echo "Securely shredding ${currentscript}"; shred -u ${currentscript};
    sudo sh -c "echo > /var/log/syslog";
}



unset HISTFILE

echo "\n Haiiii!! :333 starting security measures\n"



#Slide 17 from 2024-09-13 Linux Security.pdf (backups)

SECRET_BACKUP_DIR="/.changebackupname";
echo "backing up /var, /etc, /opt, and /home to hidden directory $SECRET_BACKUP_DIR"

mkdir $SECRET_BACKUP_DIR
cp -ar /var $SECRET_BACKUP_DIR
cp -ar /etc $SECRET_BACKUP_DIR
cp -ar /opt $SECRET_BACKUP_DIR
cp -ar /home $SECRET_BACKUP_DIR
sudo chattr +i -R $SECRET_BACKUP_DIR

#Slide 18 from 2024-09-13 Linux Security.pdf (change passwords, to-do*)




trap finish EXIT
