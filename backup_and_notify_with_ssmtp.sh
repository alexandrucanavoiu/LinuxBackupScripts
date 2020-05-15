#!/bin/bash
#your domain name
domain="example.com"
#your database username, it will be used with mysqldump
mysql_user="mysql_user"
#your database username password, it will be used with mysqldump
mysql_password="mysql_user_password"
#your database name, it will be used with mysqldump
db_name="name_db"
#your website location
website_location="/home/domain"
#backup directory
dir="/root/backups/websites/example.com"
#unixtime time format (1588495937)
now=$(date +%s)
#current date
date=$(date +%Y-%m-%d)
#the minimum size of the backup folder, if the size is less then $size your backup will fail and you will receive an email.
size=2000000
#email used to send emails
to_email="email@gmail.com"
#email used to receive alerts about backup
from_email="email@gmail.com"
# 1 for true / 0 for false, if the job fails delete the backup from local server
delete_if_fail=1
#ssh port by default is 22
backup_ssh_port="22"
#ssh username used to connect over ssh
backup_ssh_user="alexandru"
#ip to the external server
backup_ssh_ip="XXX.XXX.XXX.XX"
#external location for backup
backup_location="/home/alexandru/backups/example.com/"
#error log output for rsync
error_output_file="/tmp/rsync_error.txt"
#date when backup is started
backup_start=$(date +"%T %d-%m-%Y")

#create a local directory for backup file/db.
mkdir -p "$dir/$now"


# functions
function delete_dir_now(){
if [ -d "$dir/$now" ]; then
        rm -rf "${dir:?}/$now"
fi

}

function ssmtp_type() {
                case $1 in
                        "0")
/sbin/ssmtp $to_email <<EOF
To: $to_email
From: $from_email
Subject: Backup Successful $domain

Hello,

A backup job finished successfully for domain $domain

Additional information:
Backup Start: $backup_start
Backup Finished: $(date +"%T %d-%m-%Y")

Best regards,
Your Server :)
EOF
                        ;;

                        "1")
/sbin/ssmtp $to_email <<EOF
To: $to_email
From: $from_email
Subject: BACKUP FAILED $domain

Hello,

A backup job finished with error for domain $domain
It is not enough disk space to perform the backup. Please check.

Best regards,
Your Server :)
EOF
                        ;;
                        "2")
/sbin/ssmtp $to_email <<EOF
To: $to_email
From: $from_email
Subject: BACKUP FAILED $domain

Hello,

A backup job finished with error for domain $domain
The size of backup is less then desireded size. Please check.

Best regards,
Your Server :)
EOF
                        ;;
                        "3")
rsync_error_to_display=$(cat "$error_output_file")
/sbin/ssmtp $to_email <<EOF
To: $to_email
From: $from_email
Subject: BACKUP FAILED $domain

Hello,

A backup job finished with error for domain $domain

Error:

$rsync_error_to_display

Best regards,
Your Server :)
EOF
                        ;;
                        "4")
rsync_error_to_display=$(cat "$error_output_file")
/sbin/ssmtp $to_email <<EOF
To: $to_email
From: $from_email
Subject: BACKUP FAILED $domain

Hello,

A backup job finished with error for domain $domain

Error:

The files didn't copy successfully to the backup server. (HASH MISMATCH)

Best regards,
Your Server :)
EOF
                        ;;
                        *)

/sbin/ssmtp $to_email <<EOF
To: $to_email
From: $from_email
Subject: BACKUP FAILED $domain

Hello,

A backup job finished with error for domain $domain

Error: no ssmtp_type defined

Best regards,
Your Server :)
EOF
                        ;;
                esac
}

#check if is enough disk space to perform the backup ($free_disk_space_needed + 2000000)
usage_disk_file=$(du -s $website_location | tail -1 | awk '{print $1}')
usage_disk_db=$(du -s /var/lib/mysql/$db_name | tail -1 | awk '{print $1}')

free_disk_space=$(df -k $dir | tail -1 | awk '{print $4}')
free_disk_space_needed=$((usage_disk_file + usage_disk_db + 2000000))

if [ "$free_disk_space" -lt "$free_disk_space_needed" ]; then

ssmtp_type 1

exit 1;

fi



#dump the database $db_name
/bin/mysqldump -h localhost -u $mysql_user -p$mysql_password $db_name > "$dir/$now/$db_name.$date.sql"

#archive $website_location folder in a .tar.gz
/bin/tar -cpzf "$dir/$now/files-$date.tar.gz" website_location

#get the hash of db/file
hash_db_local=$(md5sum $dir/$now/$db_name.$date.sql | awk -F" " '{print $1}')
hash_files_local=$(md5sum $dir/$now/files-$date.tar.gz | awk -F" " '{print $1}')

#check if backup folder is less then our expected $size
CHECKER=$(du -s "$dir/$now" | awk '{ print $1}')

if [ "$CHECKER" -lt "$size" ]; then

ssmtp_type 2

if [[ "$delete_if_fail" == 1 ]]; then
delete_dir_now
fi

exit 1;

fi

#remove the $error_output_file
rm -f $error_output_file

# 1. rsync folder from local to the backup server.
#if the ssh connection is done successfully and rsync command doesn't return an error continue de script.
#if the ssh connection is not done successfully or rsync command returns an error, an email will be sent to the $to_email with the error log in body.
# 2. get the hashes for $db_name.$date.sql and $files-$date.tar.gz files.
# 3. check if the local $db_name.$date.sql and $files-$date.tar.gz files and the copied files have the same hash.
#if the hash is not the same, email to the $to_email
#if the hash are the same send a successfully email (ssmtp_type 0) and delete the local folder.

if [[ ${backup_ssh_port:-22} != 22 ]]; then args+=( -e "ssh -p $backup_ssh_port" ); fi;

if rsync -arz "${args[@]}" "$dir/$now" "$backup_ssh_user@$backup_ssh_ip:$backup_location/" > $error_output_file 2>&1; then

#get the remote hash for file/db
hash_db_remote=$(ssh $backup_ssh_user@$backup_ssh_ip -p $backup_ssh_port "md5sum $backup_location/$now/$db_name.$date.sql")
hash_db_remote=$(echo "$hash_db_remote" | awk -F" " '{print $1}')
hash_files_remote=$(ssh $backup_ssh_user@$backup_ssh_ip -p $backup_ssh_port "md5sum $backup_location/$now/$files-$date.tar.gz")
hash_files_remote=$(echo "$hash_files_remote" | awk -F" " '{print $1}')

if [[ $hash_db_local == $hash_db_remote && $hash_files_local == $hash_files_remote ]]; then
		        ssmtp_type 0
				rm -rf "${dir:?}/$now"
	else
				ssmtp_type 4
				if [[ "$delete_if_fail" == 1 ]]; then
				delete_dir_now
				fi
fi

else
        ssmtp_type 3
        if [[ "$delete_if_fail" == 1 ]]; then
                delete_dir_now
        fi
        exit 1;
fi