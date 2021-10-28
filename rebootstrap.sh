#!/bin/bash

#  51 Fresh install
#  52 udev                                       16G     0   16G   0% /dev
#  53 tmpfs                                     3.2G  1.4M  3.2G   1% /run
#  54 /dev/mapper/vg_fast-debian_green_root     4.9G  717M  3.9G  16% /
#  55 tmpfs                                      16G     0   16G   0% /dev/shm
#  56 tmpfs                                     5.0M     0  5.0M   0% /run/lock
#  57 /dev/mapper/vg_fast-debian_green_var      976M  151M  759M  17% /var
#  58 /dev/sda3                                 3.7G   64M  3.4G   2% /boot
#  59 /dev/mapper/vg_fast-debian_green_var_lib  2.0G   61M  1.8G   4% /var/lib
#  60 /dev/mapper/vg_fast-share                 9.8G   37M  9.3G   1% /share
#  61 /dev/mapper/vg_fast-debian_green_var_log  2.0G   15M  1.8G   1% /var/log
#  62 /dev/mapper/vg_fast-debian_green_tmp      2.0G  6.1M  1.8G   1% /tmp


set -eu
# Documentation
# =================

# Notes: To test if your os has been correctly installed, you can
# check if os-prober if it's work
# linux-boot-prober /dev/mapper/vg_fast-debian_root
# It should return at least one line

# Conmfiguration
# =================


CONF_VG=vg_fast
CONF_FS=ext4
CONF_DISK_PREFIX=debian_blue_
CONF_GRUB_DEVICE=/dev/sda
# CONF_GRUB_DEVICE=/dev/sdb
CONF_DATE_CODE=$(date +%d/%m/%Y)

######   DEPRECATED  # =================

os_install_grml ()
{   
  echo "Installing with packages: $DEFAULT_PACKAGES"

  # Fix some mount permissions
  wrap_exec mkdir -p $FS_CHROOT/tmp $FS_CHROOT/var/tmp /tmp/debootstrap
  wrap_exec chmod 1777 $FS_CHROOT/tmp $FS_CHROOT/var/tmp

  # with grml
  wrap_exec grml-debootstrap \
    --debopt --cache-dir=/tmp/debootstrap \
    --target $FS_CHROOT \
    --release $_os_release \
    --grub $CONF_GRUB_DEVICE \
    --defaultinterfaces \
    --contrib \
    --non-free \
    -v \
    --force \
    --sshcopyid \
    --packages <(echo "$DEFAULT_PACKAGES") \
    --password "qwerty78" || {
    echo "ERROR: Something wrong happened, please check the logs: $FS_CHROOT/debootstrap/debootstrap.log"
    return 1
  }
}


# Libraries
# =================

_log ()
{
  local lvl=${1:-DEBUG}
  shift 1 || true
  >&2 printf "%-8s: %s\n" "$lvl" "${@:- }"
}

_exec ()
{
  local cmd=$@

  if ${RESTRAP_DRY:-false}; then
    _log DRY "$cmd"
  else
    _log RUN "$cmd"
    $cmd
  fi

}

_dump_vars ()
{
  declare -p | grep ' .. _'
}

_make_default ()
{
  local pattern=$1
  local value=$2
  local default=${3-}

  if [[ "$value" == "$pattern" ]]; then
    echo "$default"
  else
    echo "$value"
  fi
}


check_bin ()
{
    command -v $1 >&/dev/null || return 1
}

ask_to_continue ()
{
#  ${RESTRAP_DRY:-false} && return || true

  local msg="${1}"
  local waitingforanswer=true
  while ${waitingforanswer}; do
    read -p "${msg}"$'\n(hit "y/Y" to continue, "n/N" to cancel) ' -n 1 ynanswer
    case ${ynanswer} in
      [Yy] ) waitingforanswer=false; break;;
      [Nn] ) echo ""; echo "Operation cancelled as requested!"; return 1;;
      *    ) echo ""; echo "Please answer either yes (y/Y) or no (n/N).";;
    esac
  done
  echo ""
}


# Core app
# =================

###  loop_over_cfg_v2 ()
###  {
###    echo "DEPRECATRED loop_over_cfg_v2 => loop_over_partitions"
###    exit 1
###    local args=$@
###  
###    # Loop over entries
###    while  read -r mount source fs size _ ; do
###  
###      [[ ! -z "$mount" ]] || continue
###      [[ ! "$mount" =~ ^' '*'#' ]] || continue
###  
###      # $cmd $args
###      for cmd in $args; do
###        $cmd
###      done
###  
###    done <<<"$config"
###  }

