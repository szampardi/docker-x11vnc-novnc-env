ARG	FROM=ubuntu
FROM	${FROM}
SHELL	["/bin/sh", "-exc"]
ARG	EXTRA_PACKAGES
RUN	if command -v apt; then \
		export DEBIAN_FRONTEND=noninteractive; \
		apt-get update; \
		apt-get dist-upgrade -yqq; \
		apt-get install -yqq --no-install-recommends dbus-x11 gvfs gvfs-backends gvfs-fuse novnc ntfs-3g procps python3-numpy sudo supervisor udev unzip x11-xserver-utils x11vnc xfce4 xfce4-goodies xvfb ${EXTRA_PACKAGES}; \
		ln -vs /usr/share/novnc/vnc_lite.html /usr/share/novnc/index.html; \
		rm -fr /var/cache/apt/*; \
	elif command -v apk; then \
		apk update; \
		apk upgrade --no-cache; \
		apk add --no-cache \
			bash dbus git gtk-vnc \
			gvfs-afc gvfs-afp gvfs-archive gvfs-avahi gvfs-cdda gvfs-dav gvfs-dev gvfs-fuse gvfs-goa gvfs-gphoto2 gvfs-lang gvfs-mtp gvfs-nfs gvfs-smb \
			lightdm-gtk-greeter ntfs-3g procps py3-numpy python3 sudo supervisor udev udisks2 unzip wget x11vnc xdotool xf86-video-dummy \
			xfce4 xfce4-screenshooter xfce4-session xfce4-settings xfce4-stopwatch-plugin xfce4-taskmanager xfce4-terminal xfce4-weather-plugin xfce4-xkb-plugin \
			xproto xset xterm xvfb ${EXTRA_PACKAGES}; \
		apk add --no-cache --virtual compiledeps fontconfig-dev freetype-dev gcc libxft-dev linux-headers make musl-dev; \
		Xdummy -install; \
		apk del compiledeps; \
		rm -fr /var/cache/apk; \
		mkdir -vp /opt/noVNC; \
		cd /opt/noVNC; \
		git clone --depth=1 https://github.com/kanaka/noVNC.git $(pwd); \
		ln -vs vnc_lite.html index.html; \
		git clone --depth=1 https://github.com/kanaka/websockify utils/websockify; \
		rm -fr $(find $(pwd) -type d -name .git); \
	else \
		printf 'Base O.S. not supported!\n'; \
		exit 2; \
	fi
SHELL	["/bin/bash", "-evxo", "pipefail", "-c"]
ARG	SESSION_USER=webuser
ARG	SUDO_USER=0
WORKDIR	/etc/conf.d
RUN	if command -v apt; then \
		tee /etc/conf.d/udevd.conf <<<$'[program:udevd]\nstdout_logfile=/tmp/udevd.log\nredirect_stderr=true\ncommand=/lib/systemd/systemd-udevd\nautorestart=true\n'; \
		tee /etc/conf.d/websockify.conf <<<$'[program:websockify]\ndirectory=/usr/share/novnc\nuser=%(ENV_SESSION_USER)s\nstdout_logfile=/tmp/websockify.log\nredirect_stderr=true\ncommand=/usr/bin/websockify %(ENV_WEBSOCKIFY_TLS)s --web /usr/share/novnc "%(ENV_WEB_PORT)s" "%(ENV_VNC_ADDR)s":"%(ENV_VNC_PORT)s"\nautorestart=true\n'; \
		useradd --home /dev/shm --no-create-home --shell /bin/bash --uid 1000 "${SESSION_USER}"; \
	elif command -v apk; then \
		tee /etc/conf.d/udevd.conf <<<$'[program:udevd]\nstdout_logfile=/tmp/udevd.log\nredirect_stderr=true\ncommand=/sbin/udevd\nautorestart=true\n'; \
		tee /etc/conf.d/websockify.conf <<<$'[program:websockify]\ndirectory=/opt/noVNC\nuser=%(ENV_SESSION_USER)s\nstdout_logfile=/tmp/websockify.log\nredirect_stderr=true\ncommand=/opt/noVNC/utils/websockify/run %(ENV_WEBSOCKIFY_TLS)s --web /opt/noVNC "%(ENV_WEB_PORT)s" "%(ENV_VNC_ADDR)s":"%(ENV_VNC_PORT)s"\nautorestart=true\n'; \
		adduser -h /dev/shm -s /bin/bash -D -H -u 1000 "${SESSION_USER}"; \
	fi; \
	tee /etc/conf.d/dbus-daemon.conf <<<$'[program:dbus-daemon]\nstdout_logfile=/tmp/dbus-daemon.log\nredirect_stderr=true\ncommand=/usr/bin/dbus-daemon --system --nofork\nautorestart=true\n'; \
	tee /etc/conf.d/x-prog.conf <<<$'[program:x-prog]\nuser=%(ENV_SESSION_USER)s\nstdout_logfile=/tmp/x-prog.log\nredirect_stderr=true\ncommand=%(ENV_X_PROG)s\nautorestart=true\n'; \
	tee /etc/conf.d/x11vnc.conf <<<$'[program:x11vnc]\nuser=%(ENV_SESSION_USER)s\nstdout_logfile=/tmp/x11vnc.log\nredirect_stderr=true\ncommand=/usr/bin/x11vnc -xkb -forever -shared %(ENV_VNCPASSWD)s\nautorestart=true\n'; \
	tee /etc/conf.d/xvfb.conf <<<$'[program:xvfb]\nuser=%(ENV_SESSION_USER)s\nstdout_logfile=/tmp/xvfb.log\nredirect_stderr=true\ncommand=/usr/bin/Xvfb "%(ENV_DISPLAY)s" -screen 0 "%(ENV_VSCREEN_RES)s" -listen tcp -ac\nautorestart=true\n'; \
	tee /etc/supervisord.conf <<<$'[supervisord]\nnodaemon=true\n[include]\nfiles = /etc/conf.d/*.conf\n'; \
	chown -v nobody:nogroup /etc/conf.d/*.conf /etc/supervisord.conf; \
	chmod -v 444 /etc/conf.d/*.conf /etc/supervisord.conf; \
	tee /bin/entrypoint.sh <<<$'#!/bin/bash -xe\nmkdir -vp /var/run/dbus\nif [[ -s ${TLS_CERT} ]] && [[ -s ${TLS_KEY} ]]; then export WEBSOCKIFY_TLS="--cert ${TLS_CERT} --key ${TLS_KEY} --ssl-only"; fi\nif [[ -n ${VNCPASSWD} ]]; then export VNCPASSWD="-passwd ${VNCPASSWD}"; fi\n{\n\tuntil [[ -n $(pidof Xvfb) ]]; do sleep 3; done\n\t/usr/bin/xset -dpms || true\n\t/usr/bin/xset s noblank\n\t/usr/bin/xset s off\n} &\n/usr/bin/supervisord -c /etc/supervisord.conf\n'; \
	chmod -v 555 /bin/entrypoint.sh; \
	if [[ ${SUDO_USER} != 0 ]]; then tee -a /etc/sudoers <<<"${SESSION_USER} ALL=(ALL) NOPASSWD:ALL"; fi

ENV	HOME=/dev/shm \
	DISPLAY=:0 \
	LANG=en_US.UTF-8 \
	LANGUAGE=en_US.UTF-8 \
	LC_ALL=C.UTF-8 \
	VSCREEN_RES=1920x1080x24 \
	VNC_ADDR=127.0.0.1 \
	VNC_PORT=5900 \
	VNCPASSWD= \
	WEB_PORT=6080 \
	TLS_CERT= \
	TLS_KEY= \
	WEBSOCKIFY_TLS= \
	X_PROG=/usr/bin/xfce4-session \
	SESSION_USER=${SESSION_USER}
WORKDIR	${HOME}
EXPOSE	5900/tcp 6080/tcp
ENTRYPOINT	["/bin/entrypoint.sh"]
