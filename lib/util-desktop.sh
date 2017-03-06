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

setup_graphics_card() {
    # Main menu. Correct option for graphics card should be automatically highlighted.
    DIALOG " $_InstGrDrv " --radiolist "$_InstDEBody\n\n$_UseSpaceBar" 0 0 12 \
      $(mhwd -l | awk 'FNR>4 {print $1}' | awk 'NF' |awk '$0=$0" - off"')  2> /tmp/.driver || return 0

    if [[ $(cat /tmp/.driver) != "" ]]; then
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
    else
        DIALOG " $_ErrTitle " --msgbox "\n\n$_WarnInstGr\n" 0 0
        check_for_error "No video-driver selected."
    fi
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
      > ${MOUNTPOINT}/etc/X11/xorg.conf.d/00-keyboard.conf 2>$ERR
    check_for_error "$FUNCNAME ${XKBMAP}" "$?"
}

install_manjaro_de_wm_pkg() {
    PROFILES="/usr/share/manjaro-tools/iso-profiles"
    # Only show this information box once
    if [[ $SHOW_ONCE -eq 0 ]]; then
        DIALOG " $_InstDETitle " --msgbox "\n$_InstPBody\n\n" 0 0
        SHOW_ONCE=1
    fi
    clear
    pacman -Sy --noconfirm $p manjaro-iso-profiles-{base,official,community} 2>$ERR
    check_for_error "update profiles pkgs" $?

    install_manjaro_de_wm
}

