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

+ Add the [restic_alises](restic_alises) snipplet below to your ~/.bashrc or ~/.bash_aliases to simplify calling of restic.

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

+ Update the .conf files to match your settings.  I split home and core files into two different backups, but this is not required.

+ Run backups via aliases.

```bash
bu-homefolder
bu-corefolders
```

+ View backups

```bash
# Set the environment to the home .conf and mount.
restic-env-home
bu-mnt-backup
```
