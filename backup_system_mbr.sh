#!/bin/bash
#
# save partitions and LVM volumes with snapshots on running systems
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
# some last changes (german only):
#
# 		2013-10-01 -> Anpassungen wegen /dev/sda anstelle /dev/cciss/*
#       2013-10-11 (und die Tage davor) -> grundlegende Aenderungen des Skriptes
#       2013-10-14 kleine Aenderungen bzw. des tar-Abzuges und Infos an den Benutzer
#       2013-10-23 lvremove des SNAPSHOTS in einer While-Schleife, da dies auf server XY mitunter viele manuelle Loeschversuche benoetige bis es klappte
#       2013-10-24 Snapshots werden nun als READ-ONLY angelegt und die Konsistenz dessen ueber der Wert fuer "Allocated to snapshot" ermittelt 
#		2013-11-13 nun neu: Abbruch, wenn $CONFIGFILE nicht auffindbar
#		2013-11-21 kleine Verbesserung im Info-Text bei der GRUB-Wiederhestellung und Co.
#       2015-05-28 ergaenzen der Zeile "cp /etc/blkid.tab config/blkid.tab" um das Stueck " || /sbin/blkid > config/blkid.txt", da die Datei "/etc/blkid.tab" nicht mehr unter Debian 8 existierte
#       2015-11-19 kleine Verbesserungen im Text des RESTORE-Skriptes
#       2016-09-04 nun mit export den PATH ergaenzen um Aufruf per cron zu ermoeglichen, sowie Skript mount_backup_sshfs.sh bereitstellen
#       2017-01-10 den Dateinamen des $CONFIGFILE und $CONFIGPATH an allen Stellen im Skript angepasst
#

# append the path (nessesary for cron based backups)
export PATH=$PATH:/sbin

# read the config
CONFIGPATH="/system_backups/"
CONFIGFILE="backup_mbr.cfg"
source ${CONFIGPATH}/${CONFIGFILE} || exit -1

# wait seconds before staring
if [ -n "${randomTimeDiffer}" ]; then (set -x; sleep $((${RANDOM}/${randomTimeDiffer})) ); fi

# start a mount script for the backup
if [ -n "${startMountScript}" ]; then source "${startMountScript}"; fi

# remove old backups
if [ -n "${keepOnlyNumberOfBackups}" ]; then cd ${BACKUPMAINDIR} || exit; ls -1dh BACKUP_* | head -n -${keepOnlyNumberOfBackups} | xargs rm -rvf; fi
if [ -n "${deleteBackupOlderThanDays}" ]; then for i in ${BACKUPMAINDIR}/BACKUP_*; do /usr/bin/find $i -maxdepth 0 -type d -mtime "+${deleteBackupOlderThanDays}" -exec rm -rfv {} \; ; done; fi

# print some messages for the user
echo 
echo 'Dieses Skript' $0 'wird nun versuchen ein BACKUP DES LAUFENDEN BETRIEBSSYTEMS durchzufuehren.'
echo
echo 'Laut aktueller Konfiguration werden dabei die folgenden Partitionen:Verzeichnisse per TAR abgezogen:' $TARSOURCES
echo 'Weiterhin werden auch die folgenden Mountpunkte per LVM-Snapshot abgezogen:' $LVMSOURCES
echo 'Alle diese Verzeichnisse muessen auf folgenden Geraet liegen: ' $BACKUPDISC
echo 'Eventuell WEITERE vorhandene DATEN WERDEN NICHT GESICHERT.'
echo 
echo 'Bitte testen Sie die korrekte Funktion des Backups auch bei jeder grossen Aenderung erneut.'
echo
sleep 5
echo "... erstelle neues Verzeichnis fuer das aktuelle Backup"

        # create the new backup directory
		mkdir -p $BACKUPDIR 
		cd $BACKUPDIR || (echo "ERROR: BACKUP DIRECTORY BACKUPDIR NOT FOUND !" exit -1)

echo
echo "... starte neue Datei $RESTOREFILE "

        # start the restore script
        echo '#!/bin/bash' > $RESTOREFILE
        echo '#' >> $RESTOREFILE
        echo '# automatisch erstelltes RESTORE-Skript' >> $RESTOREFILE
        echo '# Fragen an Thomas Mueller' >> $RESTOREFILE
        echo '#' >> $RESTOREFILE
        echo '' >> $RESTOREFILE
        echo 'source ./'${CONFIGFILE}' || (echo "ERROR: ./'${CONFIGFILE}' NOT FOUND !" exit -1)' >> $RESTOREFILE
        echo '' >> $RESTOREFILE
        echo 'BACKUPDIR=`pwd`' >> $RESTOREFILE
        
        cp ${CONFIGPATH}/${CONFIGFILE} $BACKUPDIR/

