main_menu_online() {
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

    # Depending on the answer, first check whether partition(s) are mounted and whether base has been installed
    if [[ $(cat ${ANSWER}) -eq 2 ]]; then
       check_mount
    fi

    if [[ $(cat ${ANSWER}) -ge 3 ]] && [[ $(cat ${ANSWER}) -le 8 ]]; then
       check_mount
       check_base
    fi

    case $(cat ${ANSWER}) in
        "1") prep_menu
            ;;
        "2") install_base_menu
            ;;
        "3") install_graphics_menu
            ;;
        "4") config_base_menu
            ;;
        "5") install_network_menu
            ;;
        "6") install_multimedia_menu
            ;;
        "7") security_menu
            ;;
        "8") edit_configs
            ;;
        *) final_check
           dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --yesno "$_CloseInstBody $(cat ${CHECKLIST})" 0 0
            if [[ $? -eq 0 ]]; then
                check_for_error "exit installer." $? "SKIP"
                if [[ -e /mnt/usr ]]; then
                  dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --yesno "\n$_LogInfo\n" 0 0
                  if [[ $? -eq 0 ]]; then
                    [[ -e /mnt/.m-a.log ]] && cat ${LOGFILE} >> /mnt/.m-a.log
                    install -m700 ${LOGFILE} /mnt/.m-a.log
                  fi
                fi
                umount_partitions
                clear
                exit 0
            fi
            ;;
    esac

    main_menu_online
}

# Preparation
prep_menu() {
    local PARENT="$FUNCNAME"

    submenu 7
    DIALOG "$_PrepMenuTitle " --default-item ${HIGHLIGHT_SUB} \
      --menu "$_PrepMenuBody" 0 0 7 \
      "1" "$_VCKeymapTitle" \
      "2" "$_DevShowOpt" \
      "3" "$_PrepPartDisk" \
      "4" "$_PrepLUKS" \
      "5" "$_PrepLVM $_PrepLVM2" \
      "6" "$_PrepMntPart" \
      "7" "$_Back" 2>${ANSWER}

    HIGHLIGHT_SUB=$(cat ${ANSWER})
    case $(cat ${ANSWER}) in
        "1") set_keymap
             ;;
        "2") show_devices
             ;;
        "3") umount_partitions
             select_device
             create_partitions
             ;;
        "4") luks_menu
             ;;
        "5") lvm_menu
             ;;
        "6") mount_partitions
             ;;
        *) main_menu_online
             ;;
    esac

    prep_menu
}

# Base Installation
install_base_menu() {
    local PARENT="$FUNCNAME"

    submenu 5
    DIALOG " $_InstBsMenuTitle " --default-item ${HIGHLIGHT_SUB} --menu "$_InstBseMenuBody" 0 0 5 \
      "1" "$_PrepMirror" \
      "2" "$_PrepPacKey" \
      "3" "$_InstBse" \
      "4" "$_InstBootldr" \
      "5" "$_Back" 2>${ANSWER}

    HIGHLIGHT_SUB=$(cat ${ANSWER})
    case $(cat ${ANSWER}) in
        "1") configure_mirrorlist
             ;;
        "2") clear
             pacman-key --init
             pacman-key --populate archlinux manjaro
             pacman-key --refresh-keys
             check_for_error "refresh pacman-keys"
             ;;
        "3") install_base
             ;;
        "4") install_bootloader
             ;;
        *) main_menu_online
             ;;
    esac

    install_base_menu
}

install_graphics_menu() {
    local PARENT="$FUNCNAME"

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
        *) main_menu_online
            ;;
    esac

    install_graphics_menu
}

# Base Configuration
config_base_menu() {
    local PARENT="$FUNCNAME"

    submenu 8
    DIALOG "$_ConfBseBody" --default-item ${HIGHLIGHT_SUB} --menu " $_ConfBseMenuTitle " \
     0 0 8 \
      "1" "$_ConfBseFstab" \
      "2" "$_ConfBseHost" \
      "3" "$_ConfBseSysLoc" \
      "4" "$_ConfBseTimeHC" \
      "5" "$_ConfUsrRoot" \
      "6" "$_ConfUsrNew" \
      "7" "$_MMRunMkinit" \
      "8" "$_Back" 2>${ANSWER}

    HIGHLIGHT_SUB=$(cat ${ANSWER})
    case $(cat ${ANSWER}) in
        "1") generate_fstab
            ;;
        "2") set_hostname
            ;;
        "3") set_locale
            ;;
        "4") set_timezone
            set_hw_clock
            ;;
        "5") set_root_password
            ;;
        "6") create_new_user
            ;;
        "7") run_mkinitcpio
            ;;
        *) main_menu_online
            ;;
    esac

    config_base_menu
}

