# Rebootstrap configuration example

DEFAULT_VG=vg_fast
DEFAULT_OS=bullseye
DEFAULT_GRUB=mbr
DEFAULT_PREFIX=debian
#DEFAULT_BOOT=current
DEFAULT_BOOT=none

OS_MAP="
#name   os        grub            vg
green   bullseye  mbr,/dev/sda2    vg_fast
blue    bullseye  mbr,/dev/sda3    vg_fast
"

PART_MAP="
#Mount    device     format  size  mount_opt
/         -          ext4    5G    -
/boot     -          ext4    -     -
/var      -          ext4    1G    -
/var/lib  -          ext4    2G    -
/var/log  -          ext4    2G    -
/tmp/     -          ext4    2G
swap      -          swap    4G
"
