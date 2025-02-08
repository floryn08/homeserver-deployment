```bash
apt update
apt install sudo
sudo -u www-data php occ maintenance:mode --off
sudo -u www-data php occ upgrade
```