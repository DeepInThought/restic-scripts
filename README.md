# Restic Backups

This is a custom repository for running [https://restic.net/](https://restic.net/) backups as a [restic user](https://restic.readthedocs.io/en/stable/080_examples.html#backing-up-your-system-without-running-restic-as-root) instead of root.

## Install

1. Run the [restic-install.sh](restic-install.sh) script or visit their [GitHub](https://github.com/restic/restic/releases/latest) for downloading.  The script includes setup of the restic user and gives backups permissions.  It assumes you have git installed.

2. Add the [restic_alises](restic_alises) snipplet below to your ~/.bashrc or ~/.bash_aliases to simplify calling of restic.

```bash
if [ -f ~/.scripts/restic-scripts ]; then
    . ~/.scripts/restic-scripts/restic_aliases
fi
```

3. Initialize your backup repository.

```bash
sudo ~restic/bin/restic init --repo /media/restic/backups/${HOSTNAME}/home
```

Keep note of the password used!  Add it to the [.backup_secrets](.backup_secrets) file.  Make sure it's read writable to you only.

```bash
chmod 640 .backup_secrets
```

4. Update the .conf files to match your settings.  I split home and core files into two different backups, but this is not required.

5. Run backups via aliases.

```bash
bu-homefolder
bu-corefolders
```

6. View backups

```bash
# Set the environment to the home .conf and mount.
restic-env-home
bu-mnt-backup
```
