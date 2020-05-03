## Website Backup Script (Files/Database) and notify with SSMTP

A simple bash script to backup database and files.

Keep in mind, a backup is a must these days.

### How does it work?
The script will archive "/home/alexandru/backups/example.com/" folder and export the database and put the files into /home/alexandru/backups/example.com/[timestamp-data-format]/ folder (in our case) .

After that the script will copy the folder "[timestamp-data-format]" to the remote server using "rsync" command.

If the script fails you will get an email with the error, if it doesn't fail at the end it will check the hash of archive and the sql file.  If the files weren't altered during the rsync you will get an email with "successfully backup".
 
### Setup

##### 1. Install SSMTP
```
# yum install epel-release
# yum install ssmtp
```

##### 2. Edit "/etc/ssmtp/ssmtp.conf" and insert the lines:
```
root=gmail@gmail.com
mailhub=smtp.gmail.com:465
AuthUser=gmail_username
AuthPass=gmail_password
AuthMethod=LOGIN
UseTLS=YES
```

Note: Don't forget to modify the above lines with yours credentials.

##### 3. Edit "/etc/ssmtp/ssmtp.conf" and insert the line:

```
root:gmail@gmail.com:smtp.gmail.com:465
```
Note: Don't forget to modify the above line.

##### 4. SSH 

Ensure you have access to the remote server via ssh key. 

If you don't have a key please generate one with the above command (skip it if you have one).
```
ssh-keygen -t rsa -b 4096
``` 

To use the public key authentication, you need to copy the public key to the remote server and install it in an authorized_keys file.

```
ssh-copy-id root@XXX.XXX.XXX.XXX -p 22
```

Test the ssh
```
ssh root@XXX.XXX.XXX.XXX -p 22 "ls -lah ~  && exit"
```

##### 4. The bash script

Please ensure you have "rsync" installed on both servers. If you don't have it installed please use "yum install rsync" command.

Copy the "backup_and_notify_with_ssmtp.sh" in your directory, in our case "/root/backups/", and do not forget to edit it with your settings/credentials.

Add a cronjob to execute the bash script every day at 3am.

```
0 3 0 0 0 /root/backups/backup_and_notify_with_ssmtp.sh
```

##### 5. Debug the script

If something isn't working correctly you can use the below command to debug the bash script:
```
env -i bash -x /root/backups/backup_and_notify_with_ssmtp.sh
```