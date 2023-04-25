#!/bin/bash
#
# save partitions and LVM volumes with snapshots on running systems
# nessesary package on debian: bzip2 parted dump gdisk lvm2 tar
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

# den Suchpfad fuer die Programme erweitern (noetig bei Aufruf von cron)
export PATH=$PATH:/sbin

# KONFIGURATIONS-DATEI DEFINIEREN UND LADEN
CONFIGPATH="/system_backups/"
CONFIGFILE="backup_gpt.cfg"
source ${CONFIGPATH}/${CONFIGFILE} || exit -1

# wait seconds before staring
if [ -n "${randomTimeDiffer}" ]; then (set -x; sleep $((${RANDOM}/${randomTimeDiffer})) ); fi

# start a mount script for the backup
if [ -n "${startBeforeBackup}" ]; then source "${startBeforeBackup}"; fi

# remove old backups
if [ -n "${keepOnlyNumberOfBackups}" ]; then cd ${BACKUPMAINDIR} || exit; ls -1dh BACKUP_* | head -n -${keepOnlyNumberOfBackups} | xargs rm -rvf; fi
if [ -n "${deleteBackupOlderThanDays}" ]; then for i in ${BACKUPMAINDIR}/BACKUP_*; do /usr/bin/find $i -maxdepth 0 -type d -mtime "+${deleteBackupOlderThanDays}" -exec rm -rfv {} \; ; done; fi

# Erklaerungen ausgeben
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

        # erstelle das Backup-Verzeichnis und gehe dort hin
        mkdir -p $BACKUPDIR
        cp ${CONFIGPATH}/${CONFIGFILE} ${BACKUPDIR}/${CONFIGFILE}        
        cd $BACKUPDIR || (echo "ERROR: BACKUP DIRECTORY BACKUPDIR NOT FOUND !" exit -1)

echo
echo "... starte neue Datei $RESTOREFILE "

        # starte das RESTORE-SKRIPT
        echo '#!/bin/bash' > $RESTOREFILE
        echo '#' >> $RESTOREFILE
        echo '# automatisch erstelltes RESTORE-Skript' >> $RESTOREFILE
        echo '# Fragen an Thomas Mueller' >> $RESTOREFILE
        echo '#' >> $RESTOREFILE
        echo '' >> $RESTOREFILE
        echo 'source ./'${CONFIGFILE}' || (echo "ERROR: ./'${CONFIGFILE}' NOT FOUND !" exit -1)' >> $RESTOREFILE
        echo '' >> $RESTOREFILE
        echo 'BACKUPDIR=`pwd`' >> $RESTOREFILE

echo        
echo "... schreibe erste Bloecke sowie die Partitionen-Konfiguration in Computer- und Menschenlesbarer Form"

        mkdir -p config

        # sichere die Partitionen-Konfiguration        
        sgdisk -b config/partitions.sgdisk $BACKUPDISC                      # sichern der GPT fuer das automatisches Restore
        gdisk -l $BACKUPDISC > config/partition_informations_gdisk.txt      # sichern einiger Partitioneninfos als spaetere Referenz zum Nachlesen
        parted $BACKUPDISC unit s print free > config/partitions.parted     # sichern einiger Partitioneninfos als spaetere Referenz zum Nachlesen
        parted $BACKUPDISC print free >> config/partitions.parted           # sichern einiger Partitioneninfos als spaetere Referenz zum Nachlesen
        mount > config/mounted_partitions_durring_backup.txt                # sichern der aktiven Mounts als spaetere Referenz zum Nachlesen
        cp /proc/partitions config/proc_partitions.txt                      # sichern einiger Partitioneninfos als spaetere Referenz zum Nachlesen
        
        #
        ## Erstelle ein Skript zum Erstellen der Partitionen
        #
        
        # INFO AUSGEBEN
        echo '' >> $RESTOREFILE
        echo 'echo ' >> $RESTOREFILE
        echo 'echo "!!! WARNING: READ THIS CARFULY !!!"' >> $RESTOREFILE
        echo 'echo' >> $RESTOREFILE
        echo 'echo "You can change some settings for the restore process in the file: $BACKUPDIR/'${CONFIGFILE}' ."' >> $RESTOREFILE        
        echo 'echo -n "Should I try to ERASE THE HARD DISK and install the old partition table now (recommanded only if the old partitions are missed) ? (y/n) "' >> $RESTOREFILE

        # Benutzerabfrage einlesen und auswerten
        echo 'read USERINPUT' >> $RESTOREFILE
        echo 'if [ $USERINPUT = y ]' >> $RESTOREFILE
        echo 'then' >> $RESTOREFILE
        echo '    if [[ -n `df -h . | grep "$BACKUPDISC"` ]]' >> $RESTOREFILE
        echo '    then' >> $RESTOREFILE
        echo '        echo "ERROR: IT LOOKS LIKE YOUR BACKUP IS ON THE SAME DEVICE LIKE YOU WANT TO REINSTALL NOW. I STOP NOW."' >> $RESTOREFILE
        echo '        exit -1' >> $RESTOREFILE
        echo '    fi' >> $RESTOREFILE
        
        # Partitionentabelle neu schreiben, pruefen und ausgeben
        echo '    set -x' >> $RESTOREFILE
        echo '    parted -s $BACKUPDISC mklabel gpt' >> $RESTOREFILE
        echo '    sgdisk -g -l $BACKUPDIR/config/partitions.sgdisk $BACKUPDISC' >> $RESTOREFILE
        echo '    sleep 3' >> $RESTOREFILE
        echo '    sfdisk -v $BACKUPDISC' >> $RESTOREFILE
        echo '    gdisk -l $BACKUPDISC' >> $RESTOREFILE


