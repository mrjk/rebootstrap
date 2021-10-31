# Rebootstrap configuration example

DEFAULT_VG=vg_safe
DEFAULT_OS=bullseye
DEFAULT_GRUB=mbr
DEFAULT_PREFIX=debian
DEFAULT_BOOT=none

DEFAULT_HOSTNAME=wks1
DEFAULT_SSH_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF7jBNIMjDNUy003yGhp1HO0wS/Hi1K3ZazQ0OF/Sz7V mrjk@xpjez.7451.jzn42.net:ed25519_20201104"
DEFAULT_PASSWD=qwerty

OS_MAP="
#name   os        grub            vg
green   bullseye  mbr,/dev/sda2    vg_safe
blue    bullseye  mbr,/dev/sda3    vg_safe
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
