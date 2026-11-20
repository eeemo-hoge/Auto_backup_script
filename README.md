# Auto_backup_script

A simple project for backing up data to multiple hard drives. It was originally
created for personal use and is shared here in the hope that it may be useful
to others.

## How to use ??
1. PATH. if your directory structure is like, /usr/lccal/bin/backup/ then, write ".bashrc" to, "alias backup-all='sudo bash /usr/local/bin/backup/backup-all.sh'" and type "source ~/.bashrc"
2. solve permission problem. (chmod 755 or etc.)
3. re-write the backup location directory where you want. you should re-write end of the line of "backup.sh" "backup2.sh" "backup3.sh" respectively.
4. just in case or, as your preference, re-write "backup-all.sh" "backup-common.sh" as well to, what scripts files you run or etc.
5. and run "backup.all". scripts let you backup to your hard disk drives multiple. "buckupall -ddry-run" is do not backup but run.
6. if you want to backup to more hard disc drives then, dumplicate "backup.sh" or "bachup2.sh" or etc and re-write "backup-all.sh" "backup-common" respectively so that identify location or path, copy path etc. 

## This will show how it works
![description](https://github.com/eeemo-hoge/Auto_backup_script/tree/main/images/backup_script_image.png)

## LISCENSE 


license is "[LICENSE](LICENSE)"
