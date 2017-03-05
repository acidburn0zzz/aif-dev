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

# Header
VERSION="Manjaro Architect Installer v$version"

# Host system information
ARCHI=$(uname -m) # Display whether 32 or 64 bit system
SYSTEM="Unknown"   # Display whether system is BIOS or UEFI. Default is "unknown"
H_INIT=""          # Host init-sys
NW_CMD=""          # command to launch the available network client

# Locale and Language
CURR_LOCALE="en_US.UTF-8"   # Default Locale
FONT=""                     # Set new font if necessary
KEYMAP="us"                 # Virtual console keymap. Default is "us"
XKBMAP="us"                 # X11 keyboard layout. Default is "us"
ZONE=""                     # For time
SUBZONE=""                  # For time
LOCALE="en_US.UTF-8"        # System locale. Default is "en_US.UTF-8"
PROFILES=""                 # iso-profiles path

# Menu highlighting (automated step progression)
HIGHLIGHT=0                 # Highlight items for Main Menu
HIGHLIGHT_SUB=0             # Highlight items for submenus
SUB_MENU=""                 # Submenu to be highlighted
PARENT=""                   # the parent menu

# Temporary files to store menu selections and errors
ANSWER="/tmp/.answer"          # Basic menu selections
PACKAGES="/tmp/.pkgs"       # Packages to install
MOUNT_OPTS="/tmp/.mnt_opts" # Filesystem Mount options
INIT="/tmp/.init"           # init systemd|openrc
ERR="/tmp/.errlog"

# Installer-Log
LOGFILE="/var/log/m-a.log"  # path for the installer log in the live environment
[[ ! -e $LOGFILE ]] && touch $LOGFILE
TARGLOG="/mnt/.m-a.log"     # path to copy the installer log to target install

# file systems
BTRFS=0
LUKS=0
LUKS_DEV=""
LUKS_NAME=""
LUKS_OPT=""         # Default or user-defined?
LUKS_UUID=""
LVM=0
LVM_LV_NAME=""      # Name of LV to create or use
LVM_VG=""
LVM_VG_MB=0
VG_PARTS=""
LVM_SEP_BOOT=0      # 1 = Seperate /boot, 2 = seperate /boot & LVM
LV_SIZE_INVALID=0   # Is LVM LV size entered valid?
VG_SIZE_TYPE=""     # Is VG in Gigabytes or Megabytes?

# Mounting
MOUNT=""                # Installation: All other mounts branching
MOUNTPOINT="/mnt"               # Installation: Root mount from Root
FS_OPTS=""                      # File system special mount options available
CHK_NUM=16                      # Used for FS mount options checklist length
INCLUDE_PART='part\|lvm\|crypt' # Partition types to include for display and selection.
ROOT_PART=""                    # ROOT partition
UEFI_PART=""                    # UEFI partition
UEFI_MOUNT=""                   # UEFI mountpoint (/boot or /boot/efi)

# Edit Files
FILE=""          # File(s) to be reviewed

# Installation
DM_INST=""       # Which DMs have been installed?
DM_ENABLED=0     # Has a display manager been enabled?
NM_INST=""       # Which NMs have been installed?
NM_ENABLED=0     # Has a network connection manager been enabled?
KERNEL="n"       # Kernel(s) installed (base install); kernels for mkinitcpio
GRAPHIC_CARD=""  # graphics card
INTEGRATED_GC="" # Integrated graphics card for NVIDIA
NVIDIA_INST=0    # Indicates if NVIDIA proprietary driver has been installed
NVIDIA=""        # NVIDIA driver(s) to install depending on kernel(s)
VB_MOD=""        # headers packages to install depending on kernel(s)
SHOW_ONCE=0      # Show de_wm information only once
COPY_PACCONF=0   # Copy over installer /etc/pacman.conf to installed system?

import(){
    if [[ -r $1 ]];then
        source $1
    else
        echo "Could not import $1"
    fi
}

DIALOG() {
    dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --column-separator "|" --title "$@"
}

