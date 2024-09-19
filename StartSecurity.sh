#!/bin/bash

echo "\n Haiiii!! :333 starting security measures\n"



#Slide 17 from 2024-09-13 Linux Security.pdf (backups)

SECRET_BACKUP_DIR="/.changebackupname"
echo "backing up /var, /etc, /opt, and /home to hidden directory $SECRET_BACKUP_DIR"

mkdir $SECRET_BACKUP_DIR
cp -avr /var $SECRET_BACKUP_DIR
cp -avr /etc $SECRET_BACKUP_DIR
cp -avr /opt $SECRET_BACKUP_DIR
cp -avr /home $SECRET_BACKUP_DIR
chattr +i -R $SECRET_BACKUP_DIR

#Slide 18 from 2024-09-13 Linux Security.pdf (change passwords, to-do*)

