FROM ubuntu:20.04 as builder
LABEL maintainer="John Gruber <j.gruber@f5.com>"

# Install packages

ENV DEBIAN_FRONTEND noninteractive
RUN sed -i "s/# deb-src/deb-src/g" /etc/apt/sources.list
RUN apt-get -y update
RUN apt-get -yy upgrade
ENV BUILD_DEPS="git autoconf pkg-config libssl-dev libpam0g-dev \
    libx11-dev libxfixes-dev libxrandr-dev nasm xsltproc flex \
    bison libxml2-dev dpkg-dev libcap-dev"
RUN apt-get -yy install  sudo apt-utils software-properties-common $BUILD_DEPS


# Build xrdp

WORKDIR /tmp
RUN apt-get source pulseaudio
RUN apt-get build-dep -yy pulseaudio
WORKDIR /tmp/pulseaudio-13.99.1
RUN dpkg-buildpackage -rfakeroot -uc -b
WORKDIR /tmp
RUN git clone --branch devel --recursive https://github.com/neutrinolabs/xrdp.git
WORKDIR /tmp/xrdp
RUN ./bootstrap
RUN ./configure
RUN make
RUN make install
WORKDIR /tmp
RUN  apt -yy install libpulse-dev
RUN git clone --recursive https://github.com/neutrinolabs/pulseaudio-module-xrdp.git
WORKDIR /tmp/pulseaudio-module-xrdp
RUN ./bootstrap && ./configure PULSE_DIR=/tmp/pulseaudio-13.99.1
RUN make
RUN mkdir -p /tmp/so
RUN cp src/.libs/*.so /tmp/so

FROM ubuntu:20.04
ENV DEBIAN_FRONTEND noninteractive
RUN apt update && apt install -y software-properties-common apt-utils
RUN add-apt-repository "deb http://archive.canonical.com/ $(lsb_release -sc) partner" && apt update
RUN apt -y full-upgrade && apt-get install -y \
  ca-certificates \
  crudini \
  less \
  locales \
  openssh-server \
  pulseaudio \
  sudo \
  supervisor \
  uuid-runtime \
  vim \
  wget \
  xauth \
  xfce4 \
  xfce4-taskmanager \
  xfce4-terminal \
  xfce4-goodies \
  xubuntu-default-settings \
  ristretto \
  xorgxrdp \
  xprintidle \
  xrdp \
  xdg-utils \
  ghostscript \
  ffmpeg \
  fonts-liberation \
  software-properties-common \
  apt-transport-https \
  gpg \
  gpg-agent \
  wget \
  curl \
  ansible \
  nodejs \
  imagemagick
RUN curl -s https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - && \
    touch /etc/apt/sources.list.d/kubernetes.list && \
    echo "deb http://apt.kubernetes.io/ kubernetes-xenial main" | tee -a /etc/apt/sources.list.d/kubernetes.list && \
    apt update && \
    apt install -y kubectl
RUN cd /usr/src && \
    curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 && \
    chmod +x /usr/src/get_helm.sh && \
    /usr/src/get_helm.sh
RUN wget -c https://golang.org/dl/go1.17.linux-amd64.tar.gz -O - | tar -xz -C /usr/local && \
    ln -s /usr/local/go/bin/go /usr/bin/go
RUN curl -fsSL https://apt.releases.hashicorp.com/gpg | apt-key add - && \
    apt-add-repository "deb [arch=$(dpkg --print-architecture)] https://apt.releases.hashicorp.com $(lsb_release -cs) main" && \
    apt update && \
    apt install terraform
RUN cd /usr/src && \
    wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb && \
    dpkg -i /usr/src/google-chrome-stable_current_amd64.deb
RUN wget -q https://packages.microsoft.com/keys/microsoft.asc -O- | sudo apt-key add - && \
    add-apt-repository -y "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main" && \
    apt update && \
    apt -y install code
RUN apt purge -y light-locker xscreensaver gsfonts && \
  apt autoremove -y && \
  rm -rf /var/cache/apt /var/lib/apt/lists
RUN mkdir -p /var/lib/xrdp-pulseaudio-installer
COPY --from=builder /tmp/so/module-xrdp-source.so /var/lib/xrdp-pulseaudio-installer
COPY --from=builder /tmp/so/module-xrdp-sink.so /var/lib/xrdp-pulseaudio-installer
ADD bin /usr/bin
ADD etc /etc

# Added capabilities to the READ doc
#RUN sed -i 's/google-chrome-stable/google-chrome-stable --no-sandbox/g' /usr/share/applications/google-chrome.desktop
#RUN sed -i 's/\/usr\/share\/code\/code/\/usr\/share\/code\/code --no-sandbox/g' /usr/share/applications/code.desktop

# Configure
RUN mkdir /var/run/dbus && \
  cp /etc/X11/xrdp/xorg.conf /etc/X11 && \
  sed -i "s/console/anybody/g" /etc/X11/Xwrapper.config && \
  sed -i "s/xrdp\/xorg/xorg/g" /etc/xrdp/sesman.ini && \
  locale-gen en_US.UTF-8 && \
  echo "pulseaudio -D --enable-memfd=True" > /etc/skel/.Xsession && \
  echo "xfce4-session" >> /etc/skel/.Xsession && \
  rm -rf /etc/xrdp/rsakeys.ini /etc/xrdp/*.pem

COPY default-desktop.tar.gz /default-desktop.tar.gz

# Docker config
EXPOSE 3389 22 9001
ENTRYPOINT ["/usr/bin/docker-entrypoint.sh"]
CMD ["supervisord"]