echo
echo "... schreibe LVM-Konfiguration in Menschenlesbarer Form"

        # sichere die vollstaendigen LVM-Konfigurationen fuer evtl. spaetere manuell zu loesende Probleme
        pvdisplay -v > config/pvdisplay.txt
        vgdisplay -v > config/vgdisplay.txt
        lvdisplay -v > config/lvdisplay.txt
        if [ -e "/etc/blkid.tab" ]; then cp /etc/blkid.tab config/blkid.tab; else blkid > config/blkid.txt; fi

echo
echo "... erstelle LVM-Konfiguration fuer das Restore-Skript"

        # PV-KONFIGURATION im Restore-Skript erstellen
        echo '    pvcreate $PVDEVS' >> $RESTOREFILE

        # VG-KONFIGURATION im Restore-Skript erstellen
        for i in $(echo $LVMSOURCES); do
            VGNAME=`lvdisplay $i | grep 'VG Name' | awk '{ print $3 }'`
            PESIZE=`vgdisplay $VGNAME | grep 'PE Size' | awk '{ print $3 $4 }' | sed 's/,00//' | sed 's/\.00//' | sed 's/iB$//'`
            COMMAND="vgcreate -s $PESIZE $VGNAME "'$PVDEVS'
            # schreibe die Zeile zum Erstellen des VG nur einmal in das Skript
            if [[ -z `grep "$COMMAND" $RESTOREFILE` ]]
            then
                echo "    $COMMAND" >> $RESTOREFILE
            fi
        done
            
        # LV-KONFIGURATION im Restore-Skript erstellen  
        for i in $(echo $LVMSOURCES); do
            VGNAME=`lvdisplay $i | grep 'VG Name' | awk '{ print $3 }'`
            LVNAME=`lvdisplay $i | grep 'LV Name' | awk '{ print $3 }'`
            # LVNAME-Korrektur, einige Versionen haben den kompletten Pfad (also anstatt lvexample heisst es dort /dev/vgexample/lvexample)
            if [[ -n `echo $LVNAME | awk -F '/' '{ print $4 }'` ]]; then LVNAME=`echo $LVNAME | awk -F '/' '{ print $4 }'`; fi
            CURRENTLE=`lvdisplay $i | grep 'Current LE' | awk '{ print $3 }'`
            echo "    lvcreate -l $CURRENTLE -n $LVNAME $VGNAME" >> $RESTOREFILE    # erstelle das LV
            echo "    lvchange -a y /dev/$VGNAME/$LVNAME" >> $RESTOREFILE           # aktiviere das LV (ansonsten ist es evtl. erst nach dem naechsten Reboot aktiv)
            echo "    sleep 3" >> $RESTOREFILE                                      # nur zur Sicherheit, dass die Device-Pfade auch angelegt werden
            echo "    mkfs.$DEFAULT_FILESYSTEM_TYPE $i || exit -1" >> $RESTOREFILE  # lege Dateisystem an, oder breche ab
            echo "    tune2fs -c 10000 $i" >> $RESTOREFILE
        done    