# progress through menu entries until number $1 is reached
submenu() {
    if [[ $SUB_MENU != "$PARENT" ]]; then
        SUB_MENU="$PARENT"
        HIGHLIGHT_SUB=1
    elif [[ $HIGHLIGHT_SUB != "$1" ]]; then
        HIGHLIGHT_SUB=$(( HIGHLIGHT_SUB + 1 ))
    fi
}

# Adapted from AIS. Checks if system is made by Apple, whether the system is BIOS or UEFI,
# and for LVM and/or LUKS.
id_system() {
    printf "\n    :: $(pacman -Q manjaro-architect) ::\n\n" >> ${LOGFILE}

    # Apple System Detection
    if [[ "$(cat /sys/class/dmi/id/sys_vendor)" == 'Apple Inc.' ]] || [[ "$(cat /sys/class/dmi/id/sys_vendor)" == 'Apple Computer, Inc.' ]]; then
        modprobe -r -q efivars || true  # if MAC
    else
        modprobe -q efivarfs             # all others
    fi

    # BIOS or UEFI Detection
    if [[ -d "/sys/firmware/efi/" ]]; then
        # Mount efivarfs if it is not already mounted
        if [[ -z $(mount | grep /sys/firmware/efi/efivars) ]]; then
            mount -t efivarfs efivarfs /sys/firmware/efi/efivars
        fi
        SYSTEM="UEFI"
    else
        SYSTEM="BIOS"
    fi

    # init system
    if [ $(cat /proc/1/comm) == "systemd" ]; then
        H_INIT="systemd"
    else
        H_INIT="openrc"
    fi

    ## TODO: Test which nw-client is available, including if the service according to $H_INIT is running
    [[ $H_INIT == "systemd" ]] && [[ $(systemctl is-active NetworkManager) == "active" ]] && NW_CMD=nmtui 2>$ERR

    check_for_error "system: $SYSTEM, init: $H_INIT nw-client: $NW_CMD"
}

# If there is an error, display it and go back to main menu. In any case, write to logfile.
# param 2 : error code is optional
# param 3 : return menu function , optional, default: main_menu_online
check_for_error() {
    local _msg="$1"
    local _err="${2:-0}"
    local _function_menu="${3:-main_menu}"
    ((${_err}!=0)) && _msg="[${_msg}][${_err}]"
    [[ -f "${ERR}" ]] && {
        _msg="${_msg} $(head -n1 ${ERR})"
        rm "${ERR}"
    }
    if ((${_err}!=0)) ; then
        # and function varsdump ? _msg="$_msg \n $(declare -p | grep -v " _")"
        local _fpath="${FUNCNAME[*]:1:2}()"
        _fpath=" --${_fpath// /()<-}"
        ! ((debug)) && _fpath=""
        echo -e "$(date +%D\ %T) ERROR ${_msg}${_fpath}" >> "${LOGFILE}"
        if [[  "${_function_menu}" != "SKIP" ]]; then
            DIALOG " $_ErrTitle " --msgbox "\n${_msg}\n" 0 0
            # return error for return to parent menu
            return $_err
        fi
    else
        # add $FUNCNAME limit to 20 max for control if recursive
        ((debug)) && _msg="${_msg} --${FUNCNAME[*]:1:20}"
        echo -e "$(date +%D\ %T) ${_msg}" >> "${LOGFILE}"
    fi
}

