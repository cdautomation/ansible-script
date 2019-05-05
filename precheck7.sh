#!/bin/bash
touch /home/ansuser/configuration.txt
echo > /home/ansuser/configuration.txt
echo "----Hostname-----" >> /home/ansuser/configuration.txt
hostname >> /home/ansuser/configuration.txt
echo "----Uptime----" >> /home/ansuser/configuration.txt
uptime >> /home/ansuser/configuration.txt
echo "----Kernel Version---" >> /home/ansuser/configuration.txt
uname -r >> /home/ansuser/configuration.txt
echo "----Vmware tools Version----" >> /home/ansuser/configuration.txt
vmware-toolbox-cmd -v >> /home/ansuser/configuration.txt
echo "----LVM backup conf----- " >> /home/ansuser/configuration.txt
cat /etc/lvm/backup/* >> /home/ansuser/configuration.txt
echo "----fdisk details----" >> /home/ansuser/configuration.txt
fdisk -l >> /home/ansuser/configuration.txt
echo "----pvdisplay------" >> /home/ansuser/configuration.txt
pvdisplay -v >> /home/ansuser/configuration.txt
echo "----lvdisplay-----" >> /home/ansuser/configuration.txt
lvdisplay -v >> /home/ansuser/configuration.txt
echo "----Filesystem Details----" >> /home/ansuser/configuration.txt
df -h >> /home/ansuser/configuration.txt
echo "----Fstab details----" >> /home/ansuser/configuration.txt
cat /etc/fstab >> /home/ansuser/configuration.txt
echo"----Mtab Details----" >> /home/ansuser/configuration.txt
cat /etc/mtab >> /home/ansuser/configuration.txt
echo "----IP Address Details----" >> /home/ansuser/configuration.txt
ifconfig -a >> /home/ansuser/configuration.txt
echo "----Routing Information----" >> /home/ansuser/configuration.txt
netstat -nr >> /home/ansuser/configuration.txt
echo "----Enabled services Chkconfig------" >> /home/ansuser/configuration.txt
systemctl list-unit-files --type service >> /home/ansuser/configuration.txt
echo "----Server Details-----" >> /home/ansuser/configuration.txt
dmidecode -t 1 >> /home/ansuser/configuration.txt
echo "----Memory details----" >> /home/ansuser/configuration.txt
free -g >> /home/ansuser/configuration.txt
echo "----CPU details----" >> /home/ansuser/configuration.txt
lscpu >> /home/ansuser/configuration.txt