install_vanilla_de_wm() {
    local PARENT="$FUNCNAME"

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
        *) SUB_MENU="install_graphics_menu"
           HIGHLIGHT_SUB=2 
           install_graphics_menu
             ;;
    esac

    install_vanilla_de_wm
    
}

install_desktop_menu() {
    local PARENT="$FUNCNAME"

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
        *) SUB_MENU="install_graphics_menu"
            HIGHLIGHT_SUB=2
            install_graphics_menu
            ;;
    esac

    install_desktop_menu
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
        check_for_error "$FUNCNAME" $? install_multimedia_menu
    fi

    install_multimedia_menu
}

edit_configs() {
    local PARENT="$FUNCNAME"

    # Clear the file variables
    FILE=""
    user_list=""

    submenu 13
    DIALOG " $_SeeConfOptTitle " --default-item ${HIGHLIGHT_SUB} --menu "$_SeeConfOptBody" 0 0 13 \
      "1" "/etc/vconsole.conf" \
      "2" "/etc/locale.conf" \
      "3" "/etc/hostname" \
      "4" "/etc/hosts" \
      "5" "/etc/sudoers" \
      "6" "/etc/mkinitcpio.conf" \
      "7" "/etc/fstab" \
      "8" "/etc/crypttab" \
      "9" "grub/syslinux/systemd-boot" \
      "10" "lxdm/lightdm/sddm" \
      "11" "/etc/pacman.conf" \
      "12" "~/.xinitrc" \
      "13" "$_Back" 2>${ANSWER}

    HIGHLIGHT_SUB=$(cat ${ANSWER})
    case $(cat ${ANSWER}) in
        "1") [[ -e ${MOUNTPOINT}/etc/vconsole.conf ]] && FILE="${MOUNTPOINT}/etc/vconsole.conf"
            ;;
        "2") [[ -e ${MOUNTPOINT}/etc/locale.conf ]] && FILE="${MOUNTPOINT}/etc/locale.conf"
            ;;
        "3") [[ -e ${MOUNTPOINT}/etc/hostname ]] && FILE="${MOUNTPOINT}/etc/hostname"
            ;;
        "4") [[ -e ${MOUNTPOINT}/etc/hosts ]] && FILE="${MOUNTPOINT}/etc/hosts"
            ;;
        "5") [[ -e ${MOUNTPOINT}/etc/sudoers ]] && FILE="${MOUNTPOINT}/etc/sudoers"
            ;;
        "6") [[ -e ${MOUNTPOINT}/etc/mkinitcpio.conf ]] && FILE="${MOUNTPOINT}/etc/mkinitcpio.conf"
            ;;
        "7") [[ -e ${MOUNTPOINT}/etc/fstab ]] && FILE="${MOUNTPOINT}/etc/fstab"
            ;;
        "8") [[ -e ${MOUNTPOINT}/etc/crypttab ]] && FILE="${MOUNTPOINT}/etc/crypttab"
            ;;
        "9") [[ -e ${MOUNTPOINT}/etc/default/grub ]] && FILE="${MOUNTPOINT}/etc/default/grub"
            [[ -e ${MOUNTPOINT}/boot/syslinux/syslinux.cfg ]] && FILE="$FILE ${MOUNTPOINT}/boot/syslinux/syslinux.cfg"
            if [[ -e ${MOUNTPOINT}${UEFI_MOUNT}/loader/loader.conf ]]; then
                files=$(ls ${MOUNTPOINT}${UEFI_MOUNT}/loader/entries/*.conf)
                for i in ${files}; do
                    FILE="$FILE ${i}"
                done
            fi
            ;;
        "10") [[ -e ${MOUNTPOINT}/etc/lxdm/lxdm.conf ]] && FILE="${MOUNTPOINT}/etc/lxdm/lxdm.conf"
            [[ -e ${MOUNTPOINT}/etc/lightdm/lightdm.conf ]] && FILE="${MOUNTPOINT}/etc/lightdm/lightdm.conf"
            [[ -e ${MOUNTPOINT}/etc/sddm.conf ]] && FILE="${MOUNTPOINT}/etc/sddm.conf"
            ;;
        "11") [[ -e ${MOUNTPOINT}/etc/pacman.conf ]] && FILE="${MOUNTPOINT}/etc/pacman.conf"
            ;;
        "12") user_list=$(ls ${MOUNTPOINT}/home/ | sed "s/lost+found//")
            for i in ${user_list}; do
                [[ -e ${MOUNTPOINT}/home/$i/.xinitrc ]] && FILE="$FILE ${MOUNTPOINT}/home/$i/.xinitrc"
            done
            ;;
        *) main_menu_online
            ;;
    esac

    if [[ $FILE != "" ]]; then
        nano $FILE
    else
        DIALOG " $_ErrTitle " --msgbox "$_SeeConfErrBody" 0 0
    fi

    edit_configs
}
