#!/usr/bin/env bash
#? Modified from https://gist.github.com/jeetsukumaran/61ff0033360174cda99ed3b444ba6dac
### restic-backup.sh ###
#? My version https://gist.github.com/DeepInThought/67d3a4fd42d3ec43e85c5fd5966c0944
#* bu: Backup data to repository.
#
#* Type 'bu --help' for help on actions and options.
#
#* Configuration of 'bu' is done via environmental variables which can be set by user
#* in a particular session or saved to a file and read by 'bu'.
#
#* Examples of backup configuration files:
#
#*   S3 remote repository:
#
#*       export AWS_ACCESS_KEY_ID="your-Wasabi-Access-Key”
#*       export AWS_SECRET_ACCESS_KEY="your-Wasabi-Secret-Key”
#*       export RESTIC_REPOSITORY="s3:https://s3.wasabisys.com/repo-name"
#*       export RESTIC_PASSWORD="speakfriendandenter"
#*       export BACKUP_PATHS="$HOME/projects"
#*       export RETENTION_POLICY="--keep-daily=31 --keep-monthly=12 --keep-yearly=3"
#*       export SNAPSHOT_TITLE="primary_work"
#
#*   B2 remote repository:
#
#*       export B2_ACCOUNT_ID="your-b2-account-id"
#*       export B2_ACCOUNT_KEY="your-b2-account-key"
#*       export RESTIC_REPOSITORY="b2:repo-name"
#*       export RESTIC_PASSWORD="speakfriendandenter"
#*       export BACKUP_PATHS="$HOME/projects"
#*       export RETENTION_POLICY="--keep-daily=31 --keep-monthly=12 --keep-yearly=3"
#*       export SNAPSHOT_TITLE="primary_work"
#
#*   Local Filesystem repository:
#
#*       export RESTIC_REPOSITORY="/media/peregrine/STORAGE1/backups"
#*       export RESTIC_PASSWORD="speakfriendandenter"
#*       export BACKUP_PATHS="$HOME/projects"
#*       export RETENTION_POLICY="--keep-daily=31 --keep-monthly=12 --keep-yearly=3"
#*       export SNAPSHOT_TITLE="primary_work"
#
#* Examples of usage:
#
#*   $ bu -c primary-backup.conf init            # create a new repository
#*   $ bu -c primary-backup.conf backup purge    # backup and cleanup
#*   $ bu -c primary-backup.conf list            # list snapshots
#*   $ bu -c primary-backup.conf check           # check repository integrity
#
# Adapted from:
#
#   https://github.com/erikw/restic-systemd-automatic-backup
#
# Copyright (c) 2018 Jeet Sukumaran
#
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#* Log start time
START_TIME="$(date +"%Y-%m-%d %H:%M:%S")"
echo "-bu: Starting on ${HOSTNAME} at: $START_TIME"

#* Exit on failure, pipe failure
# set -e -o pipefail

#* Clean up lock if we are killed.
#* If killed by systemd, like $(systemctl stop restic), then it kills the whole
#* cgroup and all it's subprocesses. However if we kill this script ourselves,
#* we need this trap that kills all subprocesses manually.
exit_hook() {
    echo "-bu: In exit_hook(), being killed" >&2
    jobs -p | xargs kill
    $RESTIC_PATH unlock
}
trap exit_hook INT TERM

error_exit() {
    if [[ ! -z $1 ]]; then
        echo "-bu: $1 returned non-zero exit code: terminating"
    fi
    # jobs -p | xargs kill
    # $RESTIC_PATH unlock 2>/dev/null 1>/dev/null
    exit 1
}

ACTION_CMDS="init backup purge list unlock rebuild prune check"
function join_by() {
    local IFS="$1"
    shift
    echo "$*"
}
show_help() {
    echo "usage: bu [-c CONFIGURATION-FILE] [OPTIONS] ($(join_by \| $ACTION_CMDS))"
    echo ""
    echo "Backup data to a repository."
    echo ""
    echo "Actions:"
    echo ""
    echo "  init              Initialize (create) the repository."
    echo "  backup            Backup data to repository."
    echo "  purge             Apply dereferencing policy ('forget') and prune."
    echo "  list              List snapshots in repository."
    echo "  check             Check the repository."
    echo "  unlock            Unlock a repository in a stale locked state."
    echo "  rebuild           Rebuild the repository index."
    echo "  prune             Prune the repository."
    echo ""
    echo "Options:"
    echo ""
    echo "  -h, --help        Show help and exit."
    echo "  -c, --config      Path to file with configuration environmental"
    echo "                    variables declared for export. If not specified,"
    echo "                    then environmental variables must be externally"
    echo "                    set prior to invoking program."
    echo "  --ignore-missing  On backup, ignore missing backup paths."
    echo "  --dry-run         Do not actually do anything: just run through"
    echo "                    commands."
}