echo        
echo "... schreibe erste Bloecke sowie die Partitionen-Konfiguration in Computer- und Menschenlesbarer Form"

        mkdir -p config

        # save the first blocks from the device (usefull to save grub)
        dd if=$BACKUPDISC of=first_10MB.dd bs=10M count=1

        # save the partition configuration       
		sfdisk -d $BACKUPDISC > config/partitions.sfdisk
		parted $BACKUPDISC unit s print free > config/partitions.parted
		parted $BACKUPDISC print free >> config/partitions.parted
        
        # write the commands to restore partitions later
        echo '' >> $RESTOREFILE
        echo 'echo ' >> $RESTOREFILE
        echo 'echo "!!! WARNING: READ THIS CARFULY !!!"' >> $RESTOREFILE
        echo 'echo' >> $RESTOREFILE
        echo 'echo "You can change some settings for the restore process in the file: $BACKUPDIR/'${CONFIGFILE}' ."' >> $RESTOREFILE        
        echo 'echo -n "Should the old partition table reinstall and the partitions format now (THIS WILL DELETE ALL FILES ON $BACKUPDISC !!!) (y/n) ?"' >> $RESTOREFILE
        echo 'read USERINPUT' >> $RESTOREFILE
        echo 'if [ $USERINPUT = y ]' >> $RESTOREFILE
        echo 'then' >> $RESTOREFILE
        echo '    if [[ -n `df -h . | grep "$BACKUPDISC"` ]]' >> $RESTOREFILE
        echo '    then' >> $RESTOREFILE
        echo '        echo "ERROR: IT LOOKS LIKE YOUR BACKUP IS ON THE SAME DEVICE LIKE YOU WANT TO REINSTALL NOW. I STOP NOW."' >> $RESTOREFILE
        echo '        exit -1' >> $RESTOREFILE
        echo '    fi' >> $RESTOREFILE
        echo '    set -x' >> $RESTOREFILE
        echo '    sfdisk -R $BACKUPDISC' >> $RESTOREFILE
        echo '    dd if=first_10MB.dd of=$BACKUPDISC bs=10M' >> $RESTOREFILE
        echo '    sfdisk -f $BACKUPDISC < $BACKUPDIR/config/partitions.sfdisk' >> $RESTOREFILE
        echo '    sleep 3' >> $RESTOREFILE
        echo '    sfdisk -R $BACKUPDISC' >> $RESTOREFILE

echo
echo "... schreibe LVM-Konfiguration in Menschenlesbarer Form"

        # backup all LVM configurations, for a manually desaster recovery
		pvdisplay -v > config/pvdisplay.txt
		vgdisplay -v > config/vgdisplay.txt
		lvdisplay -v > config/lvdisplay.txt
        cp /etc/blkid.tab config/blkid.tab || /sbin/blkid > config/blkid.txt
        
echo
echo "... erstelle LVM-Konfiguration fuer das Restore-Skript"

		# this will create the LVM physical volumes later
        echo '    pvcreate $PVDEVS' >> $RESTOREFILE

        # this will create the LVM volume groups later
        for i in $(echo $LVMSOURCES); do
            VGNAME=`lvdisplay $i | grep 'VG Name' | awk '{ print $3 }'`
            PESIZE=`vgdisplay $VGNAME | grep 'PE Size' | awk '{ print $3 $4 }' | sed 's/,00//' | sed 's/\.00//' | sed 's/iB$//'`
            COMMAND="vgcreate -s $PESIZE $VGNAME "'$PVDEVS'
            # write the COMMAND only ones in the restore script
            if [[ -z `grep "$COMMAND" $RESTOREFILE` ]]
            then
                echo "    $COMMAND" >> $RESTOREFILE
            fi
        done
            
        # this will create the LVM locical volumes later 
        for i in $(echo $LVMSOURCES); do
            VGNAME=`lvdisplay $i | grep 'VG Name' | awk '{ print $3 }'`
            LVNAME=`lvdisplay $i | grep 'LV Name' | awk '{ print $3 }'`
            # set the name of the logical volumen (use now "lvexample" instead of "/dev/vgexample/lvexample")
            if [[ -n `echo $LVNAME | awk -F '/' '{ print $4 }'` ]]; then LVNAME=`echo $LVNAME | awk -F '/' '{ print $4 }'`; fi
            CURRENTLE=`lvdisplay $i | grep 'Current LE' | awk '{ print $3 }'`
            echo "    lvcreate -l $CURRENTLE -n $LVNAME $VGNAME" >> $RESTOREFILE    # create the LV
            echo "    lvchange -a y /dev/$VGNAME/$LVNAME" >> $RESTOREFILE           # activate the LV in the system
            echo "    sleep 3" >> $RESTOREFILE                                      # create the file system
            echo "    mkfs.$DEFAULT_FILESYSTEM_TYPE $i || exit -1" >> $RESTOREFILE             # change a higher file system check count
            echo "    tune2fs -c 10000 $i" >> $RESTOREFILE
        done    

