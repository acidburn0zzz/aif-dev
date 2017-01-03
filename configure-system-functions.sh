DIALOG(){
	# parameters: see dialog(1)
	# returns: whatever dialog did
	dialog --backtitle "$TITLE" --aspect 15 --yes-label "$_yes" --no-label "$_no" --cancel-label "$_cancel" "$@"
	return $?
}

configure_system(){
	## PREPROCESSING ##
	# only done on first invocation of configure_system
	if [ $S_PRECONFIG -eq 0 ]; then
		#edit /etc/locale.conf & /etc/environment
		echo "LANG=${LOCALE}.UTF-8" > ${DESTDIR}/etc/locale.conf
		echo "LC_COLLATE=C" >> ${DESTDIR}/etc/locale.conf
		echo "LANG=${LOCALE}.UTF-8" >> ${DESTDIR}/etc/environment

		# add BROWSER var
		if [ -e "${DESTDIR}/usr/bin/firefox" ] ; then
			echo "BROWSER=/usr/bin/firefox" >> ${DESTDIR}/etc/environment
		fi

		#edit /etc/mkinitcpio.conf to have external bootup from pcmcia and resume support
		HOOKS=`cat /etc/mkinitcpio.conf | grep HOOKS= | grep -v '#' | cut -d'"' -f2 | sed 's/filesystems/pcmcia resume filesystems/g'`
		if [ -e ${DESTDIR}/etc/plymouth/plymouthd.conf ] ; then
			sed -i -e "s/^HOOKS=.*/HOOKS=\"${HOOKS} plymouth\"/g" ${DESTDIR}/etc/mkinitcpio.conf
		fi

		# Determind which language we are using
		configure_language ${DESTDIR}
	fi

	S_PRECONFIG=1
	## END PREPROCESS ##

	DONE=0
	DONE_CONFIG=""
	NEXTITEM=""
	while [[ "${DONE}" = "0" ]]; do
		if [[ -n "${NEXTITEM}" ]]; then
			DEFAULT="--default-item ${NEXTITEM}"
		else
			DEFAULT=""
		fi

		DIALOG $DEFAULT --menu "Configuration" 17 78 10 \
			"Root-Password"             "${_definerootpass}" \
			"Setup-User"                "${_defineuser}" \
			"Setup-Locale"              "${_definelocale}" \
			"Setup-Keymap"              "${_definekeymap}" \
			"Config-System"             "${_doeditconfig}" \
			"${_return_label}"          "${_mainmenulabel}" 2>${ANSWER} || NEXTITEM="${_return_label}"
		NEXTITEM="$(cat ${ANSWER})"

		case $(cat ${ANSWER}) in
			"Root-Password")
				PASSWDUSER="root"
				set_passwd
				echo "$PASSWDUSER:$PASSWD" | chroot ${DESTDIR} chpasswd
				DONE_CONFIG="1"
				NEXTITEM="Setup-User"
			;;
			"Setup-User")
				_setup_user && NEXTITEM="Setup-Locale"
			;;
			"Setup-Locale")
				set_language && NEXTITEM="Setup-Keymap"
			;;
			"Setup-Keymap")
				set_keyboard && NEXTITEM="Config-System"
			;;
			"Config-System")
				_config_system && NEXTITEM="${_return_label}"
			;;
			"${_return_label}") DONE="1" ;;
			*) DONE="1" ;;
		esac
	done
	if [[ "${DONE_CONFIG}" = "1" ]]; then
		_post_process
	else
		NEXTITEM="4"
	fi
}