loop_over_os_v3 ()
{
  local args=${@:-true}
  local config=${LOOP_CONFIG:-$OS_MAP}
  local cmd=

  # Loop over entries
  while  read -r target os grub vg_target _ ; do

    # Validate line
    [[ ! -z "$target" ]] || continue
    [[ ! "$target" =~ ^' '*'#' ]] || continue
    _os_name=$target
    _os_target=${DEFAULT_PREFIX}_${target}
    _os_release=$(_make_default - "$os" "$DEFAULT_OS")
    _os_vg=$(_make_default - "$vg_target" "$DEFAULT_VG")

    # Generate data
    _os_grub=$(_make_default - "$grub" "$DEFAULT_GRUB")
    _os_grub_boot=-
    _os_grub_device=-
    _os_grub_partition=-
    case "$_os_grub" in 
      *,*)
        _os_grub_boot=${_os_grub%%,*}
        _os_grub_partition=${_os_grub##*,}
        _os_grub_device=${_os_grub_partition%%[0-9]}
        ;;
      *)
        _os_grub_boot=${_os_grub}
        ;;
    esac
    if [[ "$_os_grub_device" == "$_os_grub_partition" ]]; then
      _os_grub_partition=-
    fi

    # $cmd $args
    for cmd in $args; do
      $cmd
    done

  done <<<"$config"

}

