# Restic Backups

This is a custom repository for running [https://restic.net/](https://restic.net/) backups as a [restic user](https://restic.readthedocs.io/en/stable/080_examples.html#backing-up-your-system-without-running-restic-as-root) instead of root.

## Install

+ Download the latest release from release page or run the following.

```bash
curl -L https://github.com/DeepInThought/restic-scripts/releases/download/v0.1.0/restic-scripts.tar.bz2 | bunzip2 >${HOME}/.scripts/restic-scripts
```

+ Run the [restic-install.sh](restic-install.sh) script or visit their [GitHub](https://github.com/restic/restic/releases/latest) for downloading.  The script includes setup of the restic user and gives backups permissions.

```bash
chmod +x restic-install.sh
sudo ./restic-install.sh
```

+ Add the [restic_alises](restic_aliases) snipplet below to your ~/.bashrc or ~/.bash_aliases to simplify calling of restic.

```bash
if [ -f ~/.scripts/restic-scripts/restic_alises ]; then
    . ~/.scripts/restic-scripts/restic_aliases
fi
```

+ Initialize your backup repository.

```bash
sudo ~restic/bin/restic init --repo /media/restic/backups/${HOSTNAME}/home
```

Keep note of the password used!  Add it to the [.backup_secrets](.backup_secrets) file.  Make sure it's read writable to you only.

```bash
chmod 640 .backup_secrets
```

+ Update the [restic-homedir.conf](restic-homedir.conf) and [restic-corefolders.conf](restic-corefolders.conf) files to match your settings.  I split home and core files into two different backups, but this is not required.
  + SCRIPT_DIR is used for all of the files.  Keep default to align with the repository defaults.
  + GET_LATEST_HOME_EXCLUDES scans rsync best practice for home folder backup excludes.
  + RESTIC_MOUNTPOINT is the directory used when mounting backups for viewing.  Please not you will need to create the mountpoint first, see below.
  
  ```bash
  sudo mkdir -p /mnt/restic
  ```
  
  + RESTIC_PASSWORD_FILE is the location of the backup password.
  + RESTIC_PATH is where the executable is located.
  + RESTIC_REPOSITORY is where you did the initialize of the backup.
  + BACKUP_EXCLUDE_FILE is used for excludes like [.backup_excludes](.backup_excludes).
  + BACKUP_PATHS is what folders are included for backups.
  + RETENTION_POLICY is how long to keep backups.
  + SNAPSHOT_TITLE should reflect nature of the backup.
  
+ Run backups via [restic_alises](restic_aliases).

```bash
bu-homefolder
bu-corefolders
```

+ Mount backups

```bash
# Set the environment to the home.conf and mount.
restic-env-home
bu-mnt-backup
```
