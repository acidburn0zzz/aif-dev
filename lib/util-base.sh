# !/bin/bash
#
# Architect Installation Framework (2016-2017)
#
# Written by Carl Duff and @mandog for Archlinux
# Heavily modified and re-written by @Chrysostomus to install Manjaro instead
# Contributors: @papajoker, @oberon and the Manjaro-Community.
#
# This program is free software, provided under the GNU General Public License
# as published by the Free Software Foundation. So feel free to copy, distribute,
# or modify it as you wish.

install_base() {
    # Prep variables
    echo "" > ${PACKAGES}
    echo "" > ${ANSWER}
    BTRF_CHECK=$(echo "btrfs-progs" "-" off)
    F2FS_CHECK=$(echo "f2fs-tools" "-" off)
    KERNEL="n"
    mhwd-kernel -l | awk '/linux/ {print $2}' > /tmp/.available_kernels
    kernels=$(cat /tmp/.available_kernels)
    [[ -e /mnt/.base_installed ]] && rm /mnt/.base_installed

    # User to select initsystem
    DIALOG " $_ChsInit " --menu "\n$_WarnOrc\n" 0 0 2 \
      "1" "systemd" \
      "2" "openrc" 2>${INIT}

    if [[ $(cat ${INIT}) != "" ]]; then
        if [[ $(cat ${INIT}) -eq 2 ]]; then
            check_for_error "init openrc"
            touch /mnt/.openrc
            cat /usr/share/manjaro-architect/package-lists/base-openrc-manjaro > /mnt/.base
        else
            check_for_error "init systemd"
            [[ -e /mnt/.openrc ]] && rm /mnt/.openrc
            cat /usr/share/manjaro-architect/package-lists/base-systemd-manjaro > /mnt/.base
        fi
    else
        return 0
    fi
  
    # Choose kernel and possibly base-devel
    DIALOG " $_InstBseTitle " --checklist "$_InstStandBseBody$_UseSpaceBar" 0 0 12 \
      $(cat /tmp/.available_kernels |awk '$0=$0" - off"') \
      "base-devel" "-" off 2>${PACKAGES} || return 0
      cat ${PACKAGES} >> /mnt/.base

    if [[ $(cat ${PACKAGES}) == "" ]]; then
        # Check to see if a kernel is already installed
        ls ${MOUNTPOINT}/boot/*.img >/dev/null 2>&1
        if [[ $? == 0 ]]; then
            check_for_error "linux-$(ls ${MOUNTPOINT}/boot/*.img | cut -d'-' -f2) is already installed"
            KERNEL="y"
        else
            for i in $(cat /tmp/.available_kernels); do
                [[ $(cat ${PACKAGES} | grep ${i}) != "" ]] && KERNEL="y" && break;
            done
        fi
        # If no kernel selected, warn and restart
        if [[ $KERNEL == "n" ]]; then
            DIALOG " $_ErrTitle " --msgbox "$_ErrNoKernel" 0 0
            check_for_error "no kernel installed."
            return 0
        fi
    else
        check_for_error "selected: $(cat ${PACKAGES})"

        # Choose wanted kernel modules
        DIALOG "$_ChsAddPkgs" --checklist "\n\n$_UseSpaceBar" 0 0 12 \
          "KERNEL-headers" "-" off \
          "KERNEL-acpi_call" "-" on \
          "KERNEL-ndiswrapper" "-" on \
          "KERNEL-broadcom-wl" "-" off \
          "KERNEL-r8168" "-" off \
          "KERNEL-rt3562sta" "-" off \
          "KERNEL-tp_smapi" "-" off \
          "KERNEL-vhba-module" "-" off \
          "KERNEL-virtualbox-guest-modules" "-" off \
          "KERNEL-virtualbox-host-modules" "-" off \
          "KERNEL-spl" "-" off \
          "KERNEL-zfs" "-" off 2>/tmp/.modules
        [[ $(cat /tmp/.modules) == "" ]] && return 0

        check_for_error "modules: $(cat /tmp/.modules)"
        for kernel in $(cat ${PACKAGES} | grep -v "base-devel") ; do
            cat /tmp/.modules | sed "s/KERNEL/\ $kernel/g" >> /mnt/.base
        done

        # If a selection made, act
        if [[ $(cat ${PACKAGES}) != "" ]]; then
            clear
            check_for_error "packages to install: $(cat /mnt/.base | tr '\n' ' ')"
            # If at least one kernel selected, proceed with installation.
            basestrap ${MOUNTPOINT} $(cat /mnt/.base) 2>$ERR
            check_for_error "install basepkgs" $?

            # If root is on btrfs volume, amend mkinitcpio.conf
            [[ $(lsblk -lno FSTYPE,MOUNTPOINT | awk '/ \/mnt$/ {print $1}') == btrfs ]] && sed -e '/^HOOKS=/s/\ fsck//g' -i ${MOUNTPOINT}/etc/mkinitcpio.conf && \
              check_for_error "root on btrfs volume. amend mkinitcpio."

            # If root is on nilfs2 volume, amend mkinitcpio.conf
            [[ $(lsblk -lno FSTYPE,MOUNTPOINT | awk '/ \/mnt$/ {print $1}') == nilfs2 ]] && sed -e '/^HOOKS=/s/\ fsck//g' -i ${MOUNTPOINT}/etc/mkinitcpio.conf && \
              check_for_error "root on nilfs2 volume. amend mkinitcpio."

            # Use mhwd to install selected kernels with right kernel modules
            # This is as of yet untested
            # arch_chroot "mhwd-kernel -i $(cat ${PACKAGES} | xargs -n1 | grep -f /tmp/.available_kernels | xargs)"

            # If the virtual console has been set, then copy config file to installation
            if [[ -e /tmp/vconsole.conf ]]; then
                cp -f /tmp/vconsole.conf ${MOUNTPOINT}/etc/vconsole.conf
                check_for_error "copy vconsole.conf" $?
            fi

            # If specified, copy over the pacman.conf file to the installation
            if [[ $COPY_PACCONF -eq 1 ]]; then
                cp -f /etc/pacman.conf ${MOUNTPOINT}/etc/pacman.conf
                check_for_error "copy pacman.conf" $?
            fi

            # if branch was chosen, use that also in installed system. If not, use the system setting
            if [[ -e ${BRANCH} ]]; then
                sed -i "/Branch =/c\Branch = $(cat ${BRANCH})/" ${MOUNTPOINT}/etc/pacman-mirrors.conf 2>$ERR
                check_for_error "set target branch $(cat ${BRANCH})" $?
            else
                sed -i "/Branch =/c$(grep "Branch =" /etc/pacman-mirrors.conf)" ${MOUNTPOINT}/etc/pacman-mirrors.conf 2>$ERR
                check_for_error "use host branch \($(grep "Branch =" /etc/pacman-mirrors.conf)\)" $?
            fi
            touch /mnt/.base_installed
            check_for_error "base installed succesfully."
        fi
    fi
}

install_bootloader() {
    if check_base; then
        if [[ $SYSTEM == "BIOS" ]]; then
            bios_bootloader
        else
            uefi_bootloader
        fi
    else
        HIGHLIGHT_SUB=2
    fi
}

uefi_bootloader() {
    #Ensure again that efivarfs is mounted
    [[ -z $(mount | grep /sys/firmware/efi/efivars) ]] && mount -t efivarfs efivarfs /sys/firmware/efi/efivars

    DIALOG " $_InstUefiBtTitle " --yesno "\n\n$_InstUefiBtBody\n" 0 0 || return 0
    clear
    basestrap ${MOUNTPOINT} grub efibootmgr dosfstools 2>$ERR
    check_for_error "$FUNCNAME grub" $?

    DIALOG " Grub-install " --infobox "$_PlsWaitBody" 0 0
    # if root is encrypted, amend /etc/default/grub
    boot_encrypted_setting
    #install grub
    arch_chroot "grub-install --target=x86_64-efi --efi-directory=${UEFI_MOUNT} --bootloader-id=manjaro_grub --recheck" 2>$ERR
    check_for_error "grub-install --target=x86_64-efi" $?

    # If encryption used amend grub
    [[ $LUKS_DEV != "" ]] && sed -i "s~GRUB_CMDLINE_LINUX=.*~GRUB_CMDLINE_LINUX=\"$LUKS_DEV\"~g" ${MOUNTPOINT}/etc/default/grub

    # If root is on btrfs volume, amend grub
    [[ $(lsblk -lno FSTYPE,MOUNTPOINT | awk '/ \/mnt$/ {print $1}') == btrfs ]] && \
      sed -e '/GRUB_SAVEDEFAULT/ s/^#*/#/' -i ${MOUNTPOINT}/etc/default/grub

    # Generate config file
    arch_chroot "grub-mkconfig -o /boot/grub/grub.cfg" 2>$ERR
    check_for_error "grub-mkconfig" $?

    # Ask if user wishes to set Grub as the default bootloader and act accordingly
    DIALOG " $_InstUefiBtTitle " --yesno "$_SetBootDefBody ${UEFI_MOUNT}/EFI/boot $_SetBootDefBody2" 0 0
    if [[ $? -eq 0 ]]; then
        arch_chroot "mkdir ${UEFI_MOUNT}/EFI/boot" 2>$ERR
        arch_chroot "cp -r ${UEFI_MOUNT}/EFI/manjaro_grub/grubx64.efi ${UEFI_MOUNT}/EFI/boot/bootx64.efi" 2>$ERR
        check_for_error "Install GRUB" $?
        DIALOG " $_InstUefiBtTitle " --infobox "\nGrub $_SetDefDoneBody" 0 0
        sleep 2
    fi

<<DISABLED_FOR_NOW
    "systemd-boot")
        arch_chroot "bootctl --path=${UEFI_MOUNT} install" 2>$ERR
        check_for_error "systemd-boot" $?

        # Deal with LVM Root
        [[ $(echo $ROOT_PART | grep "/dev/mapper/") != "" ]] && bl_root=$ROOT_PART \
          || bl_root=$"PARTUUID="$(blkid -s PARTUUID ${ROOT_PART} | sed 's/.*=//g' | sed 's/"//g')

        # Create default config files. First the loader
        echo -e "default  arch\ntimeout  10" > ${MOUNTPOINT}${UEFI_MOUNT}/loader/loader.conf 2>$ERR

        # Second, the kernel conf files
        [[ -e ${MOUNTPOINT}/boot/initramfs-linux.img ]] && \
          echo -e "title\tManjaro Linux\nlinux\t/vmlinuz-linux\ninitrd\t/initramfs-linux.img\noptions\troot=${bl_root} rw" \
          > ${MOUNTPOINT}${UEFI_MOUNT}/loader/entries/arch.conf
        [[ -e ${MOUNTPOINT}/boot/initramfs-linux-lts.img ]] && \
          echo -e "title\tManjaro Linux LTS\nlinux\t/vmlinuz-linux-lts\ninitrd\t/initramfs-linux-lts.img\noptions\troot=${bl_root} rw" \
          > ${MOUNTPOINT}${UEFI_MOUNT}/loader/entries/arch-lts.conf
        [[ -e ${MOUNTPOINT}/boot/initramfs-linux-grsec.img ]] && \
          echo -e "title\tManjaro Linux Grsec\nlinux\t/vmlinuz-linux-grsec\ninitrd\t/initramfs-linux-grsec.img\noptions\troot=${bl_root} rw" \
          > ${MOUNTPOINT}${UEFI_MOUNT}/loader/entries/arch-grsec.conf
        [[ -e ${MOUNTPOINT}/boot/initramfs-linux-zen.img ]] && \
          echo -e "title\tManjaro Linux Zen\nlinux\t/vmlinuz-linux-zen\ninitrd\t/initramfs-linux-zen.img\noptions\troot=${bl_root} rw" \
          > ${MOUNTPOINT}${UEFI_MOUNT}/loader/entries/arch-zen.conf

        # Finally, amend kernel conf files for LUKS and BTRFS
        sysdconf=$(ls ${MOUNTPOINT}${UEFI_MOUNT}/loader/entries/arch*.conf)
        for i in ${sysdconf}; do
            [[ $LUKS_DEV != "" ]] && sed -i "s~rw~$LUKS_DEV rw~g" ${i}
        done
