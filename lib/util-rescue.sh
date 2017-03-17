#!/usr/bin/bash
#
# mode rescue functions 

# check if efi
mount_test_efi() {
    if [[ "$(ini system.bios)" == "UEFI" ]]; then
        menu_item_insert "home" "efi/esp" "mount_partition efi"
    fi
}

mount_partition() {
    local p='' s='' i=0
    menu_item_change "back" # delete 

    find_partitions
    for p in $PARTITIONS; do
        if ((i % 2==0)); then
            s="$p"
        else
            menu_item_insert "" "$p $s" "mount_part $p $s"
        fi
        ((i++))
    done
    menu_item_insert "" "back" "mnu_return 97"
}

mount_part(){
    mount_current_partition "$1"
    return 0
}

mnu_return(){ return "${1:-98}"; } 

#change item and function from param
check_menu_edit_config_begin(){
    if [[ "${ARGS[init]}" == "systemd" ]]; then
        menu_item_change "init config" "systemd configuration" "nano /etc/${ARGS[init]}/system.conf"
    else
        menu_item_change "init config"  "openrc configuration" "nano /etc/rc.conf"
    fi

    if ((ARGS[remove])); then
        menu_item_change "pacman.conf"  # no args = remove
    fi

    # tests
    menu_item_insert "pacman.conf" "test insert" "nano test_insert"
    menu_item_insert "" "last item" "nano test_add"

    return 0
}

check_menu_is_mounted(){
    if [[ "${INSTALL[mounted]}" != 1 ]]; then
        DIALOG " error " --msgbox "\n make mount in pre-install before\n" 0 0
        return "${1:-98}"
    fi
}
