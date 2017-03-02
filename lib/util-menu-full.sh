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

main_menu_full() {
    declare -i loopmenu=1
    while ((loopmenu)); do
        if [[ $HIGHLIGHT != 9 ]]; then
           HIGHLIGHT=$(( HIGHLIGHT + 1 ))
        fi

        DIALOG " $_MMTitle " --default-item ${HIGHLIGHT} \
          --menu "$_MMBody" 0 0 9 \
          "1" "$_PrepMenuTitle|>" \
          "2" "$_InstBsMenuTitle|>" \
          "3" "$_InstGrMenuTitle|>" \
          "4" "$_ConfBseMenuTitle|>" \
          "5" "$_InstNMMenuTitle|>" \
          "6" "$_InstMultMenuTitle|>" \
          "7" "$_SecMenuTitle|>" \
          "8" "$_SeeConfOptTitle|>" \
          "9" "$_Done" 2>${ANSWER}

        HIGHLIGHT=$(cat ${ANSWER})
        case $(cat ${ANSWER}) in
            "1") prep_menu
                ;;
            "2") check_mount && install_base_menu
                ;;
            "3") check_base && install_graphics_menu_full
                ;;
            "4") check_base && config_base_menu
                ;;
            "5") check_base && install_network_menu
                ;;
            "6") check_base && install_multimedia_menu
                ;;
            "7") check_base && security_menu
                ;;
            "8") check_base && edit_configs
                ;;
             *) loopmenu=0
                exit_done
                ;;
        esac
    done
}

install_graphics_menu_full() {
    local PARENT="$FUNCNAME"
    declare -i loopmenu=1
    while ((loopmenu)); do
        submenu 4
        DIALOG " $_InstGrMenuTitle " --default-item ${HIGHLIGHT_SUB} \
          --menu "$_InstGrMenuBody" 0 0 4 \
          "1" "$_InstGrMenuDD" \
          "2" "$_InstGrMenuGE|>" \
          "3" "$_PrepKBLayout" \
          "4" "$_Back" 2>${ANSWER}
        HIGHLIGHT_SUB=$(cat ${ANSWER})

        case $(cat ${ANSWER}) in
            "1") setup_graphics_card
                ;;
            "2") install_desktop_menu
                ;;
            "3") set_xkbmap
                ;;
            *) loopmenu=0
                return 0
                ;;
        esac
    done
}

install_desktop_menu() {
    local PARENT="$FUNCNAME"
    declare -i loopmenu=1
    while ((loopmenu)); do
        submenu 4
        DIALOG " $_InstGrMenuTitle " --default-item ${HIGHLIGHT_SUB} \
          --menu "$_InstDEMenuTitle" 0 0 4 \
          "1" "$_InstDEStable" \
          "2" "$_InstDEGit" \
          "3" "$_InstDE|>" \
          "4" "$_Back" 2>${ANSWER}
        HIGHLIGHT_SUB=$(cat ${ANSWER})

        case $(cat ${ANSWER}) in
            "1") install_manjaro_de_wm_pkg
                ;;
            "2") install_manjaro_de_wm_git
                ;;
            "3") install_vanilla_de_wm
                ;;
            *) loopmenu=0 
                return 0
                ;;
        esac
    done
}

install_vanilla_de_wm() {
    local PARENT="$FUNCNAME"
    declare -i loopmenu=1
    while ((loopmenu)); do
        submenu 4
        DIALOG " $_InstGrMenuTitle " --default-item ${HIGHLIGHT_SUB} \
          --menu "$_InstGrMenuBody" 0 0 4 \
          "1" "$_InstGrMenuDS" \
          "2" "$_InstGrDE" \
          "3" "$_InstGrMenuDM" \
          "4" "$_Back" 2>${ANSWER}
        HIGHLIGHT_SUB=$(cat ${ANSWER})

        case $(cat ${ANSWER}) in
            "1") install_xorg_input
                 ;;
            "2") install_de_wm
                 ;;
            "3") install_dm
                 ;;
            *) loopmenu=0
                return 0
                 ;;
        esac 
    done
}

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
            check_for_error "basestrap ${MOUNTPOINT} $(cat ${PACKAGES})" "$?"
        fi
    fi
}

install_network_menu() {
    declare -i loopmenu=1
    while ((loopmenu)); do
        local PARENT="$FUNCNAME"
        
        submenu 5
        DIALOG " $_InstNMMenuTitle " --default-item ${HIGHLIGHT_SUB} --menu "$_InstNMMenuBody" 0 0 5 \
          "1" "$_SeeWirelessDev" \
          "2" "$_InstNMMenuPkg" \
          "3" "$_InstNMMenuNM" \
          "4" "$_InstNMMenuCups" \
          "5" "$_Back" 2>${ANSWER}

        case $(cat ${ANSWER}) in
            "1") # Identify the Wireless Device
                lspci -k | grep -i -A 2 "network controller" > /tmp/.wireless
                if [[ $(cat /tmp/.wireless) != "" ]]; then
                    DIALOG " $_WirelessShowTitle " --textbox /tmp/.wireless 0 0
                else
                    DIALOG " $_WirelessShowTitle " --msgbox "$_WirelessErrBody" 7 30
                fi
                ;;
            "2") install_wireless_packages
                ;;
            "3") install_nm
                ;;
            "4") install_cups
                ;;
            *) loopmenu=0
                return 0
                ;;
        esac
    done
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
}