# Add locale on-the-fly and sets source translation file for installer
select_language() {
    DIALOG " Select Language" --default-item '3' --menu "\n$_Lang" 0 0 11 \
      "1" $"Danish|(da_DK)" \
      "2" $"Dutch|(nl_NL)" \
      "3" $"English|(en_**)" \
      "4" $"French|(fr_FR)" \
      "5" $"Hungarian|(hu_HU)" \
      "6" $"Italian|(it_IT)" \
      "7" $"Portuguese|(pt_PT)" \
      "8" $"Portuguese [Brasil]|(pt_BR)" \
      "9" $"Russian|(ru_RU)" \
      "10" $"Spanish|(es_ES)" 2>${ANSWER}

#      "5" $"German|(de_DE)" \

    case $(cat ${ANSWER}) in
        "1") source $DATADIR/translations/danish.trans
             CURR_LOCALE="da_DK.UTF-8"
             FONT="cp865-8x16.psfu"
             ;;
        "2") source $DATADIR/translations/dutch.trans
             CURR_LOCALE="nl_NL.UTF-8"
             ;;
        "3") source $DATADIR/translations/english.trans
             CURR_LOCALE="en_US.UTF-8"
             ;;
        "4") source $DATADIR/translations/french.trans
             CURR_LOCALE="fr_FR.UTF-8"
             ;;
#        "5") source $DATADIR/translations/german.trans
#             CURR_LOCALE="de_DE.UTF-8"
#             ;;
        "5") source $DATADIR/translations/hungarian.trans
             CURR_LOCALE="hu_HU.UTF-8"
             FONT="lat2-16.psfu"
             ;;
        "6") source $DATADIR/translations/italian.trans
             CURR_LOCALE="it_IT.UTF-8"
             ;;
        "7") source $DATADIR/translations/portuguese.trans
             CURR_LOCALE="pt_PT.UTF-8"
             ;;
        "8") source $DATADIR/translations/portuguese_brasil.trans
             CURR_LOCALE="pt_BR.UTF-8"
             ;;
        "9") source $DATADIR/translations/russian.trans
             CURR_LOCALE="ru_RU.UTF-8"
             FONT="LatKaCyrHeb-14.psfu"
             ;;
        "10") source $DATADIR/translations/spanish.trans
             CURR_LOCALE="es_ES.UTF-8"
             ;;
#        "") source $DATADIR/translations/turkish.trans
#             CURR_LOCALE="tr_TR.UTF-8"
#             FONT="LatKaCyrHeb-14.psfu"
#             ;;
#        "") source $DATADIR/translations/greek.trans
#             CURR_LOCALE="el_GR.UTF-8"
#             FONT="iso07u-16.psfu"
#             ;;
#       "") source $DATADIR/translations/polish.trans
#             CURR_LOCALE="pl_PL.UTF-8"
#             FONT="latarcyrheb-sun16"
#             ;;
        *)  clear && exit 0
              ;;
    esac

    # Generate the chosen locale and set the language
    DIALOG " $_Config " --infobox "$_ApplySet" 0 0
    sleep 2
    sed -i "s/#${CURR_LOCALE}/${CURR_LOCALE}/" /etc/locale.gen
    locale-gen >/dev/null 2>$ERR
    export LANG=${CURR_LOCALE}

    check_for_error "set LANG=${CURR_LOCALE}" $?

    [[ $FONT != "" ]] && {
        setfont $FONT 2>$ERR
        check_for_error "set font $FONT" $?
    }
}

mk_connection() {
    if [[ ! $(ping -c 2 google.com) ]]; then
        DIALOG " $_NoCon " --yesno "\n$_EstCon" 0 0 && $NW_CMD && return 0 || clear && exit 0
    fi
}

# Check user is root, and that there is an active internet connection
# Seperated the checks into seperate "if" statements for readability.
check_requirements() {
    DIALOG " $_ChkTitle " --infobox "$_ChkBody" 0 0
    sleep 2

    if [[ `whoami` != "root" ]]; then
        DIALOG " $_Erritle " --infobox "$_RtFailBody" 0 0
        sleep 2
        exit 1
    fi

    if [[ ! $(ping -c 1 google.com) ]]; then
        DIALOG " $_ErrTitle " --infobox "$_ConFailBody" 0 0
        sleep 2
        exit 1
    fi

    # This will only be executed where neither of the above checks are true.
    # The error log is also cleared, just in case something is there from a previous use of the installer.
    DIALOG " $_ReqMetTitle " --infobox "\n$_ReqMetBody\n\n$_UpdDb\n\n" 0 0
    sleep 2
    clear
    echo "" > $ERR
    pacman -Syy 2>$ERR
    check_for_error "refresh database" $? SKIP
}