loop_over_partitions ()
{
  local args=${@:-true}
  local config=${LOOP_CONFIG:-$PART_MAP}
  local cmd=

  # Loop over entries
  while  read -r mount device format size mount_opts _ ; do

    # Validate line
    [[ ! -z "$mount" ]] || continue
    [[ ! "$mount" =~ ^' '*'#' ]] || continue
    mount=${mount%/}
    mount=${mount:-/}

    # Assign default values
    _part_mount=$mount
    _part_device=$device
    _part_format=$(_make_default "" "$format" "-")
    _part_size=$(_make_default "" "$size" "-")
    _part_mount_opts=$(_make_default "" "$mount_opts" "-")

    # Guess informations
    _part_mount_chroot="$FS_CHROOT$mount"
    case "$mount" in
      swap) _part_mount_chroot="";;
      *): ;;
    esac
    _part_vg=-
    _part_lv=-
    local device_name=${mount//\//_}
    device_name=${device_name#_}
    device_name=${device_name:-root}
    case "$device" in 
      -)
        _part_vg=$_os_vg
        _part_lv="${_os_target}_${device_name}"
        _part_device="/dev/$_os_vg/$_part_lv"
        ;;
      /dev/*/*|[^/][^/]*/*)
        _part_vg=${device%%/*}
        _part_lv=${device##*/}
        _part_device="/dev/$_part_vg/${_os_target}_${_part_lv}"
        ;;
      /dev/*)
        _part_device=$device
        ;;
      *)
        if [[ -e "/dev/$device" ]]; then
          _part_device="/dev/$device"
        else
          echo "UNSUPORTED PATTERN LVM"
        fi
        ;;
    esac

    if [[ "$mount" == "/boot" ]]; then
      case $_os_grub_partition in
        /dev/???[0-9])
          _part_device=$_os_grub_partition
          _part_lv=-
          _part_vg=-
          ;;
        -)
          _part_device="/dev/$_part_vg/${_part_lv}"
          ;;
      esac
    fi

    # $cmd $args
    for cmd in $args; do
      $cmd
    done

  done <<<"$config"
}


# API Volumes
# =================

api_volume_create ()
{

  # This is some kind of lvm
  if [[ "$_part_size" == "-" ]]; then
    _log INFO "Skip creation of volume $_part_vg/${_part_lv}"
    return
  fi

  vgs $_part_vg >& /dev/null || {
    _log ERROR "Can't find volume group: /dev/$_part_vg"
    return 1
  }

  if ! lvs "$_part_vg/$_part_lv" >& /dev/null; then
    _log INFO "Create logical volume $_part_vg/${_part_lv} ($_part_size)"
    _exec lvcreate --yes -n "${_part_lv}" -L $_part_size $_part_vg || true
  else
    _log INFO "Logical volume $_part_vg/${_part_lv} already exists"
  fi

}

api_volume_format ()
{ 

  case "$_part_format" in 
    ext4) 
      _exec mkfs.ext4 -F "$_part_device"
      local rc=$?
      [[ "$rc" -eq 0 ]] || {
        echo "FAIILLLLL => $rc"
        exit 1
      }
      ;;
    swap) 
      _exec mkswap "$_part_device"
      ;;
    -)
      _log INFO "Do not format $_part_device"
      ;;
    *)
      _log ERROR "Unsupported filesystem format: $_part_mount $_part_device $_part_format $_part_size"
      ;;
  esac
}


# API Mounts
# =================

api_mount_volume ()
{
  local mp="${FS_CHROOT}${_part_mount}"

  case "$_part_format" in 
    ext4) 
      mountpoint -q "$mp" || {
        _exec mkdir -p "$mp"
        _exec mount "$_part_device" "$mp"
      }
      ;;
    swap) 
      : _exec swapon "$_part_device"
      ;;
    *)
      _log DEBUG "Can't mount: $_part_device (on $mp)"
      ;;
  esac
}

#api_mount_sys_v1 ()
#{
#  mountpoint -q "$FS_CHROOT/proc" || {
#    _exec mkdir -p "$FS_CHROOT/proc"
#    _exec mount --rbind /proc "$FS_CHROOT/proc"
#    _exec mount --make-rslave "$FS_CHROOT/proc"
#  }
#  mountpoint -q "$FS_CHROOT/sys" || {
#    _exec mkdir -p "$FS_CHROOT/sys"
#    _exec mount --rbind /sys "$FS_CHROOT/sys"
#    _exec mount --make-rslave "$FS_CHROOT/sys"
#  }
#  mountpoint -q "$FS_CHROOT/dev" || {
#    _exec mkdir -p "$FS_CHROOT/dev"
#    _exec mount --rbind /dev "$FS_CHROOT/dev"
#    _exec mount --make-rslave "$FS_CHROOT/dev"
#  }
#  mountpoint -q "$FS_CHROOT/dev/pts" || {
#    _exec mkdir -p "$FS_CHROOT/dev/pts"
#    _exec mount --rbind /dev/pts "$FS_CHROOT/dev/pts"
#  }
#
#  _log INFO "Special filesystems mounted in $FS_CHROOT (/dev,/sys/,proc)"
#}

api_mount_sys_test ()
{
  local chroot=$FS_CHROOT

  _exec mount proc "$chroot/proc" -t proc -o nosuid,noexec,nodev &&
  _exec mount sys "$chroot/sys" -t sysfs -o nosuid,noexec,nodev,ro &&
  # ignore_error chroot_maybe_add_mount "[[ -d '$chroot/sys/firmware/efi/efivars' ]]" \
  #     efivarfs "$chroot/sys/firmware/efi/efivars" -t efivarfs -o nosuid,noexec,nodev &&
  _exec mount udev "$chroot/dev" -t devtmpfs -o mode=0755,nosuid &&
  _exec mount devpts "$chroot/dev/pts" -t devpts -o mode=0620,gid=5,nosuid,noexec &&
  _exec mount shm "$chroot/dev/shm" -t tmpfs -o mode=1777,nosuid,nodev &&
  _exec mount /run "$chroot/run" --bind &&
  _exec mount tmp "$chroot/tmp" -t tmpfs -o mode=1777,strictatime,nodev,nosuid
}

api_mount_sys ()
{
  mountpoint -q "$FS_CHROOT/proc" || {
    _exec mkdir -p "$FS_CHROOT/proc"
    _exec mount -t proc /proc "$FS_CHROOT/proc"
  }

  mountpoint -q "$FS_CHROOT/sys" || {
    _exec mkdir -p "$FS_CHROOT/sys"
    _exec mount --make-rslave --rbind /sys "$FS_CHROOT/sys"
  }
  mountpoint -q "$FS_CHROOT/dev" || {
    _exec mkdir -p "$FS_CHROOT/dev"
    _exec mount --make-rslave --rbind /dev "$FS_CHROOT/dev"
  }
  #mountpoint -q "$FS_CHROOT/run" || {
  #  _exec mount --make-rslave --rbind /run "$FS_CHROOT/run"
  #}

  #mountpoint -q "$FS_CHROOT/dev/pts" || {
  #  _exec mkdir -p "$FS_CHROOT/dev/pts"
  #  _exec mount --rbind /dev/pts "$FS_CHROOT/dev/pts"
  #}

  _log INFO "Special filesystems mounted in $FS_CHROOT (/dev,/sys/,proc)"
}

api_umount_sys ()
{
  ! mountpoint -q "$FS_CHROOT/proc" || {
    _exec umount -R "$FS_CHROOT/proc"
  }
  ! mountpoint -q "$FS_CHROOT/sys" || {
    _exec umount -R "$FS_CHROOT/sys"
  }
  #! mountpoint -q "$FS_CHROOT/dev/pts" || {
  #  _exec umount -R "$FS_CHROOT/dev/pts"
  #}
  ! mountpoint -q "$FS_CHROOT/dev" || {
    _exec umount -R "$FS_CHROOT/dev"
  }
  _log INFO "Special filesystems unmounted in $FS_CHROOT (/dev,/sys/,proc)"
}

api_umount_all ()
{
  local opts=${@-}
  for i in $( mount | awk  '{ print $3 }' | grep "^$FS_CHROOT" | tac); do
    # sleep 0.5 #  Do we have a timing issue here ?
    if _exec umount $opts "$i"; then
      _log INFO "Succesfully unmounted: $i"
    else
      _log ERROR "Failed to unmount: $i"
      return
    fi
  done

  # api_umount_sys
  # ! mountpoint -q "$FS_CHROOT" || {
  #   _exec umount -R $opts "$FS_CHROOT"
  # }
  # _log INFO "All filesystems unmounted in $FS_CHROOT"
}

# API Host
# =================

api_host_fetch_pkg ()
{
  # Minimal requirements
  if cat /proc/mdstat | grep -q active; then
    echo "mdadm"
  fi
  if [[ "$(lvs | wc -l)" -gt 1 ]]; then
    echo "lvm2"
  fi
  if check_bin crypsetup; then
    echo "crypsetup"
  fi

  # Boot and kernel
  if [ -d /sys/firmware/efi ]; then
    echo "grub-efi"
  else
    echo "grub-pc"
  fi
  echo "os-prober"
  echo "firmware-linux"
  echo "linux-image-amd64"

  # Extra pleasure
  echo "ca-certificates"
  echo "console-data"
  echo "dbus"
  echo "locales"

  # Userland
  echo "openssh-server"
  echo "openssh-client"
  echo "vim"
  echo "htop"
  #echo "man"
  echo "rsync"
  echo "lsof"
  echo "psmisc"
  echo "tree"
  echo "wget"
  echo "curl"

}


api_host_fetch_data ()
{
  # Retrieve user customized files and dir to be copied on target 
  :
}

api_host_fetch_system ()
{
  # Retrieve system settings into target
  :
}

# API OS
# =================


api_os_chroot ()
{
  local cmd=${@:-/bin/bash --login}
  # _log INFO "Chrooting shell into $FS_CHROOT: $cmd"
  _exec chroot $FS_CHROOT $cmd
}

api_os_rm ()
{
  # Sanity check
  if [[ -z "${FS_CHROOT:-}" ]]; then
    _log CRITICAL "Variable FS_CHROOT=$FS_CHROOT is empty"
    return 2
  fi
  mountpoint -q "$FS_CHROOT" || {
    _log ERROR "Filesystem is not mounted in $FS_CHROOT"
    return 1
  }

  _exec rm -rf ${FS_CHROOT:-BUG}/* || true
  _log INFO "System has been removed"
    
}

api_os_install_debootstrap ()
{
  local debootstrap_cache=/var/tmp
  # Sanity check
  if ! ${RESTRAP_DRY}; then
    mountpoint -q "$FS_CHROOT" || {
      _log ERROR "Filesystem is not mounted in $FS_CHROOT"
      return 1
    }
  fi

  # Prepare
  local extra_packages=$( api_host_fetch_pkg | xargs | tr ' ' ',' )
  _exec mkdir -p $FS_CHROOT/tmp $FS_CHROOT/var/tmp
  _exec chmod 1777 $FS_CHROOT/tmp $FS_CHROOT/var/tmp


  # Debootstrap
  _exec mkdir -p "$debootstrap_cache"
  tree -L 2 $FS_CHROOT
  _exec debootstrap \
    --verbose \
    --cache-dir="$debootstrap_cache" \
    --include=$extra_packages \
    --components=main,contrib,non-free \
    $_os_release $FS_CHROOT \
    http://deb.debian.org/debian/ || {
      _log ERROR "Debootstrap '$_os_release' failed at some point ..."
      _log INFO "You will need to flush those files with '${0##*/} rm' command"
      local log_file="$FS_CHROOT/debootstrap/debootstrap.log"
      if [[ -f "$log_file" ]]; then
        _log INFO "Please check logs in: $log_file"
        tail $log_file
      fi
    }
}

