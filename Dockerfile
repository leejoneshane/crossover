FROM debian:stable-slim

ENV DEBIAN_FRONTEND noninteractive

RUN dpkg --add-architecture i386 \
    && echo "deb-src http://deb.debian.org/debian stable main" >> /etc/apt/sources.list \
    && apt-get update \
    && apt-get install -y --no-install-recommends git build-essential dpkg-dev pulseaudio libpulse-dev \
    && git config --global http.sslverify false \
    && apt-get update \
    && apt -y build-dep pulseaudio \
    && chown -Rv _apt:root /var/cache/apt/archives/partial/ \
    && chmod -Rv 700 /var/cache/apt/archives/partial/ \
    && cd /root && apt source pulseaudio \
    && cd pulseaudio-* && ./configure \
    && cd /root && git clone https://github.com/neutrinolabs/pulseaudio-module-xrdp.git \
    && cd pulseaudio-module-xrdp && ./bootstrap && ./configure PULSE_DIR=/root/pulseaudio-* \
    && make && make install \
    && cd /root && rm -rf /root/pulseaudio && rm -rf /root/pulseaudio-* \
    && mkdir /var/lib/xrdp-pulseaudio-installer \
    && cp -p /usr/lib/pulse-*/modules/module-xrdp-*.so /var/lib/xrdp-pulseaudio-installer/ \
    && apt-get remove -y build-essential dpkg-dev libpulse-dev && apt-get autoremove -y

ENV LC_ALL zh_TW.UTF-8
ENV LANG zh_TW.UTF-8
ENV LANGUAGE zh_TW

RUN ln -snf /usr/share/zoneinfo/Asia/Taipei /etc/localtime && echo Asia/Taipei > /etc/timezone \
    && apt-get install -y tzdata locales \
    && echo "zh_TW.UTF-8 UTF-8" > /etc/locale.gen \
    && locale-gen "zh_TW.UTF-8" \
    && apt-get install -y --no-install-recommends sudo pavucontrol pulseaudio-utils \
                           gnome-icon-theme xorg xfce4 xfce4-goodies iceweasel dbus-x11 \
                           tigervnc-standalone-server tigervnc-common xrdp supervisor \
                           xfonts-wqy im-config scim-chewing scim-gtk-immodule \
                           gir1.2-vte-2.91 lib32z1 libc6-i386 python3-dbus python3-gi \
    && rm -rf /var/lib/apt/lists/* \
    && cd /usr/lib \
    && git clone https://github.com/novnc/noVNC \
    && cp /usr/lib/noVNC/vnc.html /usr/lib/noVNC/index.html \
    && cd /usr/lib/noVNC/utils \
    && git clone https://github.com/novnc/websockify \
    && xrdp-keygen xrdp auto

ARG VER=20.0.2
ADD https://media.codeweavers.com/pub/crossover/cxlinux/demo/crossover_$VER-1.deb /crossover.deb

RUN dpkg -i /crossover.deb 2>/dev/null \
    && rm -rf /crossover.deb

RUN useradd -G video,sudo,pulse-access -ms /bin/bash crossover \
    && echo "crossover:crossover" | chpasswd \
    && echo 'crossover ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers \
    && mkdir /home/crossover/.vnc/ \
    && echo "crossover" | vncpasswd -f > /home/crossover/.vnc/passwd \
    && echo "#!/bin/bash\nstartxfce4 &\n" > /home/crossover/.vnc/xstartup \
    && chmod +x /home/crossover/.vnc/xstartup \
    && echo 'exit-idle-time = -1' >> /etc/pulse/daemon.conf \
    && mkdir /home/crossover/.config /run/crossover \
    && chown -R crossover:crossover /home/crossover /run/crossover \
    && chmod -R 755 /home/crossover/.config \
    && chmod -R 7700 /run/crossover \
    && sed -i "s/; autospawn = (.*)/autospawn=yes/" /etc/pulse/client.conf

COPY servers.conf /etc/supervisor/conf.d/servers.conf

ENV DISPLAY :1
ENV USER crossover
ENV HOME /home/crossover
ENV SHELL /bin/bash
ENV XDG_CONFIG_HOME /home/crossover/.config
ENV XDG_RUNTIME_DIR /run/crossover
ENV PULSE_SERVER unix:/home/crossover/.config/pulse/native-sock
ENV PULSE_COOKIE unix:/home/crossover/.config/pulse/cookie
USER crossover
WORKDIR /home/crossover

EXPOSE 80 3389 5900
CMD sudo /usr/bin/supervisord -n