# Greet the user when first starting the installer
greeting() {
    DIALOG " $_WelTitle $VERSION " --msgbox "$_WelBody" 0 0
}

# Choose between the compact and extended installer menu
menu_choice() {
    DIALOG " $_ChMenu " --no-cancel --radiolist "\n$_ChMenuBody\n\n$_UseSpaceBar" 0 0 2 \
      "$_InstStandBase" "" on \
      "$_InstAdvBase" "" off 2>${ANSWER}
    menu_opt=$(cat ${ANSWER})
}

# Originally adapted from AIS. Added option to allow users to edit the mirrorlist.
configure_mirrorlist() {
        DIALOG " $_MirrorlistTitle " \
          --menu "$_MirrorlistBody" 0 0 4 \
          "1" "$_MirrorRankTitle" \
          "2" "$_MirrorConfig" \
          "3" "$_MirrorPacman" \
          "4" "$_Back" 2>${ANSWER}

        case $(cat ${ANSWER}) in
            "1") rank_mirrors
                ;;
            "2") nano /etc/pacman-mirrors.conf
                check_for_error "edit pacman-mirrors.conf"
                ;;
            "3") nano /etc/pacman.conf
                DIALOG " $_MirrorPacman " --yesno "$_MIrrorPacQ" 0 0 && COPY_PACCONF=1 || COPY_PACCONF=0
                check_for_error "edit pacman.conf $COPY_PACCONF"
                pacman -Syy
                 ;;
            *) return 0
                 ;;
        esac
}

rank_mirrors() {
    #Choose the branch for mirrorlist
    BRANCH="/tmp/.branch"
    DIALOG " $_MirrorBranch " --radiolist "\n\n$_UseSpaceBar" 0 0 3 \
      "stable" "-" on \
      "testing" "-" off \
      "unstable" "-" off 2>${BRANCH}
    clear
    if [[ ! -z "$(cat ${BRANCH})" ]]; then
        pacman-mirrors -gib "$(cat ${BRANCH})"
        check_for_error "$FUNCNAME branch $(cat ${BRANCH})"
    fi
}

# Simple code to show devices / partitions.
show_devices() {
    lsblk -o NAME,MODEL,TYPE,FSTYPE,SIZE,MOUNTPOINT | grep "disk\|part\|lvm\|crypt\|NAME\|MODEL\|TYPE\|FSTYPE\|SIZE\|MOUNTPOINT" > /tmp/.devlist
    DIALOG " $_DevShowOpt " --textbox /tmp/.devlist 0 0
}

# Adapted from AIS. An excellent bit of code!
arch_chroot() {
    manjaro-chroot $MOUNTPOINT "${1}"
}

# Ensure that a partition is mounted
check_mount() {
    if [[ $(lsblk -o MOUNTPOINT | grep ${MOUNTPOINT}) == "" ]]; then
        DIALOG " $_ErrTitle " --msgbox "$_ErrNoMount" 0 0
        ANSWER=0
        HIGHLIGHT=0
        return 1
    fi
}

# Ensure that Manjaro has been installed
check_base() {
    check_mount
    if [[ $? -eq 0 ]]; then
        if [[ ! -e /mnt/.base_installed ]]; then
            DIALOG " $_ErrTitle " --msgbox "$_ErrNoBase" 0 0
            ANSWER=1
            HIGHLIGHT=1
            return 1
        fi
    else
        return 1
    fi
}

# install a pkg in the live session if not installed
inst_needed() {
    if [[ ! $(pacman -Q $1) ]]; then
        DIALOG " $_InstPkg " --infobox "$_InstPkg '${1}'" 0 0
        sleep 2
        clear
        pacman -Sy --noconfirm $1 2>$ERR
        check_for_error "Install needed pkg $1." $?
    fi
}

# install a pkg in the chroot if not installed
check_pkg() {
    if ! arch_chroot "pacman -Q $1" ; then
        basestrap "$1" 2>$ERR 
        check_for_error "install missing pkg $1 to target." $?
    fi
}