api_os_preconfigure ()
{
  local infile=
  local outfile=

  # Configure fstab
  outfile=$FS_CHROOT/etc/fstab
  _log INFO "Configure $outfile"
  if ! ${RESTRAP_DRY:-false}; then
    api_os__gen_fstab > "$outfile"
    for i in $( cat "$outfile"  | grep -Ev '^ *#' | awk '{ print $2}' | grep -v '^/$' ) ; do
      [[ -d "$FS_CHROOT$i" ]] || _exec mkdir -p $FS_CHROOT$i
    done
  fi

  # Configure apt
  # TODO: Add other repos !
  outfile=$FS_CHROOT/etc/apt/apt.conf.d/02nosuggest
  _log INFO "Configure $outfile"
  if ! ${RESTRAP_DRY:-false}; then
    cat > "$outfile" << EOF
APT::Install-Recommends "1";
APT::Install-Suggests "0";
EOF
  fi


  # Configure locale
  infile=/etc/default/locale
  if [[ -f "$infile" ]]; then
    _log INFO "Import $infile"
    _exec cp "$infile" "$FS_CHROOT$infile"

    infile=/etc/locale.gen
    if [[ -f "$infile" ]]; then
      _log INFO "Import $infile"
      _exec cp "$infile" "$FS_CHROOT$infile"
    fi
  else
    _log INFO "Configure $infile"
    if ! ${RESTRAP_DRY:-false}; then
      echo "LANG=C.UTF-8" > "$FS_CHROOT$infile"
    fi
  fi
  api_os_chroot locale-gen

  # Import resolvers (systemd-resolverd is the choice)
  _log INFO "Import systemd resolved config"
  infile=/etc/resolv.conf
  if [[ -e "$infile" ]]; then
    _exec cp --preserve=links $infile $FS_CHROOT$infile
  else
    _exec ln -s $infile $FS_CHROOT$infile
  fi
  infile=/etc/systemd/resolved.conf.d
  if [[ -d "$infile/" ]]; then
    _exec cp -R $infile/. $FS_CHROOT$infile
  else
    if ! ${RESTRAP_DRY:-false}; then
      _exec mkdir -p $FS_CHROOT$infile
      cat > $FS_CHROOT$infile/default.conf << EOF
[Resolve]
DNS=127.0.0.53
EOF
    fi
  fi
  api_os_chroot systemctl enable systemd-resolved

  # Import networkd (use systemd if enabled)
  infile=/etc/systemd/network
  _log INFO "Import systemd resolved config"
  if [[ -d "$infile/" ]]; then
    _exec cp -R $infile/. $FS_CHROOT$infile
    api_os_chroot systemctl disable networking.service
    api_os_chroot systemctl enable systemd-networkd.service
  fi


  # Import other convenients stuffs
  _log INFO "Import /etc/ssh"
  _exec cp -a "/etc/ssh" "$FS_CHROOT/etc/ssh" || \
    _log WARN "Import failed (rc=$?)"

  _log INFO "Import /etc/vim/vimrc.local"
  _exec cp "/etc/vim/vimrc.local" "$FS_CHROOT/etc/vim/vimrc.local" || \
    _log WARN "Import failed (rc=$?)"

  _log INFO "Import /etc/gitconfig"
  _exec cp "/etc/gitconfig" "$FS_CHROOT/etc/gitconfig" || \
    _log WARN "Import failed (rc=$?)"

  # Import home root
  _log INFO "Import root directory (partial import)"
  _exec rsync -av \
		--include={.config,.profile,.bashrc,.vimrc,.ssh} \
		--exclude='/.*' \
		/root/ $FS_CHROOT/root


  # Import homes directories
  #_log INFO "Import homes directories"
  #_exec rsync -av \
	#	/homes/ $FS_CHROOT/homes

  # Import grub config
  infile=/etc/default/grub
  if [[ -f "$infile" ]]; then
    _log INFO "Import $infile"
    _exec cp "$infile" "$FS_CHROOT$infile"
  else
    if ! ${RESTRAP_DRY:-false}; then
      cat > "$FS_CHROOT$infile" <<EOF
GRUB_DEFAULT=0
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR=${_os_target^}
GRUB_CMDLINE_LINUX_DEFAULT="quiet"
GRUB_CMDLINE_LINUX=""
GRUB_PRELOAD_MODULES="diskfilter lvm mdraid1x"
EOF
    fi
  fi

  # Save the date
  outfile=$FS_CHROOT/etc/install-release
  _log INFO "Configure $outfile"
  if ! ${RESTRAP_DRY:-false}; then
      cat > "$outfile" <<EOF
INSTALL_DATE="$(date --iso-8601=seconds)"
INSTALL_VARIANT="${_os_target}"
INSTALL_NAME="${_os_name}"
EOF
  fi

}