#* Variables to be read/populated based on command line
BACKUP_CONFIGURATION_PATH=""
EXCLUDE_FILE=""
IS_INIT=""
IS_UNLOCK=""
IS_BACKUP=""
IS_FORGET_AND_PRUNE=""
IS_CHECK=""
IS_REBUILD=""
IS_PRUNE_ONLY=""
IS_LIST=""
IS_DRY_RUN=""
IS_IGNORE_MISSING=""

#* Process command line arguments
POSITIONAL_ARGS=()
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
    -c | --config)
        shift
        BACKUP_CONFIGURATION_PATH=$1
        shift
        ;;
    -h | --help)
        show_help
        exit
        ;;
    --dry-run)
        IS_DRY_RUN=1
        shift
        ;;
    --ignore-missing)
        IS_IGNORE_MISSING=1
        shift
        ;;
    --ignore-missing)
        IS_IGNORE_MISSING=1
        shift
        ;;
    -* | --*)
        echo "-bu: Unrecognized option: '$key'"
        echo "-bu: See 'bu --help' for supported 'bu' options."
        exit
        ;;
    *) # unknown option
        POSITIONAL_ARGS+=("$key") # save it in an array for later
        shift                     # past argument
        ;;
    esac
done
# set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

#* Path to restic
if [[ $IS_DRY_RUN ]]; then
    RESTIC_PATH="echo restic"
    echo "-bu: Running in dry run mode"
else
    RESTIC_PATH=restic
    # RESTIC_PATH="echo restic"
    echo "-bu: restic path is: '$RESTIC_PATH'"
fi

#* Expect to get an action command as a positional argument.
if [[ -z $POSITIONAL_ARGS ]]; then
    echo -e "-bu: Please specify an action: $(join_by , $ACTION_CMDS)\n"
    show_help
    exit 1
fi

# Read configuration path
if [[ -n "$BACKUP_CONFIGURATION_PATH" ]]; then
    if [[ -f "$BACKUP_CONFIGURATION_PATH" ]]; then
        echo "-bu: Reading backup configuration file: '$BACKUP_CONFIGURATION_PATH'"
        source $BACKUP_CONFIGURATION_PATH
        if [[ $? -ne 0 ]]; then
            echo "-bu: ERROR: failed to read configuration file."
            exit 1
        fi
    else
        echo "-bu: ERROR: Backup configuration file not found: '$BACKUP_CONFIGURATION_PATH'"
        exit 1
    fi
fi

#* Check if at least the repository destination is defined
if [[ -z $RESTIC_REPOSITORY ]]; then
    echo "-bu: Environmental variable \$RESTIC_REPOSITORY specifying path to repository not defined"
    exit 1
fi

#* Check if at least the repository destination is defined
if [[ -z $BACKUP_PATHS ]]; then
    echo "-bu: Environmental variable \$BACKUP_PATHS specifying path(s) to back up not defined"
    exit 1
fi

#* Iterate over positional arguments
for POS_ARG in ${POSITIONAL_ARGS[@]}; do
    case $POS_ARG in
    init)
        shift
        IS_INIT=1
        echo "-bu: Will initialize new repository at: '$RESTIC_REPOSITORY'"
        ;;
    unlock)
        shift
        IS_UNLOCK=1
        echo "-bu: Will unlock repository at: '$RESTIC_REPOSITORY'"
        ;;
    backup)
        shift
        IS_BACKUP=1
        echo "-bu: Will back up to repository at: '$RESTIC_REPOSITORY'"
        ;;
    purge)
        shift
        IS_FORGET_AND_PRUNE=1
        echo "-bu: Will dereference and prune repository at: '$RESTIC_REPOSITORY'"
        ;;
    list)
        shift
        IS_LIST=1
        echo "-bu: Will list snapshots in repository at: '$RESTIC_REPOSITORY'"
        ;;
    rebuild)
        shift
        IS_REBUILD=1
        echo "-bu: Will rebuild index of repository at: '$RESTIC_REPOSITORY'"
        ;;
    prune)
        shift
        IS_PRUNE_ONLY=1
        echo "-bu: Will prune repository at: '$RESTIC_REPOSITORY'"
        ;;
    check)
        shift
        IS_CHECK=1
        echo "-bu: Will check repository at: '$RESTIC_REPOSITORY'"
        ;;
    *)
        echo "-bu: Unrecognized action command: '$POS_ARG'"
        echo "-bu: See 'bu --help' for supported 'bu' options."
        exit
        ;;
    esac
done

BACKUP_TAG="$(echo "$START_TIME" | sed -e 's/://g' | sed -e 's/ /_/g')_${HOSTNAME}"
if [[ -n "$SNAPSHOT_TITLE" ]]; then
    BACKUP_TAG="${BACKUP_TAG}_${SNAPSHOT_TITLE}"
fi
if [[ -z $BACKUP_TAG ]]; then
    echo "-bu: Empty backup tag generated"
    exit 1
