# PcOnlineBackup

Some scripts for backup and restore of linux servers. The scripts can be used to save the systems during running the system. But your system should be run on a LVM volume.

The backup can be started automaticly by cron, also.

How to use:

Download the files to different partition.
Change the config file "backup_gpt.cfg" OR "backup_mbr.cfg" and optional the values in "mount_backup_sshfs.sh".

Install all necessary software like:
* bzip2 
* parted 
* dump

Run "backup_system_gpt.sh" or "backup_system_mbr.sh" to start the backup.

Thomas Mueller <><