DISABLED_FOR_NOW

}

# Grub auto-detects installed kernels, etc. Syslinux does not, hence the extra code for it.
bios_bootloader() {
    DIALOG " $_InstBiosBtTitle " --menu "$_InstBiosBtBody" 0 0 2 \
      "grub" "-" \
      "grub + os-prober" "-" 2>${PACKAGES}
    clear

    # If something has been selected, act
    if [[ $(cat ${PACKAGES}) != "" ]]; then
        sed -i 's/+\|\"//g' ${PACKAGES}
        basestrap ${MOUNTPOINT} $(cat ${PACKAGES}) 2>$ERR
        check_for_error "$FUNCNAME" $?

        # If Grub, select device
        if [[ $(cat ${PACKAGES} | grep "grub") != "" ]]; then
            select_device
            # if root is encrypted, amend /etc/default/grub
            boot_encrypted_setting
            # If a device has been selected, configure
            if [[ $DEVICE != "" ]]; then
                DIALOG " Grub-install " --infobox "$_PlsWaitBody" 0 0
                arch_chroot "grub-install --target=i386-pc --recheck $DEVICE" 2>$ERR
                check_for_error "grub-install --target=i386-pc" $?

                # if /boot is LVM (whether using a seperate /boot mount or not), amend grub
                if ( [[ $LVM -eq 1 ]] && [[ $LVM_SEP_BOOT -eq 0 ]] ) || [[ $LVM_SEP_BOOT -eq 2 ]]; then
                    sed -i "s/GRUB_PRELOAD_MODULES=\"\"/GRUB_PRELOAD_MODULES=\"lvm\"/g" ${MOUNTPOINT}/etc/default/grub
                fi

                # If encryption used amend grub
                [[ $LUKS_DEV != "" ]] && sed -i "s~GRUB_CMDLINE_LINUX=.*~GRUB_CMDLINE_LINUX=\"$LUKS_DEV\"~g" ${MOUNTPOINT}/etc/default/grub

                # If root is on btrfs volume, amend grub
                [[ $(lsblk -lno FSTYPE,MOUNTPOINT | awk '/ \/mnt$/ {print $1}') == btrfs ]] && \
                  sed -e '/GRUB_SAVEDEFAULT/ s/^#*/#/' -i ${MOUNTPOINT}/etc/default/grub

                arch_chroot "grub-mkconfig -o /boot/grub/grub.cfg" 2>$ERR
                check_for_error "grub-mkconfig" $?
            fi
        else
            # Syslinux
            DIALOG " $_InstSysTitle " --menu "$_InstSysBody" 0 0 2 \
              "syslinux-install_update -iam" "[MBR]" "syslinux-install_update -i" "[/]" 2>${PACKAGES}

            # If an installation method has been chosen, run it
            if [[ $(cat ${PACKAGES}) != "" ]]; then
                arch_chroot "$(cat ${PACKAGES})" 2>$ERR
                check_for_error "syslinux-install" $?

                # Amend configuration file. First remove all existing entries, then input new ones.
                sed -i '/^LABEL.*$/,$d' ${MOUNTPOINT}/boot/syslinux/syslinux.cfg
                #echo -e "\n" >> ${MOUNTPOINT}/boot/syslinux/syslinux.cfg

                # First the "main" entries
                [[ -e ${MOUNTPOINT}/boot/initramfs-linux.img ]] && echo -e "\n\nLABEL arch\n\tMENU LABEL Manjaro Linux\n\tLINUX \
                  ../vmlinuz-linux\n\tAPPEND root=${ROOT_PART} rw\n\tINITRD ../initramfs-linux.img" >> ${MOUNTPOINT}/boot/syslinux/syslinux.cfg
                [[ -e ${MOUNTPOINT}/boot/initramfs-linux-lts.img ]] && echo -e "\n\nLABEL arch\n\tMENU LABEL Manjaro Linux realtime LTS\n\tLINUX \
                  ../vmlinuz-linux-lts\n\tAPPEND root=${ROOT_PART} rw\n\tINITRD ../initramfs-linux-lts.img" >> ${MOUNTPOINT}/boot/syslinux/syslinux.cfg
                [[ -e ${MOUNTPOINT}/boot/initramfs-linux-grsec.img ]] && echo -e "\n\nLABEL arch\n\tMENU LABEL Manjaro Linux realtime\n\tLINUX \
                  ../vmlinuz-linux-grsec\n\tAPPEND root=${ROOT_PART} rw\n\tINITRD ../initramfs-linux-grsec.img" >> ${MOUNTPOINT}/boot/syslinux/syslinux.cfg
                [[ -e ${MOUNTPOINT}/boot/initramfs-linux-zen.img ]] && echo -e "\n\nLABEL arch\n\tMENU LABEL Manjaro Linux release candidate\n\tLINUX \
                  ../vmlinuz-linux-zen\n\tAPPEND root=${ROOT_PART} rw\n\tINITRD ../initramfs-linux-zen.img" >> ${MOUNTPOINT}/boot/syslinux/syslinux.cfg

                # Second the "fallback" entries
                [[ -e ${MOUNTPOINT}/boot/initramfs-linux.img ]] && echo -e "\n\nLABEL arch\n\tMENU LABEL Manjaro Linux Fallback\n\tLINUX \
                  ../vmlinuz-linux\n\tAPPEND root=${ROOT_PART} rw\n\tINITRD ../initramfs-linux-fallback.img" >> ${MOUNTPOINT}/boot/syslinux/syslinux.cfg
                [[ -e ${MOUNTPOINT}/boot/initramfs-linux-lts.img ]] && echo -e "\n\nLABEL arch\n\tMENU LABEL Manjaro Linux Fallback realtime LTS\n\tLINUX \
                  ../vmlinuz-linux-lts\n\tAPPEND root=${ROOT_PART} rw\n\tINITRD ../initramfs-linux-lts-fallback.img" >> ${MOUNTPOINT}/boot/syslinux/syslinux.cfg
                [[ -e ${MOUNTPOINT}/boot/initramfs-linux-grsec.img ]] && echo -e "\n\nLABEL arch\n\tMENU LABEL Manjaro Linux Fallback realtime\n\tLINUX \
                  ../vmlinuz-linux-grsec\n\tAPPEND root=${ROOT_PART} rw\n\tINITRD ../initramfs-linux-grsec-fallback.img" \
                  >> ${MOUNTPOINT}/boot/syslinux/syslinux.cfg
                [[ -e ${MOUNTPOINT}/boot/initramfs-linux-zen.img ]] && echo -e "\n\nLABEL arch\n\tMENU LABEL Manjaro Linux Fallbacl Zen\n\tLINUX \
                  ../vmlinuz-linux-zen\n\tAPPEND root=${ROOT_PART} rw\n\tINITRD ../initramfs-linux-zen-fallback.img" >> ${MOUNTPOINT}/boot/syslinux/syslinux.cfg

                # Third, amend for LUKS
                [[ $LUKS_DEV != "" ]] && sed -i "s~rw~$LUKS_DEV rw~g" ${MOUNTPOINT}/boot/syslinux/syslinux.cfg

                # Finally, re-add the "default" entries
                echo -e "\n\nLABEL hdt\n\tMENU LABEL HDT (Hardware Detection Tool)\n\tCOM32 hdt.c32" >> ${MOUNTPOINT}/boot/syslinux/syslinux.cfg
                echo -e "\n\nLABEL reboot\n\tMENU LABEL Reboot\n\tCOM32 reboot.c32" >> ${MOUNTPOINT}/boot/syslinux/syslinux.cfg
                echo -e "\n\n#LABEL windows\n\t#MENU LABEL Windows\n\t#COM32 chain.c32\n\t#APPEND root=/dev/sda2 rw" \
                  >> ${MOUNTPOINT}/boot/syslinux/syslinux.cfg
                echo -e "\n\nLABEL poweroff\n\tMENU LABEL Poweroff\n\tCOM32 poweroff.c32" ${MOUNTPOINT}/boot/syslinux/syslinux.cfg
            fi
        fi
    fi
}

