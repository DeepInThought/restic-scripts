#!/bin/bash
mkdir -p ${HOME}/.scripts
git clone https://github.com/DeepInThought/restic-scripts.git ${HOME}/.scripts/restic-scripts
sudo useradd -m restic
sudo mkdir -p ~restic/bin | ls -lat --color=always ~restic/bin || exit 1
curl -L https://github.com/restic/restic/releases/download/v0.9.5/restic_0.9.5_linux_amd64.bz2 | bunzip2 > ~restic/bin/restic
sudo ~restic/bin/restic self-update 
sudo chown root:restic ~restic/bin/restic
sudo chmod 750 ~restic/bin/restic
setcap cap_dac_read_search=+ep ~restic/bin/restic
#sudo -u restic /home/restic/bin/restic --exclude={/dev,/media,/mnt,/proc,/run,/sys,/tmp,/var/tmp} -r /tmp