api_os__gen_fstab ()
{
  # Generate system mounts from config
  echo "# System mounts"
  mount | grep $FS_CHROOT | grep '^/dev/' | \
    awk '{ print $1 "\t" $3 "\t" $5 "\t"  $6 "\t0\t0" }' | \
    sed "s@$FS_CHROOT/*@/@g" | sed "s/[()]//g" | \
    sed "1s/\t0\t0/\t0\t1/" |
    sed "s/,*stripe=256//" |
    column -t

  # Keep existing mounts
  echo "# Imported mounts"
  cat /etc/fstab | \
    grep -E -v "#.*|/ |/boot |/tmp |/usr |/bin |/sbin |/var |/var/log |/var/lib " | \
    sed '/^$/d' | column -t
}

api_os_bootloader ()
{

  [[ "$_os_grub_device" != "-" ]] || {
    _log INFO "Do not manage boot loader"
    return
  }


  local disk=$_os_grub_device
  local autoboot=false

  # Install grub and eventually mbr/efi
  api_os_chroot grub-mkdevicemap
  if [[ ! -z "${disk:-}" ]]; then
    if $autoboot ; then
      # TOFIX: Enable this to next boot on this distro
      _log INFO "Next boot: Target OS /!\\"
      api_os_chroot grub-install $disk
    else
      api_os_chroot grub-install --no-bootsector $disk
    fi
  fi
  api_os_chroot update-grub

  # Exec local update to detect this new OS
  _exec grub-mkdevicemap
  if $autoboot ; then
    _exec grub-install $disk
  else
    _log INFO "Next boot: Current OS"
    _exec grub-install --no-bootsector $disk
  fi
  _exec update-grub
  if $autoboot ; then
    _log INFO "User import finished, OS will reboot on TARGET OS."
  else
    _log INFO "User import finished, system will reboot on the current OS."
  fi
}

