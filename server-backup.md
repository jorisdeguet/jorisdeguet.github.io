jo@jo.local  mot de passe: marie etc.
## Creer un RAID 1

https://www.digitalocean.com/community/tutorials/how-to-create-raid-arrays-with-mdadm-on-ubuntu-22-04

sudo mdcdm --create /dev/md1 --level=1 --raid-devices=2 /dev/sda /dev/nvme0n1p3 




## Installer samba
https://ubuntu.com/tutorials/install-and-configure-samba#2-installing-samba
sudo apt install samba
sudo apt-get install -y samba-vfs-modules
sudo apt install netatalk avahi-daemon
Sudo nano /etc/samba/smb.conf


sudo service smbd restart
sudo ufw allow samba

## Installer Netatalk pour Time Machine, c'est fait pour
Followed this
https://www.dimov.xyz/ubuntu-20-04-setting-up-mac-os-time-machine-server/