echo
echo "... erstelle die Konfiguration fuer das Restore-Skript von Partition:Verzeichnis $TARSOURCES"

        # format the tar volumes later (in the restore process)
        echo '    for i in $(echo $TARSOURCES)' >> $RESTOREFILE
        echo '    do' >> $RESTOREFILE
        echo '        TARDEV=`echo $i | awk -F '"':' '{ print" '$1' "}'"'`' >> $RESTOREFILE
        echo '        TARTYPE=`echo $i | awk -F '"':' '{ print" '$3' "}'"'`' >> $RESTOREFILE
        echo '        mkfs.$TARTYPE $TARDEV || exit -1' >> $RESTOREFILE
        echo '        tune2fs -c 10000 $TARDEV' >> $RESTOREFILE
        echo '    done' >> $RESTOREFILE

        # the end of the partitioning in the restore script
        echo 'fi' >> $RESTOREFILE
        echo '' >> $RESTOREFILE

        # create the mount point (in the restore script)
        echo 'mkdir -p $RESTOREMNT || ( echo "ERROR: COULD NOT CREATE $RESTOREMNT. CHANGE VAULE *RESTOREMNT* IN $CONFIGFILE ?"; exit -1 )' >> $RESTOREFILE
        echo '' >> $RESTOREFILE


echo      
echo "... erstelle die TAR-Archiv-Backups"
echo

        # SAVE all defined TAR partitions and append the restore script
        j=0;
        for i in $(echo $TARSOURCES)
        do
            j=$(($j+1)) 
            
            # read device names and mount points
            TARDEV=`echo $i | awk -F ':' '{ print $1 }'`
            TARSRC=`echo $i | awk -F ':' '{ print $2 }'`

            # save partitions with tar
            backupname="$j"$(echo $TARSRC | sed 's/\//_/g')
            echo "starte nun: den TAR-Abzug von $TARSRC in die Datei $backupname.tar.bz2"
            OLD_PATH=`pwd`
            cd $TARSRC
            tar -cjf $OLD_PATH/$backupname.tar.bz2 ./
            cd $OLD_PATH
            
            # fuer TARDEV wird spaeter aus der Liste $TARSOURCES das DEVICE zum aktuellen MOUNTPUNKT $i gesucht (etwas kompliziert aber wichtig, da sich die Devicenamen spaeter anpassen lassen)
            echo 'TARDEV=$(for k in $(echo $TARSOURCES); do echo $k | grep ":'$TARSRC'" | awk -F '"':' '{ print "'$1'" }'; done)" >> $RESTOREFILE
            
            # mount and extract the files later
            echo 'echo "... mounte $TARDEV temp. nach $RESTOREMNT fuer den RESTORE"' >> $RESTOREFILE
            echo 'mount $TARDEV $RESTOREMNT || ( echo "ERROR: PROBLEM DURING MOUNTING."; exit -1 )' >> $RESTOREFILE
            echo 'echo "... start RESTORE '$TARSRC' from file '$backupname.tar.bz2'"' >> $RESTOREFILE
            echo 'tar -xpjf $BACKUPDIR/'"$backupname.tar.bz2 -C $RESTOREMNT" >> $RESTOREFILE
            echo 'cd' >> $RESTOREFILE
            echo 'umount $TARDEV' >> $RESTOREFILE
            
        done
        echo '' >> $RESTOREFILE