#api_os_bootloader_from_host ()
#{
#  local disk=${1:-$DISK_MBR}
#
#  loop_over_cfg_v2 api_mount_volume
#  api_mount_sys
#  api_os_bootloader $disk
#  api_umount_all
#
#  # Run from host
#  _exec grub-mkdevicemap
#  _exec update-grub
#}

# api_host_bootloader ()
# {
#   local disk=${1:-$DISK_MBR}
#   if [[ ! -z "${disk:-}" ]]; then
#     _exec grub-mkdevicemap
#     _exec grub-install $disk
#   fi
#   _exec update-grub
# }

api_os_import ()
{
  _log INFO "Import User settings"
  color=green

  _exec cp "/etc/profile.d/bash_tweaks.sh" "$FS_CHROOT/etc/profile.d/bash_tweaks.sh" || true
  _exec cp "/etc/profile.d/zz_init.sh" "$FS_CHROOT/etc/profile.d/zz_init.sh" || true
  if ! ${RESTRAP_DRY:-false}; then
    echo "export PS1_HOST_COLOR=${color^}" > "$FS_CHROOT/etc/profile.d/00_config.sh"
  fi

  _log INFO "User import finished"

}

# CLI API
# =================

# Specialized commands

cli__create ()
{
  : "Create volumes (LVM only)"
  loop_over_partitions api_volume_create
}


_cli__volumes_list ()
{
  case "$_part_format" in
    ext*)
      echo "  $_part_device $FS_CHROOT$mount $_part_format $_part_size"
    ;;
  swap)
      echo "  $_part_device swap $_part_format $_part_size"
    ;;
  esac
}

cli__format ()
{
  : "Format volumes"

  local recap=$( 
    _log WARN "This will create and reformat the following volumes. Are you sure?"
    {
      echo "Device Target Format? LVCreate?"
      loop_over_partitions _cli__volumes_list 
    }| column -t
    printf "\n"
  )
  ask_to_continue "$recap" || return

  loop_over_partitions api_volume_format || {
    _log HINT "If you have issues with busy devices, try: findmnt -o TARGET,PROPAGATION,FSTYPE"
    return 1
  }
  _log INFO "Format successfull"
}

cli__mount ()
{
  : "Mount volumes"
  loop_over_partitions api_mount_volume
}


cli__umount_all ()
{
  : "Umount all volumes and special fs"
  api_umount_all
}