echo
echo "... erstelle die Konfiguration fuer das Restore-Skript von Partition:Verzeichnis $TARSOURCES"

        # Teil zur Formatierung der TAR-Partitionen fuer das Restore-Skript
        echo '    for i in $(echo $TARSOURCES)' >> $RESTOREFILE
        echo '    do' >> $RESTOREFILE
        echo '        TARDEV=`echo $i | awk -F '"':' '{ print" '$1' "}'"'`' >> $RESTOREFILE
        echo '        TARTYPE=`echo $i | awk -F '"':' '{ print" '$3' "}'"'`' >> $RESTOREFILE
        echo '        mkfs.$TARTYPE $TARDEV || exit -1' >> $RESTOREFILE
        echo '        tune2fs -c 10000 $TARDEV' >> $RESTOREFILE
        echo '    done' >> $RESTOREFILE
        echo '    set +x' >> $RESTOREFILE


        # beende den Abschnitt zum Erstellen der Partitionen + Formatierungen im Restore-Skript
        echo 'fi' >> $RESTOREFILE
        echo '' >> $RESTOREFILE

        # Abschnitt zum Erstellen des temp. Mount-Punkt im Skript
        echo 'mkdir -p $RESTOREMNT || ( echo "ERROR: COULD NOT CREATE $RESTOREMNT. CHANGE VAULE *RESTOREMNT* IN ./backup.cfg ?"; exit -1 )' >> $RESTOREFILE
        echo '' >> $RESTOREFILE


