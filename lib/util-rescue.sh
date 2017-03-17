#!/usr/bin/bash
#
# mode rescue functions 

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