_setup_user(){
	#addgroups="video,audio,power,disk,storage,optical,network,lp,scanner"
	DIALOG --inputbox "${_enterusername}" 10 65 "${username}" 2>${ANSWER} || return 1
	REPLY="$(cat ${ANSWER})"
	while [ -z "$(echo $REPLY |grep -E '^[a-z_][a-z0-9_-]*[$]?$')" ];do
		DIALOG --inputbox "${_givecorrectname}" 10 65 "${username}" 2>${ANSWER} || return 1
		REPLY="$(cat ${ANSWER})"
	done

	chroot ${DESTDIR} useradd -m -p "" -g users -G $addgroups $REPLY

	PASSWDUSER="$REPLY"

	if [ -d "${DESTDIR}/var/lib/AccountsService/users" ] ; then
		echo "[User]" > ${DESTDIR}/var/lib/AccountsService/users/$PASSWDUSER
		if [ -e "/usr/bin/startxfce4" ] ; then
			echo "XSession=xfce" >> ${DESTDIR}/var/lib/AccountsService/users/$PASSWDUSER
		fi
		if [ -e "/usr/bin/cinnamon-session" ] ; then
			echo "XSession=cinnamon" >> ${DESTDIR}/var/lib/AccountsService/users/$PASSWDUSER
		fi
		if [ -e "/usr/bin/mate-session" ] ; then
			echo "XSession=mate" >> ${DESTDIR}/var/lib/AccountsService/users/$PASSWDUSER
		fi
		if [ -e "/usr/bin/enlightenment_start" ] ; then
			echo "XSession=enlightenment" >> ${DESTDIR}/var/lib/AccountsService/users/$PASSWDUSER
		fi
		if [ -e "/usr/bin/openbox-session" ] ; then
			echo "XSession=openbox" >> ${DESTDIR}/var/lib/AccountsService/users/$PASSWDUSER
		fi
		if [ -e "/usr/bin/startlxde" ] ; then
			echo "XSession=LXDE" >> ${DESTDIR}/var/lib/AccountsService/users/$PASSWDUSER
		fi
		if [ -e "/usr/bin/lxqt-session" ] ; then
			echo "XSession=LXQt" >> ${DESTDIR}/var/lib/AccountsService/users/$PASSWDUSER
		fi
		echo "Icon=" >> ${DESTDIR}/var/lib/AccountsService/users/$PASSWDUSER
	fi

	if DIALOG --yesno "${_addsudouserdl1}${REPLY}${_addsudouserdl2}" 6 40;then
		echo "${PASSWDUSER}     ALL=(ALL) ALL" >> ${DESTDIR}/etc/sudoers
	else
		chroot ${DESTDIR} gpasswd -d "${PASSWDUSER}" wheel
	fi
	sed -i -e 's|# %wheel ALL=(ALL) ALL|%wheel ALL=(ALL) ALL|g' ${DESTDIR}/etc/sudoers
	chmod 0440 ${DESTDIR}/etc/sudoers
	set_passwd
	echo "$PASSWDUSER:$PASSWD" | chroot ${DESTDIR} chpasswd
	NEXTITEM="Setup-User"
	DONE_CONFIG=1
}

_config_system(){
	DONE=0
	NEXTITEM=""
	while [[ "${DONE}" = "0" ]]; do
		if [[ -n "${NEXTITEM}" ]]; then
			DEFAULT="--default-item ${NEXTITEM}"
		else
			DEFAULT=""
		fi
		if [[ -e /run/systemd ]]; then
			DIALOG $DEFAULT --menu "Configuration" 17 78 10 \
				"/etc/fstab"                "${_fstabtext}" \
				"/etc/mkinitcpio.conf"      "${_mkinitcpioconftext}" \
				"/etc/resolv.conf"          "${_resolvconftext}" \
				"/etc/hostname"             "${_hostnametext}" \
				"/etc/hosts"                "${_hoststext}" \
				"/etc/hosts.deny"           "${_hostsdenytext}" \
				"/etc/hosts.allow"          "${_hostsallowtext}" \
				"/etc/locale.gen"           "${_localegentext}" \
				"/etc/locale.conf"          "${_localeconftext}" \
				"/etc/environment"          "${_environmenttext}" \
				"/etc/pacman-mirrors.conf"  "${_mirrorconftext}" \
				"/etc/pacman.d/mirrorlist"  "${_mirrorlisttext}" \
				"/etc/X11/xorg.conf.d/10-evdev.conf"  "${_xorgevdevconftext}" \
				"/etc/vconsole.conf"        "${_vconsoletext}" \
				"${_return_label}"        "${_return_label}" 2>${ANSWER} || NEXTITEM="${_return_label}"
			NEXTITEM="$(cat ${ANSWER})"
		else
			DIALOG $DEFAULT --menu "Configuration" 17 78 10 \
				"/etc/fstab"                "${_fstabtext}" \
				"/etc/mkinitcpio.conf"      "${_mkinitcpioconftext}" \
				"/etc/resolv.conf"          "${_resolvconftext}" \
				"/etc/rc.conf"              "${_rcconfigtext}" \
				"/etc/conf.d/hostname"      "${_hostnametext}" \
				"/etc/conf.d/keymaps"       "${_localeconftext}" \
				"/etc/conf.d/modules"       "${_modulesconftext}" \
				"/etc/conf.d/hwclock"       "${_hwclockconftext}" \
				"/etc/conf.d/xdm"           "${_xdmconftext}" \
				"/etc/hosts"                "${_hoststext}" \
				"/etc/hosts.deny"           "${_hostsdenytext}" \
				"/etc/hosts.allow"          "${_hostsallowtext}" \
				"/etc/locale.gen"           "${_localegentext}" \
				"/etc/environment"          "${_environmenttext}" \
				"/etc/pacman-mirrors.conf"  "${_mirrorconftext}" \
				"/etc/pacman.d/mirrorlist"  "${_mirrorlisttext}" \
				"/etc/X11/xorg.conf.d/10-evdev.conf"  "${_xorgevdevconftext}" \
				"/etc/X11/xorg.conf.d/00-keyboard.conf"  "X11 keyboard configuration" \
				"${_return_label}"        "${_return_label}" 2>${ANSWER} || NEXTITEM="${_return_label}"
			NEXTITEM="$(cat ${ANSWER})"
		fi

		if [ "${NEXTITEM}" = "${_return_label}" -o -z "${NEXTITEM}" ]; then
			DONE=1
		else
			$EDITOR ${DESTDIR}${NEXTITEM}
		fi
	done
}

