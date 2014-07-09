# rbackup #

Deeply simple Perl+rsync script with over a decade of use on multiple OSes.

Featuring:

 - No dependencies other than `rsync`, `svn` (optional) and `mysqldump` (optional)
 - Support for dumping MySQL and SVN databases.
 - Very few lines of code, making it easy to hack in features you need.

Not featuring:

 - Revisions
 - Warning emails if the backup failed (though we do write .lastbackuptime and sync it)
 - Any scheduling support
 - Destination compression (you can use rsync --compress)
 - Cloud things like Amazon S3

## Usage ##

 1. Edit `rbackup.conf` to your exacting standards.
 2. Test with: `perl rbackup.pl`
 3. Optional: copy `rbackup.conf` to `/etc` if your OS has that directory.
 4. If you like what happened, set it up in a cronjob.


