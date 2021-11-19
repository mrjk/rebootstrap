# Use cases

On all examples, we assume we are on system `green` and we works with `blue` system.

## Do like a full show

To install a fresh system, you can run the command in check mode to actually see
what will happen:
```
root@green# rebootstrap.sh -n blue install
```

Then you checked the result, you can run it for good. Att the `-P` flag to force the next reboot on the target:
```
root@green# rebootstrap.sh blue install
```

## Reboot on the current system

TOFIX: this command is not persistant ...
```
root@green# rebootstrap.sh blue boot local
```

## Reboot on the target system

```
root@green# rebootstrap.sh blue boot target
 INFO: Target: debian_blue (bullseye) installed on /dev/vg_safe/debian_blue_root
Install grub in MBR for 'target' os in '/dev/sda' to '/dev/sda3' for next reboot?
(hit "y/Y" to continue, "n/N" to cancel) 
...

```