cli__chroot ()
{
  : "Chroot into the target"
  cli__mount_all
  api_os_chroot $@
}

cli__rm ()
{
  : "Remove all files of the target, without umounts"
  ask_to_continue "WARN    : This will 'rm -rf $FS_CHROOT', are you sure?" || return

  api_umount_sys
  loop_over_partitions api_mount_volume
  api_os_rm
  tree -L 2 $FS_CHROOT
}

# Workflow commands

cli__install_all ()
{
  : "Clean everything and install all from fresh start"
  cli__umount_all
  cli__create
  # Format is quite broken due to volume locks .... 
  # cli__format 
  cli__rm
  cli__debootstrap
  cli__configure
}

cli__mount_all ()
{
  : "Mount all volumes and special fs"
  loop_over_partitions api_mount_volume
  api_mount_sys
}

cli__debootstrap ()
{
  : "Debootstrap the minimal base system"
  api_umount_sys
  cli__mount
  api_os_install_debootstrap
  api_mount_sys
  api_os_bootloader
}

cli__configure ()
{
  : "Configure the minimal base system and import data"
  cli__mount_all
  api_os_preconfigure
  api_os_import
}

#cli__boot_target ()
#{
#  : "Install mbr to boot on target"
#
#}
#
#cli__boot_local ()
#{
#  : "Install mbr to boot on local"
#  local device=$1
#  grub-install $device
#}

cli__help ()
{
  : "Show this help"

  echo "${0##*/} is a tool to do blue/green Debian installation."
  echo ""
  echo "usage: ${0##*/} <COMMAND> <TARGET> [<ARGS>]"
  echo "       ${0##*/} help"
  echo ""

  echo "COMMANDS:"
  declare -f | grep -E -A 2 '^cli__[a-z0-9_]* \(\)' \
    | sed '/{/d;/--/d;s/cli__/  /;s/ ()/,/;s/";$//;s/^  *: "//;' \
    | xargs -n2 -d'\n' | column -t -s ',' 
}




################ DEVEL

####   init_config_OOOLD ()
####   {
####     local target=$1
####   
####   
####   ######     local current_os_disk
####   ######     current_os_disk=${1:-$(mount | sed  -n '/ on \/ type/s@ on / .*@@p')}
####   ######     OS_MAP=$(grep -v '^#' <<< "$OS_MAP" | grep -v "^$" )
####   ######     OS_MAP_TMP=$(echo -e "$OS_MAP\n$OS_MAP" )
####   ######   
####   ######   #  echo "${current_os_disk}" | grep "/${VG_NAME}-${DISK_NAME_PREFIX}_[a-zA-Z0-9]*_root"
####   ######   #  echo "${current_os_disk}" | grep "/${VG_NAME}-${DISK_NAME_PREFIX}_[a-zA-Z0-9]*_root"
####   ######     #name=$(sed -E -n "s@/.*/${VG_NAME}-${DISK_NAME_PREFIX}_([a-zA-Z0-9]*)_root@\\1@p" <<< "$current_os_disk" )
####   ######     names=$( sed -En 's/^([a-zA-Z0-9][a-zA-Z0-9]*)( .*)/\1/p' <<< "$OS_MAP" )
####   ######     grep_pattern=$( sed -E 's/(.*)/^\1$/' <<< "$names" )
####   ######   
####   ######     # Guess from hostname, part_name
####   ######     local from_host=$( grep -f <( echo "$grep_pattern" ) <<< "$HOSTNAME" || true )
####   ######     if [[ ! -z "$from_host" ]]; then
####   ######       name=$from_host
####   ######     else
####   ######       current_os_disk=${1:-$(mount | sed  -n '/ on \/ type/s@ on / .*@@p')}
####   ######       hint=${current_os_disk##.*-}
####   ######       if grep -f <( echo "$grep_pattern" ) <<< "$hint"; then
####   ######         name=$hint
####   ######       fi
####   ######     fi
####   ######   
####   ######     echo "NAME: $name"
####   
####     if [[ -z "$target" ]]; then
####       _log ERROR "Can't auto-detect target configuration name, please use '-t <TARGET>' option."
####       exit 1
####     fi
####   
####     # Verify config
####     config_match=$( grep -m 1 "^$target" <<< "$OS_MAP" ) || {
####       _log ERROR "Cant' find config '$target' in config file"
####       list=$(grep -o '^[a-zA-Z0-9][a-zA-Z0-9]*' <<< "$OS_MAP" | tr '\n' ',' | sed 's/,$//')
####       _log HINT "Available configs: $list"
####       return 1
####     }
####   
####   echo "|||$config_match|||"
####   exit 1
####   
####   #  set -x
####   #  : "$OS_MAP"
####   #  next_config=$( grep -A 1 "^$name" <<< "$OS_MAP_TMP" | sed -n '2p' )
####   ##  last_option=$(tail -n 1 <<< "$OS_MAP" )
####   #  #if [[ "$next_config" == "$last_option" ]]; then
####   #  #  # take the first one then
####   #  #  next_config=$(head -n 1 <<< "$OS_MAP")
####   #  #fi
####   #  set +x
####   
####   
####     # Load config
####     #while  read -r name grub_disk os prefix _ ; do
####     #  :
####     read -r name os grub_disk _  <<< "$config_match"
####     echo "Weee: ${DISK_NAME_PREFIX}_$name boot on $grub_disk"
####   
####     # echo "$PART_MAP2" | column -t
####   
####   
####   
####   
####   
####   
####   
####   }