boot_encrypted_setting() {
    # Check if there is separate encrypted /boot partition 
    if $(lsblk | grep '/mnt/boot' | grep -q 'crypt' ); then
        echo "GRUB_ENABLE_CRYPTODISK=y" >> /mnt/etc/default/grub
    # Check if root is encrypted and there is no separate /boot
    elif $(lsblk | grep "/mnt$" | grep -q 'crypt' ) && [[ $(lsblk | grep "/mnt/boot$") == "" ]]; then
        echo "GRUB_ENABLE_CRYPTODISK=y" >> /mnt/etc/default/grub
    else
        true
    fi
}

# Function will not allow incorrect UUID type for installed system.
generate_fstab() {
    DIALOG " $_ConfBseFstab " --menu "$_FstabBody" 0 0 4 \
      "fstabgen -p" "$_FstabDevName" \
      "fstabgen -L -p" "$_FstabDevLabel" \
      "fstabgen -U -p" "$_FstabDevUUID" \
      "fstabgen -t PARTUUID -p" "$_FstabDevPtUUID" 2>${ANSWER}

    if [[ $(cat ${ANSWER}) != "" ]]; then
        if [[ $SYSTEM == "BIOS" ]] && [[ $(cat ${ANSWER}) == "fstabgen -t PARTUUID -p" ]]; then
            DIALOG " $_ErrTitle " --msgbox "$_FstabErr" 0 0
            generate_fstab
        else
            $(cat ${ANSWER}) ${MOUNTPOINT} > ${MOUNTPOINT}/etc/fstab 2>$ERR
            check_for_error "$FUNCNAME" $?
            [[ -f ${MOUNTPOINT}/swapfile ]] && sed -i "s/\\${MOUNTPOINT}//" ${MOUNTPOINT}/etc/fstab
        fi
    fi
}