echo
echo "... erstelle die LVM-Backups"

        # SAVE all defined LVM volumes and append the restore script
        for i in $(echo $LVMSOURCES)
        do
            
            # get names ans sizes of VGs and LVs
            CURRENTLE=`lvdisplay $i | grep 'Current LE' | awk '{ print $3 }'`
            VGNAME=`lvdisplay $i | grep 'VG Name' | awk '{ print $3 }'`
            LVNAME=`lvdisplay $i | grep 'LV Name' | awk '{ print $3 }'`
            # set the name of the logical volumen (use now "lvexample" instead of "/dev/vgexample/lvexample")
            if [[ -n `echo $LVNAME | awk -F '/' '{ print $4 }'` ]]; then LVNAME=`echo $LVNAME | awk -F '/' '{ print $4 }'`; fi
            
            # create a LV for the temporary snapshot
            echo
			echo "... erstelle LVM-Snapshot 'snaptmp' zu " $i
            # create the snapshot ("-s ... Typ ist Snapshot", "-p r ... READ-ONLY-Snapshot anlegen, er kann also selbst nicht veraendert werden", "-L ... max. Groesse fuer Snapshot-Puffer bei Aenderungen im Original", "-n  ... Name des Snapshots")
            lvcreate -s -p r -L 10G -n snaptmp $VGNAME/$LVNAME || (echo "ERROR: COULD NOT CREATE LVM-SNAPSHOT snaptmp !" exit -1)
            mkdir -p /mnt/snapshot_mount/ || (echo "ERROR: COULD NOT CREATE DIRECTORY /mnt/snapshot_mount/ !" exit -1)
            SNAPDEV="/dev/$VGNAME/snaptmp"

            # save the data from the snapshot of the LV (-O (fuer full_Backup); -L BACKUP-LABLE; -z (komprimiert, default Level = 2); -f BACKUP-FILE)
            echo "... sichere die daten des snapshot mittels dump"
			dump -0 -L $LVNAME -z -f $LVNAME.lvm.dump $SNAPDEV

            # try the LV snapshot
            echo
            echo "... pruefe wie viele Aenderungen bisher im Snapshot gegenueber dem Original vorgenommen wurden."
            echo "    Dieser Wert ('Allocated to snapshot') sollte unter 100% sein BZW. es sollte nun kein Eingabe-/Ausgabefehler erscheinen. Ansonsten koennte das Backup defekt auch sein."
            echo
            lvdisplay $SNAPDEV | grep "Allocated to snapshot " 

            # delete the LV snapshot
            echo
			echo "... warte 5 sekunden und loesche wieder den snapshot " $snapdev
            sleep 5
			# retry to remove the snapshot, this can take some loops
            redo='y'
            while [[ $redo = 'y' ]]
			do
                echo "Try to remove the snapshot: $SNAPDEV"; lvremove -f $SNAPDEV; sleep 1; redo='n'
                if [ -e $SNAPDEV ]; then echo "FEHLER: Versuche den Snapshot in einer Sekunde automatisch erneut zu entfernen. Falls es nicht klappt, entfernen Sie ihn bitte per Hand mittels: 'lvremove -f $SNAPDEV'."; redo='y'; fi; sleep 1
            done
        
            # append the restore script
            LVDEV="/dev/$VGNAME/$LVNAME"
            echo 'echo "... start RESTORE of LVM-Volume '$LVDEV' from file '$LVNAME.lvm.dump'"' >> $RESTOREFILE
            echo "mount $LVDEV $RESTOREMNT || (echo 'ERROR: COULD NOT MOUNT $LVDEV ON $RESTOREMNT.'; exit -1)" >> $RESTOREFILE
            echo "cd $RESTOREMNT || ( echo 'ERROR: COULD NOT CHANGE TO THE DIRECTORY "$RESTOREMNT".'; exit -1)" >> $RESTOREFILE
            echo 'restore -rf $BACKUPDIR/'$LVNAME.lvm.dump >> $RESTOREFILE
            echo "cd" >> $RESTOREFILE
            echo "umount $RESTOREMNT" >> $RESTOREFILE
            echo 'set +x' >> $RESTOREFILE
            echo '' >> $RESTOREFILE
            
        done    

	    NameLVMSystem=`mount | grep "on / " | awk '{ print $1 }'`

            # get messages for the user, aber restoring
            echo "echo ''" >> $RESTOREFILE
            echo "echo 'THE RESTORE IS FINISHED.'" >> $RESTOREFILE
            echo "echo '************************'" >> $RESTOREFILE
            echo "echo 'Verify the whole system now.'" >> $RESTOREFILE
            echo "echo 'PLease note: This restore DOES NOT RESTORE ALL FILES and PARTITIONS of the whole system.'" >> $RESTOREFILE
            echo "echo 'The backup script was written to save only the system partitions for a disaster recovery.'" >> $RESTOREFILE
            echo "echo 'Please use other backup system to restore missing files (e.g. big data files or HOME-Directorys).'" >> $RESTOREFILE
            echo "echo 'In the case that you change the network cards (hardware), do not forget to update (or delete) the file: .../etc/udev/rules.d/70-persistent-net.rules'" >> $RESTOREFILE
            echo "echo 'If you reinstall the partitions: Please remove missed partition from /etc/fstab and check the (new) UUIDs of the system.'" >> $RESTOREFILE
            echo "echo 'WARNING: Systems, which using the device mapper can be have problems, by using partitions like /dev/sda1 in /etc/fstab. Please use the UUIDs of the partitions.'" >> $RESTOREFILE
            echo "echo" >> $RESTOREFILE            
            echo "echo 'PLEASE NOTE: In case of problems during booting: CHECK PARTITIONS in /etc/fstab AND REINSTALL THE BOOTLOADER (GRUB).'" >> $RESTOREFILE
            echo "echo" >> $RESTOREFILE
            echo "echo 'A short EXAMPLE (with grub2, the whole system is on /dev/sda, /boot is on /dev/sda1, / is on the LVM device $NameLVMSystem):'" >> $RESTOREFILE
            echo "echo" >> $RESTOREFILE
            echo "echo '    mkdir -p /mnt/custom'" >> $RESTOREFILE            
            echo "echo '    less .../"${CONFIGFILE}"   # to see the partition(s) and LVM name(s) of the backup for the next steps'" >> $RESTOREFILE
            echo "echo '    mount $NameLVMSystem /mnt/custom'" >> $RESTOREFILE
            echo "echo '    mount /dev/sda1 /mnt/custom/boot'" >> $RESTOREFILE
            echo "echo '    for i in dev sys proc; do mount -o bind /\$i /mnt/custom/\$i; done'" >> $RESTOREFILE
            echo "echo '    chroot /mnt/custom /bin/bash'" >> $RESTOREFILE
            echo "echo '    mv /boot/grub /boot/grub_OLD'" >> $RESTOREFILE
            echo "echo '    mkdir /boot/grub'" >> $RESTOREFILE
            echo "echo '    chmod 755 /boot/grub'" >> $RESTOREFILE
            echo "echo '    grub-install /dev/sda'" >> $RESTOREFILE
            echo "echo '    update-grub'" >> $RESTOREFILE
			echo "echo '    exit                       # to exit the chroot environment'" >> $RESTOREFILE
            echo "echo '    blkid                      # to see the UUIDs and device names for changing the /etc/passwd'" >> $RESTOREFILE
            echo "echo '    vim /mnt/custom/etc/fstab  # to check all partition names, DEACTIVATE unrecovered and UNNECESSARY partitions, change the UUIDs to the given names from the blkid command'" >> $RESTOREFILE	    
            echo "echo '    vim /mnt/custom/etc/initramfs-tools/conf.d/resume  # OPTIONAL: change the UUID of the SWAP-Partition to the UUIDs from the blkid command'" >> $RESTOREFILE
            echo "echo" >> $RESTOREFILE
            echo '' >> $RESTOREFILE
            
			# make the restore script executable
            chmod 744 $RESTOREFILE

