#!/bin/bash
touch /home/ansuser/postpatch.txt
echo "----Hostname-----" >> /home/ansuser/postpatch.txt
hostname >> /home/ansuser/postpatch.txt
echo "----Uptime----" >> /home/ansuser/postpatch.txt
uptime >> /home/ansuser/postpatch.txt
echo "----Kernel Version---" >> /home/ansuser/postpatch.txt
uname -r >> /home/ansuser/postpatch.txt
echo "----Vmware tools Version----" >> /home/ansuser/postpatch.txt
vmware-toolbox-cmd -v >> /home/ansuser/postpatch.txt
echo "----LVM backup conf----- " >> /home/ansuser/postpatch.txt
cat /etc/lvm/backup/* >> /home/ansuser/postpatch.txt
echo "----fdisk details----" >> /home/ansuser/postpatch.txt
fdisk -l >> /home/ansuser/postpatch.txt
echo "----pvdisplay------" >> /home/ansuser/postpatch.txt
pvdisplay -v >> /home/ansuser/postpatch.txt
echo "----lvdisplay-----" >> /home/ansuser/postpatch.txt
lvdisplay -v >> /home/ansuser/postpatch.txt
echo "----Filesystem Details----" >> /home/ansuser/postpatch.txt
df -h >> /home/ansuser/postpatch.txt
echo "----Fstab details----" >> /home/ansuser/postpatch.txt
cat /etc/fstab >> /home/ansuser/postpatch.txt
echo"----Mtab Details----" >> /home/ansuser/postpatch.txt
cat /etc/mtab >> /home/ansuser/postpatch.txt
echo "----IP Address Details----" >> /home/ansuser/postpatch.txt
ifconfig -a >> /home/ansuser/postpatch.txt
echo "----Routing Information----" >> /home/ansuser/postpatch.txt
netstat -nr >> /home/ansuser/postpatch.txt
echo "----Enabled services Chkconfig------" >> /home/ansuser/postpatch.txt
chkconfig --list >> /home/ansuser/postpatch.txt
echo "----Server Details-----" >> /home/ansuser/postpatch.txt
dmidecode -t 1 >> /home/ansuser/postpatch.txt
echo "----Memory details----" >> /home/ansuser/postpatch.txt
free -g >> /home/ansuser/postpatch.txt