# Install Accessibility Applications
install_acc_menu() {
    echo "" > ${PACKAGES}

    DIALOG " $_InstAccTitle " --checklist "$_InstAccBody" 0 0 15 \
      "accerciser" "-" off \
      "at-spi2-atk" "-" off \
      "at-spi2-core" "-" off \
      "brltty" "-" off \
      "caribou" "-" off \
      "dasher" "-" off \
      "espeak" "-" off \
      "espeakup" "-" off \
      "festival" "-" off \
      "java-access-bridge" "-" off \
      "java-atk-wrapper" "-" off \
      "julius" "-" off \
      "orca" "-" off \
      "qt-at-spi" "-" off \
      "speech-dispatcher" "-" off 2>${PACKAGES}

    clear
    # If something has been selected, install
    if [[ $(cat ${PACKAGES}) != "" ]]; then
        basestrap ${MOUNTPOINT} ${PACKAGES} 2>$ERR
        check_for_error "$FUNCNAME" $? || return $?
    fi
}

security_menu() {
    declare -i loopmenu=1
    while ((loopmenu)); do
        local PARENT="$FUNCNAME"

        submenu 4
        DIALOG " $_SecMenuTitle " --default-item ${HIGHLIGHT_SUB} \
          --menu "$_SecMenuBody" 0 0 4 \
          "1" "$_SecJournTitle" \
          "2" "$_SecCoreTitle" \
          "3" "$_SecKernTitle " \
          "4" "$_Back" 2>${ANSWER}

        HIGHLIGHT_SUB=$(cat ${ANSWER})
        case $(cat ${ANSWER}) in
            # systemd-journald
            "1") DIALOG " $_SecJournTitle " --menu "$_SecJournBody" 0 0 7 \
                   "$_Edit" "/etc/systemd/journald.conf" \
                   "10M" "SystemMaxUse=10M" \
                   "20M" "SystemMaxUse=20M" \
                   "50M" "SystemMaxUse=50M" \
                   "100M" "SystemMaxUse=100M" \
                   "200M" "SystemMaxUse=200M" \
                   "$_Disable" "Storage=none" 2>${ANSWER}

                 if [[ $(cat ${ANSWER}) != "" ]]; then
                     if [[ $(cat ${ANSWER}) == "$_Disable" ]]; then
                         sed -i "s/#Storage.*\|Storage.*/Storage=none/g" ${MOUNTPOINT}/etc/systemd/journald.conf
                         sed -i "s/SystemMaxUse.*/#&/g" ${MOUNTPOINT}/etc/systemd/journald.conf
                         DIALOG " $_SecJournTitle " --infobox "\n$_Done!\n\n" 0 0
                         sleep 2
                     elif [[ $(cat ${ANSWER}) == "$_Edit" ]]; then
                         nano ${MOUNTPOINT}/etc/systemd/journald.conf
                     else
                         sed -i "s/#SystemMaxUse.*\|SystemMaxUse.*/SystemMaxUse=$(cat ${ANSWER})/g" ${MOUNTPOINT}/etc/systemd/journald.conf
                         sed -i "s/Storage.*/#&/g" ${MOUNTPOINT}/etc/systemd/journald.conf
                         DIALOG " $_SecJournTitle " --infobox "\n$_Done!\n\n" 0 0
                         sleep 2
                     fi
                 fi
                 ;;
            # core dump
            "2") DIALOG " $_SecCoreTitle " --menu "$_SecCoreBody" 0 0 2 \
                 "$_Disable" "Storage=none" \
                 "$_Edit" "/etc/systemd/coredump.conf" 2>${ANSWER}

                 if [[ $(cat ${ANSWER}) == "$_Disable" ]]; then
                     sed -i "s/#Storage.*\|Storage.*/Storage=none/g" ${MOUNTPOINT}/etc/systemd/coredump.conf
                     DIALOG " $_SecCoreTitle " --infobox "\n$_Done!\n\n" 0 0
                     sleep 2
                 elif [[ $(cat ${ANSWER}) == "$_Edit" ]]; then
                     nano ${MOUNTPOINT}/etc/systemd/coredump.conf
                 fi
                 ;;
            # Kernel log access
            "3") DIALOG " $_SecKernTitle " --menu "$_SecKernBody" 0 0 2 \
                 "$_Disable" "kernel.dmesg_restrict = 1" \
                 "$_Edit" "/etc/systemd/coredump.conf.d/custom.conf" 2>${ANSWER}

                  case $(cat ${ANSWER}) in
                      "$_Disable") echo "kernel.dmesg_restrict = 1" > ${MOUNTPOINT}/etc/sysctl.d/50-dmesg-restrict.conf
                                   DIALOG " $_SecKernTitle " --infobox "\n$_Done!\n\n" 0 0
                                   sleep 2 ;;
                      "$_Edit") [[ -e ${MOUNTPOINT}/etc/sysctl.d/50-dmesg-restrict.conf ]] && nano ${MOUNTPOINT}/etc/sysctl.d/50-dmesg-restrict.conf || \
                                  DIALOG " $_SeeConfErrTitle " --msgbox "$_SeeConfErrBody1" 0 0 ;;
                  esac
                 ;;
            *) loopmenu=0
                return 0
                 ;;
        esac
    done
}