fi
echo "-bu: Destination repository: '$RESTIC_REPOSITORY'"

### NOTE start all commands in background and wait for them to finish.
#* Reason: bash ignores any signals while child process is executing and thus my trap exit hook is not triggered.
#* However if put in subprocesses, wait(1) waits until the process finishes OR signal is received.
#? Reference: https://unix.stackexchange.com/questions/146756/forward-sigterm-to-child-in-bash

if [[ $IS_INIT ]]; then
    echo "-bu: Repository initialization starting"
    $RESTIC_PATH init &
    wait "$!"
    echo "-bu: Repository initialization done"
fi

if [[ $IS_UNLOCK ]]; then
    echo "-bu: Unlocking repository"
    $RESTIC_PATH unlock &
    wait "$!"
fi

if [[ $IS_BACKUP ]]; then
    #* Check if at least one backup path is given
    if [[ -z $BACKUP_PATHS ]]; then
        echo "-bu: Backup path information not found in \$BACKUP_PATHS"
        exit 1
    fi
    echo "-bu: Backup starting"
    echo "-bu: Backup tag: '$BACKUP_TAG'"
    echo "-bu: Paths to be included:"
    PROPOSED_BACKUP_PATHS="$BACKUP_PATHS"
    BACKUP_PATHS=""
    for BACKUP_PATH in $PROPOSED_BACKUP_PATHS; do
        if [[ -d $BACKUP_PATH ]]; then
            echo "-bu:     '$BACKUP_PATH'"
            BACKUP_PATHS="$BACKUP_PATHS $BACKUP_PATH"
        else
            if [[ $IS_IGNORE_MISSING ]]; then
                echo "-bu:     '$BACKUP_PATH' [NOT FOUND]"
            else
                echo "-bu: ABORTING DUE TO MISSING PATH: '$BACKUP_PATH'"
                exit 1
            fi
        fi
    done
    if [[ -n $BACKUP_EXCLUDE_FILE ]]; then
        EXCLUDE_FILE="--exclude-file ${BACKUP_EXCLUDE_FILE}"
        echo "-bu: Exclude file added: ${BACKUP_EXCLUDE_FILE}"
    fi
        if [[ -n $RESTIC_PASSWORD_FILE ]]; then
        PASSWORD_FILE="--password-file ${RESTIC_PASSWORD_FILE}"
        echo "-bu: Using password file: ${RESTIC_PASSWORD_FILE}"
    fi
    echo "-bu: Paths to be excluded: $BACKUP_EXCLUDES"
    $RESTIC_PATH backup \
        --one-file-system \
        --tag $BACKUP_TAG \
        ${EXCLUDE_FILE} \
        ${PASSWORD_FILE} \
        ${BACKUP_EXCLUDES} \
        ${BACKUP_PATHS} &
    wait "$!"
    if [[ $? == 1 ]]; then
        error_exit "'restic backup'"
    fi
    echo "-bu: Backup done"
fi

if [[ $IS_FORGET_AND_PRUNE ]]; then
    if [[ -z $RETENTION_POLICY ]]; then
        RETENTION_POLICY="--keep-daily 14 --keep-weekly 16 --keep-monthly 18 --keep-yearly 3"
    fi
    echo "-bu: Dereferencing starting"
    echo "-bu: Retention policy: '$RETENTION_POLICY'"
    $RESTIC_PATH forget \
        --prune \
        $RETENTION_POLICY \
        ;
    wait "$!"
    if [[ $? == 1 ]]; then
        error_exit "'restic forget'"
    fi
    echo "-bu: Purging done"
fi

if [[ $IS_LIST ]]; then
    $RESTIC_PATH snapshots &
    wait "$!"
    if [[ $? == 1 ]]; then
        error_exit "'restic list'"
    fi
fi

if [[ $IS_REBUILD ]]; then
    #* Rebuild repository for errors.
    echo "-bu: Rebuilding starting"
    $RESTIC_PATH rebuild-index &
    wait "$!"
    if [[ $? == 1 ]]; then
        error_exit "'restic rebuild'"
    fi
    echo "-bu: Rebuilding done"
    echo "-bu: Run 'prune' followed by 'check' to complete."
fi

if [[ $IS_PRUNE_ONLY ]]; then
    echo "-bu: Pruning starting"
    $RESTIC_PATH prune
    wait "$!"
    if [[ $? == 1 ]]; then
        error_exit "'restic prune'"
    fi
    echo "-bu: Pruning done"
fi

if [[ $IS_CHECK ]]; then
    #* Check repository for errors.
    echo "-bu: Checking starting"
    $RESTIC_PATH check &
    wait "$!"
    if [[ $? == 1 ]]; then
        error_exit "'restic check'"
    fi
    echo "-bu: Checking done"
fi

END_TIME="$(date --rfc-3339=seconds)"
echo "-bu: Exiting normally at: $END_TIME"
