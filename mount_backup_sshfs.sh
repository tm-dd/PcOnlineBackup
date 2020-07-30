#!/bin/bash
#
# mount script for sshfs based backup targets
#
# Copyright (C) 2020 Thomas Mueller <developer@mueller-dresden.de>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License version 3,
# as published by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#

# backup target vaules ("encfsctl passwd /system_backups/system/encfsBackupData" allows passwort changing on encfs)
sftpBackupTargetServer='login@server.domain.tld:'
sftpBackupLocalMountPoint='/system_backups/system'
encfsPassword='ENCFS PASSWORD'
mailNotificationAddress='example@mail.org'
encfsBackupData='/system_backups/system/encfsBackupData'
encfsBackupMount='/system_backups/system/encfsBackupMount'

# if nessesary, mount the sshfs target
if [ -z "`/bin/mount | grep \"^$sftpBackupTargetServer on \"`" ]
then
    /usr/bin/sshfs -o nonempty ${sftpBackupTargetServer} ${sftpBackupLocalMountPoint}
    (set -x; sleep 5)
fi

# try the mount point
if [ -z "`/bin/mount | grep \"^$sftpBackupTargetServer on \"`" ]
then

    # send a error message and stop the backup process, now
    (date; echo; echo "ERROR: The backup target $sftpBackupLocalMountPoint could not mounted from sftpBackupTargetServer with sshfs."; echo; df -h | grep -v '^tmpfs ') | /usr/bin/mail -s "Error on server `hostname`" $mailNotificationAddress
    exit -1

fi

# if desired, mount the backup volumen with encfs to encrypt the backup on the target
if [ -n "${encfsPassword}" ] && [ -z "`/bin/mount | grep \"/encfsBackupMount\"`" ]
then

    if [ -d "$encfsBackupData" ] && [ -d "$encfsBackupMount" ]
    then
        ENCFSMESSAGE=`echo "${encfsPassword}" | encfs -i 10 -S $encfsBackupData $encfsBackupMount`
    else
	mkdir -p $encfsBackupData $encfsBackupMount
	echo -e "\nPlease setup encfs (and use the password '$encfsPassword' ), now.\n"
        encfs -i 10 $encfsBackupData $encfsBackupMount
    fi

    (set -x; sleep 10)
    
    # possible error, stop the backup process now and send a mail
    if [ -n "${ENCFSMESSAGE}" ]
    then
	echo "${ENCFSMESSAGE}" 
        echo "${ENCFSMESSAGE}" | mail -s "ENCFS and BACKUP ERROR on $HOSTNAME (BACKUP STOP NOW.)" ${mailNotificationAddress}
        umount $encfsBackupMount
        umount "${sftpBackupLocalMountPoint}"
        exit -1
    fi
    
fi

exit 0