echo      
echo "... erstelle die TAR-Archiv-Backups"
echo

        # durchlaufe alle per TAR abzuziehenden Partitionen und erstelle die Backups + Restore-Aufrufe
        j=0;
        for i in $(echo $TARSOURCES)
        do
            # laufende Nummer als Ergaenzung des Dateinamens
            j=$(($j+1)) 
            
            # teile TARSOURCES in DEVICE-NAME und MOUNT-PUNKT
            TARDEV=`echo $i | awk -F ':' '{ print $1 }'`
            TARSRC=`echo $i | awk -F ':' '{ print $2 }'`

            # sichern per TAR
            backupname="$j"$(echo $TARSRC | sed 's/\//_/g')
            echo "starte nun: den TAR-Abzug von $TARSRC in die Datei $backupname.tar.bz2"
            OLD_PATH=`pwd`
            cd $TARSRC
            tar -cjf $OLD_PATH/$backupname.tar.bz2 ./
            cd $OLD_PATH
            
            #
            # Skript-Teil fuer das RESTORE des TARs
            #
            
            # fuer TARDEV wird spaeter aus der Liste $TARSOURCES das DEVICE zum aktuellen MOUNTPUNKT $i gesucht (etwas kompliziert aber wichtig, da sich die Devicenamen spaeter anpassen lassen)
            echo 'TARDEV=$(for k in $(echo $TARSOURCES); do echo $k | grep ":'$TARSRC'" | awk -F '"':' '{ print "'$1'" }'; done)" >> $RESTOREFILE
            
            # mounte und entpacke die Daten
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

        # durchlaufe alle per LVM-Snapshot abzuziehenden Partitionen und erstelle die Backups + Restore-Aufrufe
        for i in $(echo $LVMSOURCES)
        do
            
            # ermittele die Namen der VGs und LVs und die Groesse der LVs
            CURRENTLE=`lvdisplay $i | grep 'Current LE' | awk '{ print $3 }'`
            VGNAME=`lvdisplay $i | grep 'VG Name' | awk '{ print $3 }'`
            LVNAME=`lvdisplay $i | grep 'LV Name' | awk '{ print $3 }'`
            # Korrektur des "LV Name" einige Versionen haben den kompletten Pfad (also anstatt lvexample heisst es dort /dev/vgexample/lvexample)
            if [[ -n `echo $LVNAME | awk -F '/' '{ print $4 }'` ]]; then LVNAME=`echo $LVNAME | awk -F '/' '{ print $4 }'`; fi
            
            # erstelle ein temp. LV fuer die LVM-Snapshots
            echo
			echo "... erstelle LVM-Snapshot 'snaptmp' zu " $i
            # erstelle Snapshot "-s ... Typ ist Snapshot", "-p r ... READ-ONLY-Snapshot anlegen, er kann also selbst nicht veraendert werden", "-L ... max. Groesse fuer Snapshot-Puffer bei Aenderungen im Original", "-n  ... Name des Snapshots" 
            lvcreate -s -p r -L 10G -n snaptmp $VGNAME/$LVNAME || (echo "ERROR: COULD NOT CREATE LVM-SNAPSHOT snaptmp !" exit -1)
            mkdir -p /mnt/snapshot_mount/ || (echo "ERROR: COULD NOT CREATE DIRECTORY /mnt/snapshot_mount/ !" exit -1)
            SNAPDEV="/dev/$VGNAME/snaptmp"

            # sichere den Inhalt des LVM-Volumens ueber dessen Snapshot 
            echo "... sichere die daten des snapshot mittels dump"
            # -O (fuer full_Backup); -L BACKUP-LABLE; -z (komprimiert, default Level = 2); -f BACKUP-FILE
			dump -0 -L $LVNAME -z -f $LVNAME.lvm.dump $SNAPDEV

            # teste den LVM-Snapshot
            echo
            echo "... pruefe wie viele Aenderungen bisher im Snapshot gegenueber dem Original vorgenommen wurden."
            echo "    Dieser Wert ('Allocated to snapshot') sollte unter 100% sein BZW. es sollte nun kein Eingabe-/Ausgabefehler erscheinen. Ansonsten koennte das Backup defekt auch sein."
            echo
            lvdisplay $SNAPDEV | grep "Allocated to snapshot " 

            # loesche den LVM-Snapshot wieder
            echo
			echo "... warte 5 sekunden und loesche wieder den snapshot " $snapdev
            sleep 5
			# versuche in einer Schleife immer wieder den LVM-Snapshot zu loeschen (dies kann einige Anlaeufe dauern)
            redo='y'
            while [[ $redo = 'y' ]]
			do
                echo "Try to remove the snapshot: $SNAPDEV"; lvremove -f $SNAPDEV; sleep 1; redo='n'
                if [ -e $SNAPDEV ]; then echo "FEHLER: Versuche den Snapshot in einer Sekunde automatisch erneut zu entfernen. Falls es nicht klappt, entfernen Sie ihn bitte per Hand mittels: 'lvremove -f $SNAPDEV'."; redo='y'; fi; sleep 1
            done
        
            # erstelle den Teil des RESTORE-SKRIPTs fuer das Wiederherstellen des LVM-Backups
            LVDEV="/dev/$VGNAME/$LVNAME"
            echo 'echo "... start RESTORE of LVM-Volume '$LVDEV' from file '$LVNAME.lvm.dump'"' >> $RESTOREFILE
            echo "mount $LVDEV $RESTOREMNT || (echo 'ERROR: COULD NOT MOUNT $LVDEV ON $RESTOREMNT.'; exit -1)" >> $RESTOREFILE
            echo "cd $RESTOREMNT || ( echo 'ERROR: COULD NOT CHANGE TO THE DIRECTORY "$RESTOREMNT".'; exit -1)" >> $RESTOREFILE
            echo 'restore -rf $BACKUPDIR/'$LVNAME.lvm.dump >> $RESTOREFILE
            echo "cd" >> $RESTOREFILE
            echo "umount $RESTOREMNT" >> $RESTOREFILE
            echo '' >> $RESTOREFILE
            
        done    

