#!/bin/bash
touch /home/ansuser/prepatch.txt
echo > /home/ansuser/prepatch.txt
echo "----Hostname-----" >> /home/ansuser/prepatch.txt
hostname >> /home/ansuser/prepatch.txt
echo "----Uptime----" >> /home/ansuser/prepatch.txt
uptime >> /home/ansuser/prepatch.txt
echo "----Kernel Version---" >> /home/ansuser/prepatch.txt
uname -r >> /home/ansuser/prepatch.txt
echo "----Vmware tools Version----" >> /home/ansuser/prepatch.txt
vmware-toolbox-cmd -v >> /home/ansuser/prepatch.txt
echo "----LVM backup conf----- " >> /home/ansuser/prepatch.txt
cat /etc/lvm/backup/* >> /home/ansuser/prepatch.txt
echo "----fdisk details----" >> /home/ansuser/prepatch.txt
fdisk -l >> /home/ansuser/prepatch.txt
echo "----pvdisplay------" >> /home/ansuser/prepatch.txt
pvdisplay -v >> /home/ansuser/prepatch.txt
echo "----lvdisplay-----" >> /home/ansuser/prepatch.txt
lvdisplay -v >> /home/ansuser/prepatch.txt
echo "----Filesystem Details----" >> /home/ansuser/prepatch.txt
df -h >> /home/ansuser/prepatch.txt
echo "----Fstab details----" >> /home/ansuser/prepatch.txt
cat /etc/fstab >> /home/ansuser/prepatch.txt
echo "----Mtab Details----" >> /home/ansuser/prepatch.txt
cat /etc/mtab >> /home/ansuser/prepatch.txt
echo "----IP Address Details----" >> /home/ansuser/prepatch.txt
ifconfig -a >> /home/ansuser/prepatch.txt
echo "----Routing Information----" >> /home/ansuser/prepatch.txt
netstat -nr >> /home/ansuser/prepatch.txt
echo "----Enabled services Chkconfig------" >> /home/ansuser/prepatch.txt
systemctl list-unit-files --type service >> /home/ansuser/prepatch.txt
echo "----Server Details-----" >> /home/ansuser/prepatch.txt
dmidecode -t 1 >> /home/ansuser/prepatch.txt
echo "----Memory details----" >> /home/ansuser/prepatch.txt
free -g >> /home/ansuser/prepatch.txt
echo "----CPU details----" >> /home/ansuser/prepatch.txt
lscpu >> /home/ansuser/prepatch.txt
echo "----yum check-update details----" >> /home/ansuser/prepatch.txt
yum check-update >> /home/ansuser/prepatch.txt
