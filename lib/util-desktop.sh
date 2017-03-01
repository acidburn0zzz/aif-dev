install_de_wm() {
    # Only show this information box once
    if [[ $SHOW_ONCE -eq 0 ]]; then
        DIALOG " $_InstDETitle " --msgbox "$_DEInfoBody" 0 0
        SHOW_ONCE=1
    fi

    # DE/WM Menu
    DIALOG " $_InstDETitle " --checklist "\n$_InstDEBody\n\n$_UseSpaceBar" 0 0 12 \
      "budgie-desktop" "-" off \
      "cinnamon" "-" off \
      "deepin" "-" off \
      "deepin-extra" "-" off \
      "enlightenment + terminology" "-" off \
      "gnome-shell" "-" off \
      "gnome" "-" off \
      "gnome-extra" "-" off \
      "plasma-desktop" "-" off \
      "plasma" "-" off \
      "kde-applications" "-" off \
      "lxde" "-" off \
      "lxqt + oxygen-icons" "-" off \
      "mate" "-" off \
      "mate-extra" "-" off \
      "mate-gtk3" "-" off \
      "mate-extra-gtk3" "-" off \
      "xfce4" "-" off \
      "xfce4-goodies" "-" off \
      "awesome + vicious" "-" off \
      "fluxbox + fbnews" "-" off \
      "i3-wm + i3lock + i3status" "-" off \
      "icewm + icewm-themes" "-" off \
      "openbox + openbox-themes" "-" off \
      "pekwm + pekwm-themes" "-" off \
      "windowmaker" "-" off 2>${PACKAGES}

    # If something has been selected, install
    if [[ $(cat ${PACKAGES}) != "" ]]; then
        clear
        sed -i 's/+\|\"//g' ${PACKAGES}
        basestrap ${MOUNTPOINT} $(cat ${PACKAGES}) 2>$ERR
        check_for_error "${FUNCNAME}: ${PACKAGES}" "$?"

        # Clear the packages file for installation of "common" packages
        echo "" > ${PACKAGES}

        # Offer to install various "common" packages.
        DIALOG " $_InstComTitle " --checklist "\n$_InstComBody\n\n$_UseSpaceBar" 0 50 14 \
          "bash-completion" "-" on \
          "gamin" "-" on \
          "gksu" "-" on \
          "gnome-icon-theme" "-" on \
          "gnome-keyring" "-" on \
          "gvfs" "-" on \
          "gvfs-afc" "-" on \
          "gvfs-smb" "-" on \
          "polkit" "-" on \
          "poppler" "-" on \
          "python2-xdg" "-" on \
          "ntfs-3g" "-" on \
          "ttf-dejavu" "-" on \
          "xdg-user-dirs" "-" on \
          "xdg-utils" "-" on \
          "xterm" "-" on 2>${PACKAGES}

        # If at least one package, install.
        if [[ $(cat ${PACKAGES}) != "" ]]; then
            clear
            basestrap ${MOUNTPOINT} $(cat ${PACKAGES}) 2>$ERR
            check_for_error "basestrap ${MOUNTPOINT} $(cat ${PACKAGES})" "$?" install_vanilla_de_wm
        fi
    fi

    return 0
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
            DIALOG "$_ExtraTitle" --no-cancel --menu "\n$_ExtraBody" 0 0 2 \
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
            check_for_error "install pkgs: $(cat /tmp/.desktop)" "$?" install_desktop_menu

            # copy the profile overlay to the new root
            echo "Copying overlay files to the new root"
            cp -r "$overlay"* ${MOUNTPOINT} 2>$ERR
            check_for_error "copy overlay" "$?"

            # Copy settings to root account
            cp -ar $MOUNTPOINT/etc/skel/. $MOUNTPOINT/root/ 2>$ERR
            check_for_error "copy root config" "$?" install_desktop_menu

            # copy settings to already created users
            if [[ -e "$(echo /mnt/home/*)" ]]; then
            for home in $(echo $MOUNTPOINT/home/*); do
                cp -ar $MOUNTPOINT/etc/skel/. $home/
                user=$(echo $home | cut -d/ -f4)
                arch_chroot "chown -R ${user}:${user} $home"
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
                    arch_chroot "rc-update add $service default"
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
                    echo "no display manager was installed"
                    sleep 2
                fi
            else
                eval $(grep -e "enable_systemd=" $profile | sed 's/# //g')
                echo "${enable_systemd[@]}" | xargs -n1 > /tmp/.services
                echo /mnt/usr/lib/systemd/system/* | xargs -n1 | cut -d/ -f7 | sed 's/.service//g' > /tmp/.available_services
                grep -f /tmp/.available_services /tmp/.services > /tmp/.fix && mv /tmp/.fix /tmp/.services
                arch_chroot "systemctl enable $(cat /tmp/.services)"
                arch_chroot "systemctl disable pacman-init" 
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
                check_for_error "basestrap -i ${MOUNTPOINT} $(cat ${PACKAGES})" "$?" install_desktop_menu
            fi
    fi
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
    check_for_error "update profiles pkgs" $? install_graphics_menu

    install_manjaro_de_wm
}

install_manjaro_de_wm_git() {
    PROFILES="$DATADIR/profiles"
    # Only show this information box once
    if [[ $SHOW_ONCE -eq 0 ]]; then
        DIALOG " $_InstDETitle " --msgbox "\n$_InstPBody\n\n" 0 0
        SHOW_ONCE=1
    fi
    clear
    # install git if not already installed
    inst_needed git
    # download manjaro-tools.-isoprofiles git repo
    if [[ -e $PROFILES ]]; then
        git -C $PROFILES pull 2>$ERR
        check_for_error "pull profiles repo" $? install_graphics_menu
    else
        git clone --depth 1 https://github.com/manjaro/iso-profiles.git $PROFILES 2>$ERR
        check_for_error "clone profiles repo" $? install_graphics_menu
    fi

    install_manjaro_de_wm
}

# Display Manager
install_dm() {
    if [[ $DM_ENABLED -eq 0 ]]; then
        # Prep variables
        echo "" > ${PACKAGES}
        dm_list="gdm lxdm lightdm sddm"
        DM_LIST=""
        DM_INST=""

        # Generate list of DMs installed with DEs, and a list for selection menu
        for i in ${dm_list}; do
            [[ -e ${MOUNTPOINT}/usr/bin/${i} ]] && DM_INST="${DM_INST} ${i}"
            DM_LIST="${DM_LIST} ${i} -"
        done

        DIALOG " $_DmChTitle " --menu "$_AlreadyInst$DM_INST\n\n$_DmChBody" 0 0 4 \
          ${DM_LIST} 2>${PACKAGES}
        clear

        # If a selection has been made, act
        if [[ $(cat ${PACKAGES}) != "" ]]; then
            # check if selected dm already installed. If so, enable and break loop.
            for i in ${DM_INST}; do
                if [[ $(cat ${PACKAGES}) == ${i} ]]; then
                    enable_dm
                    break;
                fi
            done

            # If no match found, install and enable DM
            if [[ $DM_ENABLED -eq 0 ]]; then
                # Where lightdm selected, add gtk greeter package
                sed -i 's/lightdm/lightdm lightdm-gtk-greeter/' ${PACKAGES}
                basestrap ${MOUNTPOINT} $(cat ${PACKAGES}) 2>$ERR

                # Where lightdm selected, now remove the greeter package
                sed -i 's/lightdm-gtk-greeter//' ${PACKAGES}
                enable_dm
            fi
        fi
    fi

    # Show after successfully installing or where attempting to repeat when already completed.
    [[ $DM_ENABLED -eq 1 ]] && DIALOG " $_DmChTitle " --msgbox "$_DmDoneBody" 0 0

    return 0
}

enable_dm() {
    if [[ -e /mnt/.openrc ]]; then
        sed -i "s/$(grep "DISPLAYMANAGER=" /mnt/etc/conf.d/xdm)/DISPLAYMANAGER=\"$(cat ${PACKAGES})\"/g" /mnt/etc/conf.d/xdm
        arch_chroot "rc-update add xdm default" 2>$ERR
        check_for_error "$FUNCNAME" "$?"
        DM=$(cat ${PACKAGES})
        DM_ENABLED=1
    else 
        # enable display manager for systemd
        arch_chroot "systemctl enable $(cat ${PACKAGES})" 2>$ERR
        check_for_error "$FUNCNAME" "$?"
        DM=$(cat ${PACKAGES})
        DM_ENABLED=1
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
    arch_chroot "gpasswd -a sddm video &> /dev/null"
}

# Network Manager
install_nm() {
    if [[ $NM_ENABLED -eq 0 ]]; then
        # Prep variables
        echo "" > ${PACKAGES}
        nm_list="connman CLI dhcpcd CLI netctl CLI NetworkManager GUI wicd GUI"
        NM_LIST=""
        NM_INST=""

        # Generate list of DMs installed with DEs, and a list for selection menu
        for i in ${nm_list}; do
            [[ -e ${MOUNTPOINT}/usr/bin/${i} ]] && NM_INST="${NM_INST} ${i}"
            NM_LIST="${NM_LIST} ${i}"
        done

        # Remove netctl from selectable list as it is a PITA to configure via arch_chroot
        NM_LIST=$(echo $NM_LIST | sed "s/netctl CLI//")

        DIALOG " $_InstNMTitle " --menu "$_AlreadyInst $NM_INST\n$_InstNMBody" 0 0 4 \
          ${NM_LIST} 2> ${PACKAGES}
        clear

        # If a selection has been made, act
        if [[ $(cat ${PACKAGES}) != "" ]]; then
            # check if selected nm already installed. If so, enable and break loop.
            for i in ${NM_INST}; do
                [[ $(cat ${PACKAGES}) == ${i} ]] && enable_nm && break
            done

            # If no match found, install and enable NM
            if [[ $NM_ENABLED -eq 0 ]]; then
                # Where networkmanager selected, add network-manager-applet
                sed -i 's/NetworkManager/networkmanager network-manager-applet/g' ${PACKAGES}
                basestrap ${MOUNTPOINT} $(cat ${PACKAGES}) 2>$ERR
                check_for_error "$FUNCNAME" "$?" install_network_menu

                # Where networkmanager selected, now remove network-manager-applet
                sed -i 's/networkmanager network-manager-applet/NetworkManager/g' ${PACKAGES}
                enable_nm
            fi
        fi
    fi

    # Show after successfully installing or where attempting to repeat when already completed.
    [[ $NM_ENABLED -eq 1 ]] && DIALOG " $_InstNMTitle " --msgbox "$_InstNMErrBody" 0 0

    return 0
}

enable_nm() {
    # Add openrc support. If openrcbase was installed, the file /mnt/.openrc should exist.
    if [[ $(cat ${PACKAGES}) == "NetworkManager" ]]; then
        if [[ -e /mnt/.openrc ]]; then
        arch_chroot "rc-update add NetworkManager default" 2>$ERR
        else
        arch_chroot "systemctl enable NetworkManager NetworkManager-dispatcher" >/tmp/.symlink 2>$ERR
        fi
    else
        if [[ -e /mnt/.openrc ]]; then
        arch_chroot "rc-update add $(cat ${PACKAGES}) default" 2>$ERR
        else            
        arch_chroot "systemctl enable $(cat ${PACKAGES})" 2>$ERR
        fi
    fi
    check_for_error "$FUNCNAME" "$?" install_network_menu
    NM_ENABLED=1
}

install_multimedia_menu() {
    declare -i loopmenu=1
    while ((loopmenu)); do
        local PARENT="$FUNCNAME"

        submenu 5
        DIALOG "$_InstMultMenuBody" --default-item ${HIGHLIGHT_SUB} --menu " $_InstMultMenuTitle " 0 0 5 \
          "1" "$_InstMulSnd" \
          "2" "$_InstMulCodec" \
          "3" "$_InstMulAcc" \
          "4" "$_InstMulCust" \
          "5" "$_Back" 2>${ANSWER}

        HIGHLIGHT_SUB=$(cat ${ANSWER})
        case $(cat ${ANSWER}) in
            "1") install_alsa_pulse
                ;;
            "2") install_codecs
                ;;
            "3") install_acc_menu
                ;;
            "4") install_cust_pkgs
                ;;
            *) loopmenu=0
                ;;
        esac
    done

    return 0
}

install_alsa_pulse() {
    # Prep Variables
    echo "" > ${PACKAGES}
    ALSA=""
    PULSE_EXTRA=""
    alsa=$(pacman -Ss alsa | awk '{print $1}' | grep "/alsa-" | sed "s/extra\///g" | sort -u)
    pulse_extra=$(pacman -Ss pulseaudio- | awk '{print $1}' | sed "s/extra\///g" | grep "pulseaudio-" | sort -u)

    for i in ${alsa}; do
        ALSA="${ALSA} ${i} - off"
    done

    ALSA=$(echo $ALSA | sed "s/alsa-utils - off/alsa-utils - on/g" | sed "s/alsa-plugins - off/alsa-plugins - on/g")

    for i in ${pulse_extra}; do
        PULSE_EXTRA="${PULSE_EXTRA} ${i} - off"
    done

    DIALOG " $_InstMulSnd " --checklist "$_InstMulSndBody\n\n$_UseSpaceBar" 0 0 6 \
      $ALSA "pulseaudio" "-" off $PULSE_EXTRA \
      "paprefs" "pulseaudio GUI" off \
      "pavucontrol" "pulseaudio GUI" off \
      "ponymix" "pulseaudio CLI" off \
      "volumeicon" "ALSA GUI" off \
      "volwheel" "ASLA GUI" off 2>${PACKAGES}

    clear
    # If at least one package, install.
    if [[ $(cat ${PACKAGES}) != "" ]]; then
        basestrap ${MOUNTPOINT} $(cat ${PACKAGES}) 2>$ERR
        check_for_error "$FUNCNAME" "$?" install_multimedia_menu
    fi

    return 0
}

install_codecs() {
    # Prep Variables
    echo "" > ${PACKAGES}
    GSTREAMER=""
    gstreamer=$(pacman -Ss gstreamer | awk '{print $1}' | grep "/gstreamer" | sed "s/extra\///g" | sed "s/community\///g" | sort -u)
    echo $gstreamer
    for i in ${gstreamer}; do
        GSTREAMER="${GSTREAMER} ${i} - off"
    done

    DIALOG " $_InstMulCodec " --checklist "$_InstMulCodBody\n\n$_UseSpaceBar" 0 0 14 \
    $GSTREAMER "xine-lib" "-" off 2>${PACKAGES}

    clear
    # If at least one package, install.
    if [[ $(cat ${PACKAGES}) != "" ]]; then
        basestrap ${MOUNTPOINT} $(cat ${PACKAGES}) 2>$ERR
        check_for_error "$FUNCNAME" "$?" install_multimedia_menu
    fi

    return 0
}

install_cust_pkgs() {
    echo "" > ${PACKAGES}
    DIALOG " $_InstMulCust " --inputbox "$_InstMulCustBody" 0 0 "" 2>${PACKAGES} || install_multimedia_menu

    clear
    # If at least one package, install.
    if [[ $(cat ${PACKAGES}) != "" ]]; then
        if [[ $(cat ${PACKAGES}) == "hen poem" ]]; then
            DIALOG " \"My Sweet Buckies\" by Atiya & Carl " --msgbox "\nMy Sweet Buckies,\nYou are the sweetest Buckies that ever did \"buck\",\nLily, Rosie, Trumpet, and Flute,\nMy love for you all is absolute!\n\nThey buck: \"We love our treats, we are the Booyakka sisters,\"\n\"Sometimes we squabble and give each other comb-twisters,\"\n\"And in our garden we love to sunbathe, forage, hop and jump,\"\n\"We love our freedom far, far away from that factory farm dump,\"\n\n\"For so long we were trapped in cramped prisons full of disease,\"\n\"No sunlight, no fresh air, no one who cared for even our basic needs,\"\n\"We suffered in fear, pain, and misery for such a long time,\"\n\"But now we are so happy, we wanted to tell you in this rhyme!\"\n\n" 0 0
        else
            basestrap ${MOUNTPOINT} $(cat ${PACKAGES}) 2>$ERR
            check_for_error "$FUNCNAME $(cat ${PACKAGES})" "$?" install_multimedia_menu
        fi
    fi

    return 0
}