# start a script at the end of backup, if the script exists
if [ -n "${startAfterBackup}" ]; then echo; set -x; ${startAfterBackup}; set +x; fi

        NameLVMSystem=`mount | grep "on / " | awk '{ print $1 }'`

        # Infos an den Benutzer geben, dass der Restore fertig ist und setzen des Execute-Flag zum Skript.
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
        echo "echo 'A short EXAMPLE (with grub2, the whole system is on /dev/sda, /boot/efi is on /dev/sda1, swap is on /dev/sda2 AND / is on the LVM device $NameLVMSystem):'" >> $RESTOREFILE
        echo "echo" >> $RESTOREFILE
        echo "echo 'To RESTORE the grub on a GPT partition, boot a Linux like the SystemRescueCD in EFI mode, before you run the following commands:'" >> $RESTOREFILE
        echo "echo" >> $RESTOREFILE
        echo "echo '    mkdir -p /mnt/custom'" >> $RESTOREFILE
        echo "echo '    parted /dev/sda print      # to see the new partition numbers'" >> $RESTOREFILE
        echo "echo '    mkswap /dev/sda2           # warning, use the right partition number here'" >> $RESTOREFILE
        echo "echo '    less .../"${CONFIGFILE}"   # to see the old partition(s) and LVM name(s) of the backup for the next steps'" >> $RESTOREFILE
        echo "echo '    mount $NameLVMSystem /mnt/custom'" >> $RESTOREFILE
        echo "echo '    mount /dev/sda1 /mnt/custom/boot/efi'" >> $RESTOREFILE
        echo "echo '    for i in dev sys proc; do mount -o bind /\$i /mnt/custom/\$i; done'" >> $RESTOREFILE
        echo "echo '    chroot /mnt/custom /bin/bash'" >> $RESTOREFILE
        echo "echo '    update-grub'" >> $RESTOREFILE
        echo "echo '    grub-install'" >> $RESTOREFILE
        echo "echo '    exit                       # to exit the chroot environment'" >> $RESTOREFILE
        echo "echo '    blkid                      # to see the UUIDs and device names for changing the /etc/passwd'" >> $RESTOREFILE
        echo "echo '    vim /mnt/custom/etc/fstab  # to check all partition names, DEACTIVATE unrecovered and UNNECESSARY partitions, change the UUIDs to the given names from the blkid command'" >> $RESTOREFILE	    
        echo "echo '    vim /mnt/custom/etc/initramfs-tools/conf.d/resume  # OPTIONAL: change the UUID of the SWAP-Partition to the UUIDs from the blkid command'" >> $RESTOREFILE
        echo "echo" >> $RESTOREFILE
        echo '' >> $RESTOREFILE

        chmod 744 $RESTOREFILE

echo
echo "ENDE DES BACKUP-LAUFES !!! - Folgende Dateien wurden erstellt:"
echo

        # dem Benutzer die Dateien des Backups anzeigen
        ls -lhR $BACKUPDIR

echo
echo "... erstelle nun noch die Pruefsummendatei und sende Sie auch per E-Mail an: $mailNotificationAddress"

        # Dateinamen, Pruefsummen und Konfiguration per E-Mail senden.
        echo -e "DATEIEN DES BACKUPS DES SERVERS $HOSTNAME - STAND BACKUPTIME\n" > $BACKUPDIR/backup_files.txt
        ls -lhR $BACKUPDIR >> $BACKUPDIR/backup_files.txt
        echo -e "\nPRUEFSUMMEN DES BACKUPS:\n" >> $BACKUPDIR/backup_files.txt
        find $BACKUPDIR -type f -exec /usr/bin/md5sum {} \; >> $BACKUPDIR/backup_files.txt
        echo -e "\nKONFIGURATIONSDATEI DES BACKUPS:\n" >> $BACKUPDIR/backup_files.txt
        cat ${CONFIGPATH}/${CONFIGFILE} >> $BACKUPDIR/backup_files.txt
        cat $BACKUPDIR/backup_files.txt | /usr/bin/mail -s "md5summen der Backups von $HOSTNAME Stand: $BACKUPTIME" $mailNotificationAddress

# letzte Infos an den Benutzer ausgeben
echo
echo "+++ DAS BACKUP WURDE NUN DURCHGEFUEHRT. +++"
echo "+++ BITTE PRUEFEN SIE OB DIE OBEREN BACKUP-GROESSEN AUCH PLAUSIBEL SIND. +++"
echo "+++ Die *.dump und *.tar.bz2 Dateien enthalten die Inhalte der zu sichernden Partitionen. +++"
echo "+++ Das Restore-Skript zum Testen und fuer den Ernstfall, wurde erstellt unter: $RESTOREFILE +++"
echo

exit 0