run_mkinitcpio() {
    clear
    KERNEL=""

    # If LVM and/or LUKS used, add the relevant hook(s)
    ([[ $LVM -eq 1 ]] && [[ $LUKS -eq 0 ]]) && { sed -i 's/block filesystems/block lvm2 filesystems/g' ${MOUNTPOINT}/etc/mkinitcpio.conf 2>$ERR || check_for_error "lVM2 hooks" $?; }
    ([[ $LVM -eq 1 ]] && [[ $LUKS -eq 1 ]]) && { sed -i 's/block filesystems/block encrypt lvm2 filesystems/g' ${MOUNTPOINT}/etc/mkinitcpio.conf 2>$ERR || check_for_error "lVM/LUKS hooks" $?; }
    ([[ $LVM -eq 0 ]] && [[ $LUKS -eq 1 ]]) && { sed -i 's/block filesystems/block encrypt filesystems/g' ${MOUNTPOINT}/etc/mkinitcpio.conf 2>$ERR || check_for_error "LUKS hooks" $?; }
    
    arch_chroot "mkinitcpio -P" 2>$ERR
    check_for_error "$FUNCNAME" "$?"
}

# virtual console keymap
set_keymap() {
    KEYMAPS=""
    for i in $(ls -R /usr/share/kbd/keymaps | grep "map.gz" | sed 's/\.map\.gz//g' | sort); do
        KEYMAPS="${KEYMAPS} ${i} -"
    done

    DIALOG " $_VCKeymapTitle " --menu "$_VCKeymapBody" 20 40 16 ${KEYMAPS} 2>${ANSWER} || return 0
    KEYMAP=$(cat ${ANSWER})

    loadkeys $KEYMAP 2>$ERR
    check_for_error "loadkeys $KEYMAP" "$?"
    biggest_resolution=$(head -n 1 /sys/class/drm/card*/*/modes | awk -F'[^0-9]*' '{print $1}' | awk 'BEGIN{a=   0}{if ($1>a) a=$1 fi} END{print a}')
    # Choose terminus font size depending on resolution
    if [[ $biggest_resolution -gt 1920 ]]; then
        FONT=ter-124n
    elif [[ $biggest_resolution -eq 1920 ]]; then
        FONT=ter-118n
    else
        FONT=ter-114n
    fi
    echo -e "KEYMAP=${KEYMAP}\nFONT=${FONT}" > /tmp/vconsole.conf
}

# Set keymap for X11
set_xkbmap() {
    XKBMAP_LIST=""
    keymaps_xkb=("af al am at az ba bd be bg br bt bw by ca cd ch cm cn cz de dk ee es et eu fi fo fr\
      gb ge gh gn gr hr hu ie il in iq ir is it jp ke kg kh kr kz la lk lt lv ma md me mk ml mm mn mt mv\
      ng nl no np pc ph pk pl pt ro rs ru se si sk sn sy tg th tj tm tr tw tz ua us uz vn za")

    for i in ${keymaps_xkb}; do
        XKBMAP_LIST="${XKBMAP_LIST} ${i} -"
    done

    DIALOG " $_PrepKBLayout " --menu "$_XkbmapBody" 0 0 16 ${XKBMAP_LIST} 2>${ANSWER} || return 0
    XKBMAP=$(cat ${ANSWER} |sed 's/_.*//')
    echo -e "Section "\"InputClass"\"\nIdentifier "\"system-keyboard"\"\nMatchIsKeyboard "\"on"\"\nOption "\"XkbLayout"\" "\"${XKBMAP}"\"\nEndSection" \
      > ${MOUNTPOINT}/etc/X11/xorg.conf.d/00-keyboard.conf
}

# locale array generation code adapted from the Manjaro 0.8 installer
set_locale() {
    LOCALES=""
    for i in $(cat /etc/locale.gen | grep -v "#  " | sed 's/#//g' | sed 's/ UTF-8//g' | grep .UTF-8); do
        LOCALES="${LOCALES} ${i} -"
    done

    DIALOG " $_ConfBseSysLoc " --menu "$_localeBody" 0 0 12 ${LOCALES} 2>${ANSWER} || return 0

    LOCALE=$(cat ${ANSWER})

    echo "LANG=\"${LOCALE}\"" > ${MOUNTPOINT}/etc/locale.conf
    sed -i "s/#${LOCALE}/${LOCALE}/" ${MOUNTPOINT}/etc/locale.gen 2>$ERR
    arch_chroot "locale-gen" >/dev/null 2>$ERR
    check_for_error "$FUNCNAME" "$?"
}

# Set Zone and Sub-Zone
set_timezone() {
    ZONE=""
    for i in $(cat /usr/share/zoneinfo/zone.tab | awk '{print $3}' | grep "/" | sed "s/\/.*//g" | sort -ud); do
        ZONE="$ZONE ${i} -"
    done

    DIALOG " $_ConfBseTimeHC " --menu "$_TimeZBody" 0 0 10 ${ZONE} 2>${ANSWER} || return 0
    ZONE=$(cat ${ANSWER})

    SUBZONE=""
    for i in $(cat /usr/share/zoneinfo/zone.tab | awk '{print $3}' | grep "${ZONE}/" | sed "s/${ZONE}\///g" | sort -ud); do
        SUBZONE="$SUBZONE ${i} -"
    done

    DIALOG " $_ConfBseTimeHC " --menu "$_TimeSubZBody" 0 0 11 ${SUBZONE} 2>${ANSWER} || return 0
    SUBZONE=$(cat ${ANSWER})

    DIALOG " $_ConfBseTimeHC " --yesno "\n$_TimeZQ ${ZONE}/${SUBZONE}?\n\n" 0 0
    if (( $? == 0 )); then
        arch_chroot "ln -sf /usr/share/zoneinfo/${ZONE}/${SUBZONE} /etc/localtime" 2>$ERR
        check_for_error "$FUNCNAME ${ZONE}/${SUBZONE}" $?
    fi
}

set_hw_clock() {
    DIALOG " $_ConfBseTimeHC " --menu "$_HwCBody" 0 0 2 \
    "utc" "-" \
    "localtime" "-" 2>${ANSWER}

    if [[ $(cat ${ANSWER}) != "" ]]; then
        arch_chroot "hwclock --systohc --$(cat ${ANSWER})"  2>$ERR
        check_for_error "$FUNCNAME" "$?"
    fi
}

set_hostname() {
    DIALOG " $_ConfBseHost " --inputbox "$_HostNameBody" 0 0 "manjaro" 2>${ANSWER} || return 0

    echo "$(cat ${ANSWER})" > ${MOUNTPOINT}/etc/hostname 2>$ERR
    echo -e "#<ip-address>\t<hostname.domain.org>\t<hostname>\n127.0.0.1\tlocalhost.localdomain\tlocalhost\t$(cat \
      ${ANSWER})\n::1\tlocalhost.localdomain\tlocalhost\t$(cat ${ANSWER})" > ${MOUNTPOINT}/etc/hosts 2>$ERR
    check_for_error "$FUNCNAME"
}

# Adapted and simplified from the Manjaro 0.8 and Antergos 2.0 installers
set_root_password() {
    DIALOG " $_ConfUsrRoot " --clear --insecure --passwordbox "$_PassRtBody" 0 0 \
      2> ${ANSWER} || return 0
    PASSWD=$(cat ${ANSWER})

    DIALOG " $_ConfUsrRoot " --clear --insecure --passwordbox "$_PassReEntBody" 0 0 \
      2> ${ANSWER} || return 0
    PASSWD2=$(cat ${ANSWER})

    if [[ $PASSWD == $PASSWD2 ]]; then
        echo -e "${PASSWD}\n${PASSWD}" > /tmp/.passwd
        arch_chroot "passwd root" < /tmp/.passwd >/dev/null 2>$ERR
        check_for_error "$FUNCNAME" $?
        rm /tmp/.passwd
    else
        DIALOG " $_ErrTitle " --msgbox "$_PassErrBody" 0 0
        set_root_password
    fi
}

# Originally adapted from the Antergos 2.0 installer
create_new_user() {
    DIALOG " $_NUsrTitle " --inputbox "$_NUsrBody" 0 0 "" 2>${ANSWER} || return 0
    USER=$(cat ${ANSWER})

    # Loop while user name is blank, has spaces, or has capital letters in it.
    while [[ ${#USER} -eq 0 ]] || [[ $USER =~ \ |\' ]] || [[ $USER =~ [^a-z0-9\ ] ]]; do
        DIALOG " $_NUsrTitle " --inputbox "$_NUsrErrBody" 0 0 "" 2>${ANSWER} || return 0
        USER=$(cat ${ANSWER})
    done

    DIALOG " _NUsrTitle " --radiolist "\n$_DefShell\n$_UseSpaceBar" 0 0 3 \
      "zsh" "-" on \
      "bash" "-" off \
      "fish" "-" off 2>/tmp/.shell
    shell=$(cat /tmp/.shell)

    # Enter password. This step will only be reached where the loop has been skipped or broken.
    DIALOG " $_ConfUsrNew " --clear --insecure --passwordbox "$_PassNUsrBody $USER\n\n" 0 0 \
      2> ${ANSWER} || return 0
    PASSWD=$(cat ${ANSWER})

    DIALOG " $_ConfUsrNew " --clear --insecure --passwordbox "$_PassReEntBody" 0 0 \
      2> ${ANSWER} || return 0
    PASSWD2=$(cat ${ANSWER})

    # loop while passwords entered do not match.
    while [[ $PASSWD != $PASSWD2 ]]; do
        DIALOG " $_ErrTitle " --msgbox "$_PassErrBody" 0 0

        DIALOG " $_ConfUsrNew " --clear --insecure --passwordbox "$_PassNUsrBody $USER\n\n" 0 0 \
          2> ${ANSWER} || return 0
        PASSWD=$(cat ${ANSWER})

        DIALOG " $_ConfUsrNew " --clear --insecure --passwordbox "$_PassReEntBody" 0 0 \
          2> ${ANSWER} || return 0
        PASSWD2=$(cat ${ANSWER})
    done

    # create new user. This step will only be reached where the password loop has been skipped or broken.
    DIALOG " $_ConfUsrNew " --infobox "$_NUsrSetBody" 0 0
    sleep 2

    # Create the user, set password, then remove temporary password file
    arch_chroot "groupadd ${USER}"
    arch_chroot "useradd ${USER} -m -g ${USER} -G wheel,storage,power,network,video,audio,lp -s /bin/$shell" 2>$ERR
    check_for_error "add user to groups" $?
    echo -e "${PASSWD}\n${PASSWD}" > /tmp/.passwd
    arch_chroot "passwd ${USER}" < /tmp/.passwd >/dev/null 2>$ERR
    check_for_error "create user pwd" $?
    rm /tmp/.passwd

    # Set up basic configuration files and permissions for user
    #arch_chroot "cp /etc/skel/.bashrc /home/${USER}"
    arch_chroot "chown -R ${USER}:${USER} /home/${USER}"
    [[ -e ${MOUNTPOINT}/etc/sudoers ]] && sed -i '/%wheel ALL=(ALL) ALL/s/^#//' ${MOUNTPOINT}/etc/sudoers
}

setup_graphics_card() {
    # Main menu. Correct option for graphics card should be automatically highlighted.
    DIALOG " Choose video-driver to be installed " --radiolist "$_InstDEBody\n\n$_UseSpaceBar" 0 0 12 \
      $(mhwd -l | awk 'FNR>4 {print $1}' | awk 'NF' |awk '$0=$0" - off"')  2> /tmp/.driver || return 0

    clear
    arch_chroot "mhwd -f -i pci $(cat /tmp/.driver)" 2>$ERR
    check_for_error "install $(cat /tmp/.driver)" $?

    GRAPHIC_CARD=$(lspci | grep -i "vga" | sed 's/.*://' | sed 's/(.*//' | sed 's/^[ \t]*//')

    # All non-NVIDIA cards / virtualisation
    if [[ $(echo $GRAPHIC_CARD | grep -i 'intel\|lenovo') != "" ]]; then
        install_intel
    elif [[ $(echo $GRAPHIC_CARD | grep -i 'ati') != "" ]]; then
        install_ati
    elif [[ $(cat /tmp/.driver) == "video-nouveau" ]]; then
        sed -i 's/MODULES=""/MODULES="nouveau"/' ${MOUNTPOINT}/etc/mkinitcpio.conf
    fi
    check_for_error "$FUNCNAME $(cat /tmp/.driver)" "$?"
}

install_intel() {
    sed -i 's/MODULES=""/MODULES="i915"/' ${MOUNTPOINT}/etc/mkinitcpio.conf

    # Intel microcode (Grub, Syslinux and systemd-boot).
    # Done as seperate if statements in case of multiple bootloaders.
    if [[ -e ${MOUNTPOINT}/boot/grub/grub.cfg ]]; then
        DIALOG " grub-mkconfig " --infobox "$_PlsWaitBody" 0 0
        sleep 1
        arch_chroot "grub-mkconfig -o /boot/grub/grub.cfg" 2>$ERR
    fi
    # Syslinux
    [[ -e ${MOUNTPOINT}/boot/syslinux/syslinux.cfg ]] && sed -i "s/INITRD /&..\/intel-ucode.img,/g" ${MOUNTPOINT}/boot/syslinux/syslinux.cfg

    # Systemd-boot
    if [[ -e ${MOUNTPOINT}${UEFI_MOUNT}/loader/loader.conf ]]; then
        update=$(ls ${MOUNTPOINT}${UEFI_MOUNT}/loader/entries/*.conf)
        for i in ${upgate}; do
            sed -i '/linux \//a initrd \/intel-ucode.img' ${i}
        done
    fi
}

install_ati() {
    sed -i 's/MODULES=""/MODULES="radeon"/' ${MOUNTPOINT}/etc/mkinitcpio.conf
}
