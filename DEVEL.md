
# Checklist Debian Server
# ==================


Apres un chroot:
* Set le hostname (no fqdn)
    echo wks1 > /etc/hostname
* Set le /etc/hosts
    echo "127.0.1.1     wks1" >> /etc/hosts
    echo "127.0.1.1     wks1.domain.org wks1" >> /etc/hosts # Ou si fqdn
* Verifier le fstab:
	mount | grep $FS_CHROOT | grep '^/dev/' | \ 
	    awk '{ print $1 "\t" $3 "\t" $5 "\t"  $6 "\t0\t0" }' | \ 
	    sed "s@$FS_CHROOT/*@/@g" | sed "s/[()]//g" | \ 
	    sed "1s/\t0\t0/\t0\t1/" |
	    sed "s/,*stripe=256//" |
	    column -t > $FS_CHROOT/etc/fstab
* Use C locale, instead of english or anywhat
    echo "LANG=C.UTF-8" >  /etc/default/locale
    localegen # Re run locale gen, only necessary if not C
* Install only required packages, not recommanded in APT
    cat > /etc/apt/apt.conf.d/02norecommend << EOF
    APT::Install-Recommends "0";
    APT::Install-Suggests "0";
    EOF


Une fois le systeme en place:
* Install core packages:
	* Volume mgmt:
		* lvm2
		* mdadm
		* cryptsetup
	* Firmwares:
		* firmware-linux
		* firmware-linux-free
		* firmware-linux-nonfree
		* firmware-misc-nonfree
	* Linux:
		* linux-base
	* Boot:
		* os-prober
			* We want to detect blue and green os inside grub menus
		* grub-efi
		* grub-mbr

* Installer les packets du kernel: lvm2 mdadm cryptsetup
* Installer linux-base et firmwares
* Installer grub
	* grub-mkdevicemap
	* grub-install /dev/sdX
	* update-grub
* Mettre un root password
	* password root


Comfort:
* Mettre une config de vim saine
	cat /etc/vim/vimrc.local
	source $VIMRUNTIME/defaults.vim
	syntax on
	filetype plugin indent on
	set nu
	set mouse=
	set ttymouse=
	
	"set autoindent                 " Minimal automatic indenting for any filetype.
	set backspace=indent,eol,start " Proper backspace behavior.
	set incsearch                  " Incremental search, hit `<CR>` to stop.
	
	set tabstop=2
	set softtabstop=2
	set shiftwidth=2
	set expandtab
	"set smarttab
	
	set wildmenu
	set showcmd
	set smartcase
	
* Mettre une config de git saine




# Minimal debian packages
# ==================

Userland:
```
vim htop git iftop psmisc

lsof iproute2
less 
```

System:
```
ca-certificates
apt
iproute2
```

Core:
```
bash
locales
dbus

console-data
console-setup
console-common




# grub-efi or grub-mbr
grub-pc


```