#### New config parser



init_config ()
{
  local target=$1

  # Load user config
  DEFAULT_OS=${DEFAULT_OS:-bullseye}
  DEFAULT_GRUB=${DEFAULT_GRUB:-auto}
  DEFAULT_VG=${DEFAULT_VG:--}
  DEFAULT_PREFIX=${DEFAULT_PREFIX:-debian}
  . /root/prj/rebootstrap/configs/new_conf.sh


  # Verify config
  if [[ -z "$target" ]]; then
    _log ERROR "Can't auto-detect target configuration name, please use '-t <TARGET>' option."
    exit 1
  fi
  config_match=$( grep -m 1 "^$target" <<< "$OS_MAP"  ) || {
    _log ERROR "Cant' find config '$target' in config file"
    list=$(grep -o '^[a-zA-Z0-9][a-zA-Z0-9]*' <<< "$OS_MAP" | tr '\n' ',' | sed 's/,$//')
    _log HINT "Available configs: $list"
    return 1
  }

  # Load config
  #LOOP_CONFIG="$config_match" loop_over_os_v3 _dump_vars
  LOOP_CONFIG="$config_match" loop_over_os_v3 true
  _log INFO "Target: $_os_target ($_os_release) installed on /dev/$_os_vg/${_os_target}_root"

  # Load disks (DEVEL ONLY)
  ### LOOP_CONFIG="$PART_MAP" loop_over_partitions _dump_vars

  # TOFIX HARDOCDED VARS
  FS_CHROOT=/mnt/$_os_target

}


cli__devel ()
{
  init_config $RESTRAP_TARGET $@
}


# Devel
# =================

main_app ()
{

  # Init CLI: options
  RESTRAP_DRY=false
  local OPTIND o
  while getopts "t:n" o; do
    case "${o}" in
        t) RESTRAP_TARGET=$OPTARG ;;
        n) RESTRAP_DRY=true ;;
        *) _log ERROR "Unknown option: $o"
            cli__help
            return 1
            ;;
    esac
  done
  shift $((OPTIND-1))

  # Init CLI: arguments
  local cmd=${1:-help}
  shift 1 || true

  local commands=$(declare -f | sed -E -n 's/cli__([a-z0-9_]*) \(\)/\1/p')
  case "$cmd" in
    -h|--help|help) cli__help; return ;;
    devel) shift 1; cli__devel $@; return ;;
  esac

  local target_name=${RESTRAP_TARGET:-}
  if [[ -z "${target_name}" ]]; then
    local target_name=${1:-FAIL}
    shift 1 || true
  fi
  local args=${@:-}


  # Init user config
  init_config $RESTRAP_TARGET


  # Dispatch
  if grep -q "$cmd" <<< "$commands"; then
    "cli__$cmd" $args
  else
    _log ERROR "Unknown command: $cmd"
    return 1
  fi



  # DEPRECATED # Load configurations
  # DEPRECATED # TOFIX => hard codede path !
  # DEPRECATED for conf in /root/prj/rebootstrap/configs/{common.sh,$target_name.sh}; do
  # DEPRECATED   if [[ -f "$conf" ]]; then
  # DEPRECATED     . "$conf"
  # DEPRECATED   else
  # DEPRECATED     _log ERROR "Missing configuration file: $conf"
  # DEPRECATED     return 1
  # DEPRECATED   fi
  # DEPRECATED done

  # Load config


}


# Main
# =================

main_app "$@"
