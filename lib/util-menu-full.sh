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
