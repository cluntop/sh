#!/bin/bash

cleaning_trash() {
sudo apt-get clean; sudo apt-get autoclean; sudo apt-get autoremove; sudo journalctl --rotate; sudo journalctl --vacuum-time=1s; sudo dpkg -l | grep '^rc' | awk '{print $2}' | sudo xargs dpkg --purge; sudo rm -rf /tmp/*; sudo rm -rf /var/tmp/*; sudo apt-get autoremove --purge; docker system prune -a -f; docker volume prune -f; docker network prune -f; docker image prune -a -f; docker container prune -f; docker builder prune -f; rm -rf ~/Downloads/*; rm -rf ~/.cache/thumbnails/*; rm -rf ~/.mozilla/firefox/*.default-release/cache2/*; sudo apt-get clean; dpkg --list | grep linux-image | grep -v `uname -r` | awk '{print $2}' | xargs sudo apt-get remove --purge -y
} && cleaning_trash