install_manjaro_de_wm() {
    # Clear packages after installing base
    echo "" > /tmp/.desktop

    # DE/WM Menu
    DIALOG " $_InstDETitle " --radiolist "\n$_InstManDEBody\n$(evaluate_profiles)\n\n$_UseSpaceBar" 0 0 12 \
      $(echo $PROFILES/{manjaro,community}/* | xargs -n1 | cut -f7 -d'/' | grep -vE "netinstall|architect" | awk '$0=$0" - off"')  2> /tmp/.desktop

    # If something has been selected, install
    if [[ $(cat /tmp/.desktop) != "" ]]; then
        check_for_error "selected: [Manjaro-$(cat /tmp/.desktop)]"
        clear
        # Source the iso-profile
        profile=$(echo $PROFILES/*/$(cat /tmp/.desktop)/profile.conf)
        . $profile        
        overlay=$(echo $PROFILES/*/$(cat /tmp/.desktop)/desktop-overlay/)
        echo $displaymanager > /tmp/.display-manager
        target_desktop=$(echo $PROFILES/*/$(cat /tmp/.desktop)/Packages-Desktop)

        # Parse package list based on user input and remove parts that don't belong to pacman
        cat $PROFILES/shared/Packages-Root "$target_desktop" > /tmp/.edition
        if [[ -e /mnt/.openrc ]]; then
            evaluate_openrc
            # Remove any packages tagged with >systemd and remove >openrc tags
            sed -i '/>systemd/d' /tmp/.edition
            sed -i 's/>openrc //g' /tmp/.edition
        else
            # Remove any packages tagged with >openrc and remove >systemd tags
            sed -i '/>openrc/d' /tmp/.edition
            sed -i 's/>systemd //g' /tmp/.edition
        fi

        if [[ "$(uname -m)" == "x86_64" ]]; then
            # Remove any packages tagged with >i686 and remove >x86_64 tags
            sed -i '/>i686/d' /tmp/.edition
            sed -i '/>nonfree_i686/d' /tmp/.edition
            sed -i 's/>x86_64 //g' /tmp/.edition
        else
            # Remove any packages tagged with >x86_64 and remove >i686 tags
            sed -i '/>x86_64/d' /tmp/.edition
            sed -i '/>nonfree_x86_64/d' /tmp/.edition
            sed -i 's/>i686 //g' /tmp/.edition
        fi

        # If multilib repo is enabled, install multilib packages
        if grep -q "^[multilib]" ${MOUNTPOINT}/etc/pacman.conf ; then
            # Remove >multilib tags
            sed -i 's/>multilib //g' /tmp/.edition
            sed -i 's/>nonfree_multilib //g' /tmp/.edition
        else
            # Remove lines with >multilib tag
            sed -i '/>multilib/d' /tmp/.edition
            sed -i '/>nonfree_multilib/d' /tmp/.edition
        fi

        if grep -q ">extra" /tmp/.edition;then
            # User to select base|extra profile
            DIALOG " $_ExtraTitle " --no-cancel --menu "\n$_ExtraBody" 0 0 2 \
              "1" "full" \
              "2" "minimal" 2>/tmp/.version

            if [[ $(cat /tmp/.version) -eq 2 ]]; then
                check_for_error "selected 'minimal' profile"
                touch /tmp/.minimal
            else
                check_for_error "selected 'full' profile"
                [[ -e /tmp/.minimal ]] && rm /tmp/.minimal
            fi
        fi

        if [[ -e /tmp/.minimal ]]; then
            # Remove >extra tags
            sed -i 's/>basic //g' /tmp/.edition
            sed -i '/>extra/d' /tmp/.edition
        else
            # Remove >basic tags
            sed -i 's/>extra //g' /tmp/.edition
            sed -i '/>basic/d' /tmp/.edition
        fi
        # remove >manjaro flags and >sonar flags+pkgs until we support it properly
        sed -i '/>sonar/d' /tmp/.edition
        sed -i 's/>manjaro //g' /tmp/.edition
        # Remove commented lines
        # remove everything except the first word of every lines
        sed -i 's/\s.*$//' /tmp/.edition
        # Remove lines with #
        sed -i '/#/d' /tmp/.edition
        # remove KERNEL variable
        sed -i '/KERNEL/d' /tmp/.edition
        # Remove empty lines
        sed -i '/^\s*$/d' /tmp/.edition

        # Remove base-devel and base packages. Base is already installed and base-devel should be decided by the user
        # pacman -Sgq base-devel base openrc-base > /tmp/.notincluded
        # grep -v -f /tmp/.notincluded /tmp/.edition | grep -v "base-devel" > /tmp/.tmp
        # mv /tmp/.tmp /tmp/.edition
        # Remove packages that have been dropped from repos
        pacman -Ssq > /tmp/.available_packages
        grep -f /tmp/.available_packages /tmp/.edition > /tmp/.tmp
        mv /tmp/.tmp /tmp/.edition
        # remove zsh
        sed -i '/^zsh$/d' /tmp/.edition

        check_for_error "packages to install: $(grep -v -f /mnt/.base /tmp/.edition | sort | uniq | tr '\n' ' ')"

        clear
        # remove already installed base pkgs and
        # basestrap the parsed package list to the new root
        basestrap -i ${MOUNTPOINT} $(grep -v -f /mnt/.base /tmp/.edition | sort | uniq) 2>$ERR
        check_for_error "install pkgs: $(cat /tmp/.desktop)" "$?"

        # copy the profile overlay to the new root
        echo "Copying overlay files to the new root"
        cp -r "$overlay"* ${MOUNTPOINT} 2>$ERR
        check_for_error "copy overlay" "$?"

        # Copy settings to root account
        cp -ar $MOUNTPOINT/etc/skel/. $MOUNTPOINT/root/ 2>$ERR
        check_for_error "copy root config" "$?"

        # copy settings to already created users
        if [[ -e "$(echo /mnt/home/*)" ]]; then
            for home in $(echo $MOUNTPOINT/home/*); do
                cp -ar $MOUNTPOINT/etc/skel/. $home/
                user=$(echo $home | cut -d/ -f4)
                arch_chroot "chown -R ${user}:${user} /home/${user}"
            done
        fi
        # Enable services in the chosen profile
        echo "Enabling services"
        if [[ -e /mnt/.openrc ]]; then
            eval $(grep -e "enable_openrc=" $profile | sed 's/# //g')
            echo "${enable_openrc[@]}" | xargs -n1 > /tmp/.services
            echo /mnt/etc/init.d/* | xargs -n1 | cut -d/ -f5 > /tmp/.available_services
            grep -f /tmp/.available_services /tmp/.services > /tmp/.fix && mv /tmp/.fix /tmp/.services
            for service in $(cat /tmp/.services) ; do
                arch_chroot "rc-update add $service default" 2>$ERR
                check_for_error "enable $service" $?
            done

            # enable display manager for openrc
            if [[ "$(cat /tmp/.display-manager)" == sddm ]]; then
                sed -i "s/$(grep "DISPLAYMANAGER=" /mnt/etc/conf.d/xdm)/DISPLAYMANAGER=\"sddm\"/g" /mnt/etc/conf.d/xdm
                arch_chroot "rc-update add xdm default" 2>$ERR
                check_for_error "add xdm default: sddm" "$?"
                set_sddm_ck
            elif [[ "$(cat /tmp/.display-manager)" == lightdm ]]; then
                set_lightdm_greeter
                sed -i "s/$(grep "DISPLAYMANAGER=" /mnt/etc/conf.d/xdm)/DISPLAYMANAGER=\"lightdm\"/g" /mnt/etc/conf.d/xdm
                arch_chroot "rc-update add xdm default" 2>$ERR
                check_for_error "add xdm default: lightdm" "$?"

            else
                check_for_error "no DM installed."
                echo "no display manager was installed."
                sleep 2
            fi
        else
            eval $(grep -e "enable_systemd=" $profile | sed 's/# //g')
            echo "${enable_systemd[@]}" | xargs -n1 > /tmp/.services
            echo /mnt/usr/lib/systemd/system/* | xargs -n1 | cut -d/ -f7 | sed 's/.service//g' > /tmp/.available_services
            grep -f /tmp/.available_services /tmp/.services > /tmp/.fix && mv /tmp/.fix /tmp/.services
            arch_chroot "systemctl enable $(cat /tmp/.services)" 2>$ERR
            check_for_error "enable $(cat /tmp/.services)" $?
            arch_chroot "systemctl disable pacman-init" 2>$ERR
            check_for_error "disable pacman-init" $?

            # enable display manager for systemd
            if [[ "$(cat /tmp/.display-manager)" == lightdm ]]; then
                set_lightdm_greeter
                arch_chroot "systemctl enable lightdm" 2>$ERR
                check_for_error "enable lightdm" "$?"
            elif [[ "$(cat /tmp/.display-manager)" == sddm ]]; then
                arch_chroot "systemctl enable sddm" 2>$ERR
                check_for_error "enable sddm" "$?"
            elif [[ "$(cat /tmp/.display-manager)" == gdm ]]; then
                arch_chroot "systemctl enable gdm" 2>$ERR
                check_for_error "enable gdm" "$?"
            else
                check_for_error "no DM installed."
                echo "no display manager was installed"
                sleep 2
            fi
        fi

        # Stop for a moment so user can see if there were errors
        echo ""
        echo ""
        echo ""
        echo "press Enter to continue"
        read
        # Clear the packages file for installation of "common" packages
        echo "" > ${PACKAGES}

        # Offer to install various "common" packages.

        DIALOG " $_InstComTitle " --checklist "\n$_InstComBody\n\n$_UseSpaceBar" 0 50 20 \
          "manjaro-settings-manager" "-" off \
          "pamac" "-" off \
          "octopi" "-" off \
          "pacli" "-" off \
          "pacui" "-" off \
          "fish" "-" off \
          "fisherman" "-" off \
          "zsh" "-" on \
          "zsh-completions" "-" on \
          "manjaro-zsh-config" "-" on \
          "grml-zsh-config" "-" off \
          "mhwd-chroot" "-" off \
          "bmenu" "-" on \
          "clonezilla" "-" off \
          "snapper" "-" off \
          "snap-pac" "-" off \
          "manjaro-tools-iso" "-" off \
          "manjaro-tools-base" "-" off \
          "manjaro-tools-pkg" "-" off 2>${PACKAGES}

        # If at least one package, install.
        if [[ $(cat ${PACKAGES}) != "" ]]; then
            clear
            basestrap -i ${MOUNTPOINT} $(cat ${PACKAGES}) 2>$ERR
            check_for_error "basestrap -i ${MOUNTPOINT} $(cat ${PACKAGES})" "$?"
        fi
    fi
}

set_lightdm_greeter() {
    local greeters=$(ls /mnt/usr/share/xgreeters/*greeter.desktop) name
    for g in ${greeters[@]}; do
        name=${g##*/}
        name=${name%%.*}
        case ${name} in
            lightdm-gtk-greeter)
                break
                ;;
            lightdm-*-greeter)
                sed -i -e "s/^.*greeter-session=.*/greeter-session=${name}/" /mnt/etc/lightdm/lightdm.conf
                ;;
        esac
    done
}

set_sddm_ck() {
    local halt='/usr/bin/shutdown -h -P now' \
      reboot='/usr/bin/shutdown -r now'
    sed -e "s|^.*HaltCommand=.*|HaltCommand=${halt}|" \
      -e "s|^.*RebootCommand=.*|RebootCommand=${reboot}|" \
      -e "s|^.*MinimumVT=.*|MinimumVT=7|" \
      -i "/mnt/etc/sddm.conf"
    arch_chroot "gpasswd -a sddm video &> /dev/null" 2>$ERR
    check_for_error "$FUNCNAME" $?
}