# return list of profiles not containing >openrc flag in Packages-Desktop
evaluate_profiles() {
    echo "" > /tmp/.systemd_only
    for p in $(find $PROFILES/{manjaro,community} -mindepth 1 -maxdepth 1 -type d ! -name 'netinstall' ! -name 'architect'); do
        [[ ! $(grep ">openrc" $p/Packages-Desktop) ]] && echo $p | cut -f7 -d'/' >> /tmp/.systemd_only
    done
    echo $(cat /tmp/.systemd_only)
}

# verify if profile is available for openrc
evaluate_openrc() {
    if [[ ! $(grep ">openrc" $PROFILES/*/$(cat /tmp/.desktop)/Packages-Desktop) ]]; then
        DIALOG " $_ErrInit " --menu "\n[Manjaro-$(cat /tmp/.desktop)] $_WarnInit\n" 0 0 2 \
          "1" "$_DiffPro" \
          "2" "$_InstSystd" 2>${ANSWER}
        check_for_error "selected systemd-only profile [$(cat /tmp/.desktop)] with openrc base. -> $(cat ${ANSWER})"
        case $(cat ${ANSWER}) in
            "1") install_desktop_menu
            ;;
            "2") install_base
            ;;
        esac
    fi
}  

final_check() {
    CHECKLIST=/tmp/.final_check
    # Empty the list
    echo "" > ${CHECKLIST}

    # Check if base is installed
    if [[ ! -e /mnt/.base_installed ]]; then
        echo "- Base is not installed" >> ${CHECKLIST}
    else
        # Check if bootloader is installed
        if [[ $SYSTEM == "BIOS" ]]; then
            arch_chroot "pacman -Qq grub" &> /dev/null || echo "- Bootloader is not installed" >> ${CHECKLIST}
        else
            [[ -e /mnt/boot/efi/EFI/manjaro_grub/grubx64.efi ]] || [[ -e /mnt/boot/EFI/manjaro_grub/grubx64.efi ]] || echo "- Bootloader is not installed" >> ${CHECKLIST}
        fi

        # Check if fstab is generated
        $(grep -qv '^#' /mnt/etc/fstab 2>/dev/null) || echo "- Fstab has not been generated" >> ${CHECKLIST}

        # Check if locales have been generated
        [[ $(manjaro-chroot /mnt 'locale -a' | wc -l) -ge '3' ]] || echo "- Locales have not been generated" >> ${CHECKLIST}

        # Check if root password has been set
        manjaro-chroot /mnt 'passwd --status root' | cut -d' ' -f2 | grep -q 'NP' && echo "- Root password is not set" >> ${CHECKLIST}

        # check if user account has been generated
        [[ $(ls /mnt/home 2>/dev/null) == "" ]] && echo "- No user accounts have been generated" >> ${CHECKLIST}
    fi
}

exit_done() {
    if [[ $(lsblk -o MOUNTPOINT | grep ${MOUNTPOINT} 2>/dev/null) != "" ]]; then
        final_check
        dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --yesno "$_CloseInstBody $(cat ${CHECKLIST})" 0 0
        if [[ $? -eq 0 ]]; then
            check_for_error "exit installer."
            dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --yesno "\n$_LogInfo ${TARGLOG}.\n" 0 0
            if [[ $? -eq 0 ]]; then
                [[ -e ${TARGLOG} ]] && cat ${LOGFILE} >> ${TARGLOG} || cp ${LOGFILE} ${TARGLOG}
            fi
            umount_partitions
            clear
            exit 0
        else
            [[ menu_opt == "advanced" ]] && main_menu_full || main_menu
        fi
    else
        dialog --backtitle "$VERSION - $SYSTEM ($ARCHI)" --yesno "$_CloseInstBody" 0 0
        if [[ $? -eq 0 ]]; then
            umount_partitions
            clear
            exit 0
        else
            [[ menu_opt == "advanced" ]] && main_menu_full || main_menu
        fi
    fi
}
