ARG	FROM=alpine
FROM	${FROM}
SHELL	["/bin/ash", "-evxo", "pipefail", "-c"]
RUN	apk update; \
	apk upgrade --no-cache; \
	apk add --no-cache \
		bash dbus git gtk-vnc \
		gvfs-afc gvfs-afp gvfs-archive gvfs-avahi gvfs-cdda gvfs-dav gvfs-dev gvfs-fuse gvfs-goa gvfs-gphoto2 gvfs-lang gvfs-mtp gvfs-nfs gvfs-smb \
		lightdm-gtk-greeter ntfs-3g procps py3-numpy python3 sudo supervisor udev udisks2 unzip wget x11vnc xdotool xf86-video-dummy \
		xfce4 xfce4-screenshooter xfce4-session xfce4-settings xfce4-stopwatch-plugin xfce4-taskmanager xfce4-terminal xfce4-weather-plugin xfce4-xkb-plugin \
		xproto xset xterm xvfb; \
	apk add --no-cache --virtual compiledeps fontconfig-dev freetype-dev gcc libxft-dev linux-headers make musl-dev; \
	Xdummy -install; \
	apk del compiledeps; \
	rm -fr /var/cache/apk
SHELL	["/bin/bash", "-xec"]

WORKDIR	/opt/noVNC
RUN	git clone --depth=1 https://github.com/kanaka/noVNC.git $(pwd); \
	ln -vs vnc_lite.html index.html; \
	git clone --depth=1 https://github.com/kanaka/websockify utils/websockify; \
	rm -fr $(find $(pwd) -type d -name .git)

ARG	SESSION_USER=webuser
WORKDIR	/etc/conf.d
RUN	tee /etc/conf.d/udevd.conf <<<$'[program:udevd]\nstdout_logfile=/tmp/udevd.log\nredirect_stderr=true\ncommand=/sbin/udevd\nautorestart=true\n'; \
	tee /etc/conf.d/dbus-daemon.conf <<<$'[program:dbus-daemon]\nstdout_logfile=/tmp/dbus-daemon.log\nredirect_stderr=true\ncommand=/usr/bin/dbus-daemon --system --nofork\nautorestart=true\n'; \
	tee /etc/conf.d/websockify.conf <<<$'[program:websockify]\ndirectory=/opt/noVNC\nuser=%(ENV_SESSION_USER)s\nstdout_logfile=/tmp/websockify.log\nredirect_stderr=true\ncommand=/opt/noVNC/utils/websockify/run %(ENV_WEBSOCKIFY_TLS)s --web /opt/noVNC "%(ENV_WEB_PORT)s" "%(ENV_VNC_ADDR)s":"%(ENV_VNC_PORT)s"\nautorestart=true\n'; \
	tee /etc/conf.d/x-prog.conf <<<$'[program:x-prog]\nuser=%(ENV_SESSION_USER)s\nstdout_logfile=/tmp/x-prog.log\nredirect_stderr=true\ncommand=%(ENV_X_PROG)s\nautorestart=true\n'; \
	tee /etc/conf.d/x11vnc.conf <<<$'[program:x11vnc]\nuser=%(ENV_SESSION_USER)s\nstdout_logfile=/tmp/x11vnc.log\nredirect_stderr=true\ncommand=x11vnc -xkb -forever -shared %(ENV_VNCPASSWD)s\nautorestart=true\n'; \
	tee /etc/conf.d/xterm.conf <<<$'[program:xterm]\nuser=%(ENV_SESSION_USER)s\nstdout_logfile=/tmp/xterm.log\nredirect_stderr=true\ncommand=xterm\nautorestart=true\n'; \
	tee /etc/conf.d/xvfb.conf <<<$'[program:xvfb]\nuser=%(ENV_SESSION_USER)s\nstdout_logfile=/tmp/xvfb.log\nredirect_stderr=true\ncommand=Xvfb "%(ENV_DISPLAY)s" -screen 0 "%(ENV_VSCREEN_RES)s" -listen tcp -ac\nautorestart=true\n'; \
	tee /etc/supervisord.conf <<<$'[supervisord]\nnodaemon=true\n[include]\nfiles = /etc/conf.d/*.conf\n'; \
	chown -v nobody:nobody /etc/conf.d/*.conf /etc/supervisord.conf; \
	chmod -v 444 /etc/conf.d/*.conf /etc/supervisord.conf; \
	tee /bin/entrypoint.sh <<<$'#!/bin/bash -xe\nif [[ -s ${TLS_CERT} ]] && [[ -s ${TLS_KEY} ]]; then export WEBSOCKIFY_TLS="--cert ${TLS_CERT} --key ${TLS_KEY} --ssl-only"; fi\nif [[ -n ${VNCPASSWD} ]]; then export VNCPASSWD="-passwd ${VNCPASSWD}"; fi\n{\n\tuntil [[ -n $(pidof Xvfb) ]]; do sleep 3; done\n\t/usr/bin/xset -dpms || true\n\t/usr/bin/xset s noblank\n\t/usr/bin/xset s off\n} &\n/usr/bin/supervisord -c /etc/supervisord.conf\n'; \
	chmod -v 555 /bin/entrypoint.sh; \
	adduser -h /dev/shm -s /bin/bash -D -H -u 1000 "${SESSION_USER}"; \
	tee -a /etc/sudoers <<<"${SESSION_USER} ALL=(ALL) NOPASSWD:ALL"

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
