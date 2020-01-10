# PcOnlineBackup

Some scripts for backup and restore of linux servers. The scripts can be used to save the systems during running the system. But your system should be run on a LVM volume.

Example system configuration:

	/dev/sda1	-> /boot/efi
	/dev/sda2	-> linux-swap
	/dev/sda1	-> physical volume for LVM
	/dev/sdb	-> /system_backups
	
	/dev/mapper/sda-system -> /
	/dev/mapper/sda-varlog -> /var/log

	The locical volumes "sda-system" and "/dev/mapper/sda-varlog" can 
	be saved by dump with this script.
	To save "/boot/efi" define the TAR backup on this script.
	All backups (and this scripts) can be saved on "/dev/sdb".

The backup can be started automaticly by cron, also.
You can define the number of backups to keep, as well.

How to use:

* Download the files to an different partition.
* Change the config file "backup_gpt.cfg" OR "backup_mbr.cfg".
* Optional, set the values in "mount_backup_sshfs.sh".

Install all necessary software like:
* bzip2 
* parted 
* dump

Depending on your system, run "backup_system_gpt.sh" OR "backup_system_mbr.sh" to start the backup.

Thomas Mueller <><