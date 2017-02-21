# !/bin/bash
#
# Architect Installation Framework (version 2.3.1 - 26-Mar-2016)
#
# Written by Carl Duff for Architect Linux
#
# Modified by Chrysostomus to install manjaro instead
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
LOGFILE="/var/log/m-a.log"
[[ ! -e $LOGFILE ]] && touch $LOGFILE

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

LOG(){
    echo "$(date +%D\ %T\ %Z) $1" >> $LOGFILE
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
    [[ $H_INIT == "systemd" ]] && [[ $(systemctl is-active NetworkManager) == "active" ]] && NW_CMD=nmtui
}

# If there is an error, display it, move the log and then go back to the main menu (no point in continuing).
check_for_error() {
    if [[ $? -eq 1 ]] && [[ $(cat ${ERR} | grep -i "error") != "" ]]; then
        DIALOG " $_ErrTitle " --msgbox "\n$(cat ${ERR})\n" 0 0
        LOG "ERROR : $(cat ${ERR})"
        echo "" > $ERR
        
        main_menu_online
    fi
}

# Add locale on-the-fly and sets source translation file for installer
select_language() {
    LOG "select language"
    DIALOG "Select Language" --default-item '3' --menu "\n$_Lang" 0 0 11 \
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
    DIALOG "$_Config" --infobox "$_ApplySet" 0 0
    sleep 2
    sed -i "s/#${CURR_LOCALE}/${CURR_LOCALE}/" /etc/locale.gen
    locale-gen >/dev/null 2>&1
    export LANG=${CURR_LOCALE}
    [[ $FONT != "" ]] && setfont $FONT
}

mk_connection() {
    if [[ ! $(ping -c 2 google.com) ]]; then
        DIALOG "$_NoCon" --yesno "\n$_EstCon" 0 0 && $NW_CMD || clear && exit 0
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
    DIALOG " $_ReqMetTitle " --infobox "$_ReqMetBody" 0 0
    sleep 2
    clear
    echo "" > $ERR
    pacman -Syy
}

# Greet the user when first starting the installer
greeting() {
    DIALOG " $_WelTitle $VERSION " --msgbox "$_WelBody" 0 0
}

rank_mirrors() {
    #Choose the branch for mirrorlist        
    BRANCH="/tmp/.branch"
    DIALOG "$_MirrorBranch" --radiolist "\n\n$_UseSpaceBar" 0 0 3 \
      "stable" "-" off \
      "testing" "-" off \
      "unstable" "-" off 2>${BRANCH}
    clear
    [[ ! -z "$(cat ${BRANCH})" ]] && pacman-mirrors -gib "$(cat ${BRANCH})" && \
    LOG "branch selected: $(cat ${BRANCH})"
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
            LOG "rank mirrors"
            ;;
        "2") nano /etc/pacman-mirrors.conf
            LOG "edit pacman-mirrors.conf"
            ;;
        "3") nano /etc/pacman.conf
            DIALOG " $_MirrorPacman " --yesno "$_MIrrorPacQ" 0 0 \
            && LOG "edit pacman.conf" && COPY_PACCONF=1 || COPY_PACCONF=0
            pacman -Syy
             ;;
        *) install_base_menu
             ;;
    esac

    configure_mirrorlist
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
       main_menu_online
    fi
}

# Ensure that Manjaro has been installed
check_base() {
    if [[ ! -e ${MOUNTPOINT}/etc ]]; then
        DIALOG " $_ErrTitle " --msgbox "$_ErrNoBase" 0 0
        main_menu_online
    fi
}

# install a pkg in the live session if not installed
inst_needed() {
    [[ ! $(pacman -Q $1 2>/dev/null) ]] && pacman -Sy --noconfirm $1
    LOG "Install needed pkg $1."
}

# install a pkg in the chroot if not installed
check_pkg() {
    arch_chroot "[[ ! $(pacman -Q $1 2>/dev/null) ]] && pacman -Sy --noconfirm $1" 2>$ERR
    LOG "Install missing pkg $1 to target."
}
