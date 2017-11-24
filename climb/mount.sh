echo " = Format volume (EXT4)"
mkfs.ext4 /dev/vdb1
echo " = Creating mount point: /data"
rmdir "/data"
mkdir "/data"
echo " = Mount volume"
mount /dev/vdb1 "/data"
echo " = Change mountpoint owner (ubuntu:ubuntu)"
chown ubuntu:ubuntu "/data"