set_clock(){
	# utc or local?
	DIALOG --menu "${_machinetimezone}" 10 72 2 \
		"UTC" " " \
		"localtime" " " \
		2>${ANSWER} || return 1
	HARDWARECLOCK=$(cat ${ANSWER})

	# timezone?
	REGIONS=""
	for i in $(grep '^[A-Z]' /usr/share/zoneinfo/zone.tab | cut -f 3 | sed -e 's#/.*##g'| sort -u); do
		REGIONS="$REGIONS $i -"
	done
	region=""
	zone=""
	while [ -z "$zone" ];do
		region=""
		while [ -z "$region" ];do
			:>${ANSWER}
			DIALOG --menu "${_selectregion}" 0 0 0 $REGIONS 2>${ANSWER}
			region=$(cat ${ANSWER})
		done
		ZONES=""
		for i in $(grep '^[A-Z]' /usr/share/zoneinfo/zone.tab | grep $region/ | cut -f 3 | sed -e "s#$region/##g"| sort -u); do
			ZONES="$ZONES $i -"
		done
		:>${ANSWER}
		DIALOG --menu "${_selecttimezone}" 0 0 0 $ZONES 2>${ANSWER}
		zone=$(cat ${ANSWER})
	done
	TIMEZONE="$region/$zone"

	# set system clock from hwclock - stolen from rc.sysinit
	local HWCLOCK_PARAMS=""


	if [[ -e /run/openrc ]];then
		local _conf_clock='clock="'${HARDWARECLOCK}'"'
		sed -i -e "s|^.*clcok=.*|${_conf_clock}|" /etc/conf.d/hwclock
		fi
		if [ "$HARDWARECLOCK" = "UTC" ]; then
		HWCLOCK_PARAMS="$HWCLOCK_PARAMS --utc"
	else
	HWCLOCK_PARAMS="$HWCLOCK_PARAMS --localtime"
		if [[ -e /run/systemd ]];then
			echo "0.0 0.0 0.0" > /etc/adjtime &> /dev/null
			echo "0" >> /etc/adjtime &> /dev/null
			echo "LOCAL" >> /etc/adjtime &> /dev/null
		fi
	fi
	if [ "$TIMEZONE" != "" -a -e "/usr/share/zoneinfo/$TIMEZONE" ]; then
		/bin/rm -f /etc/localtime
		#/bin/cp "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
		ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
	fi
	/usr/bin/hwclock --hctosys $HWCLOCK_PARAMS --noadjfile

	if [[ -e /run/openrc ]];then
		echo "${TIMEZONE}" > /etc/timezone
	fi

	# display and ask to set date/time
	DIALOG --calendar "${_choosedatetime}" 0 0 0 0 0 2> ${ANSWER} || return 1
	local _date="$(cat ${ANSWER})"
	DIALOG --timebox "${_choosehourtime}" 0 0 2> ${ANSWER} || return 1
	local _time="$(cat ${ANSWER})"
	echo "date: $_date time: $_time" >$LOG

	# save the time
	# DD/MM/YYYY hh:mm:ss -> YYYY-MM-DD hh:mm:ss
	local _datetime="$(echo "$_date" "$_time" | sed 's#\(..\)/\(..\)/\(....\) \(..\):\(..\):\(..\)#\3-\2-\1 \4:\5:\6#g')"
	echo "setting date to: $_datetime" >$LOG
	date -s "$_datetime" 2>&1 >$LOG
	/usr/bin/hwclock --systohc $HWCLOCK_PARAMS --noadjfile

	S_CLOCK=1
	NEXTITEM="2"
}

set_passwd(){
	# trap tmp-file for passwd
	trap "rm -f ${ANSWER}" 0 1 2 5 15

	# get password
	DIALOG --title "$_passwdtitle" \
		--clear \
		--insecure \
		--passwordbox "$_passwddl $PASSWDUSER" 10 30 2> ${ANSWER}
	PASSWD="$(cat ${ANSWER})"
	DIALOG --title "$_passwdtitle" \
		--clear \
		--insecure \
		--passwordbox "$_passwddl2 $PASSWDUSER" 10 30 2> ${ANSWER}
	PASSWD2="$(cat ${ANSWER})"
	if [ "$PASSWD" == "$PASSWD2" ]; then
		PASSWD=$PASSWD
		_passwddl=$_passwddl1
	else
		_passwddl=$_passwddl3
		set_passwd
	fi
}