echo
echo "ENDE DES BACKUP-LAUFES !!! - Folgende Dateien wurden erstellt:"
echo

			# list all files of the Backup
			ls -lhR $BACKUPDIR

echo
echo "... erstelle nun noch die Pruefsummendatei und sende Sie auch per E-Mail an: $mailNotificationAddress"

			# send filenames, checksums and configuration by mail
			echo -e "DATEIEN DES BACKUPS DES SERVERS $HOSTNAME - STAND BACKUPTIME\n" > $BACKUPDIR/backup_files.txt
			ls -lhR $BACKUPDIR >> $BACKUPDIR/backup_files.txt
			echo -e "\nPRUEFSUMMEN DES BACKUPS:\n" >> $BACKUPDIR/backup_files.txt
			find $BACKUPDIR -type f -exec /usr/bin/md5sum {} \; >> $BACKUPDIR/backup_files.txt
			echo -e "\nKONFIGURATIONSDATEI DES BACKUPS:\n" >> $BACKUPDIR/backup_files.txt
			cat ${CONFIGPATH}/${CONFIGFILE} >> $BACKUPDIR/backup_files.txt
			cat $BACKUPDIR/backup_files.txt | /usr/bin/mail -s "md5summen der Backups von $HOSTNAME Stand: $BACKUPTIME" $mailNotificationAddress

# last messages and exit
echo
echo "+++ DAS BACKUP WURDE NUN DURCHGEFUEHRT. +++"
echo "+++ BITTE PRUEFEN SIE OB DIE OBEREN BACKUP-GROESSEN AUCH PLAUSIBEL SIND. +++"
echo "+++ Die *.dump und *.tar.bz2 Dateien enthalten die Inhalte der zu sichernden Partitionen. +++"
echo "+++ Das Restore-Skript zum Testen und fuer den Ernstfall, wurde erstellt unter: $RESTOREFILE +++"
echo

exit 0

