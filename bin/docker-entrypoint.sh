#!/bin/bash
if [ ! -f "/usr/share/backgrounds/xfce/hostname.png" ];
    then
        convert -background black -fill white -font Liberation-Sans -size 1920x1080 -gravity center -pointsize 128 label:`hostname` /usr/share/backgrounds/xfce/hostname.png
fi

if [ ! -f "/etc/users_created" ];
    then
    test -f /etc/users.list || exit 0
    while read username password; do
        if [ ! -z "$username" ]; then
		    grep ^$username /etc/passwd && continue
            echo "adding user $username"
            useradd -m $username -U -s /bin/bash
            echo "setting password for $username"
            echo "${username}:${password}" | chpasswd
            echo "adding $username to sudo"
            adduser $username sudo
            echo "${username}    ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
		fi
    done < /etc/users.list
    touch /etc/users_created
fi

if [ -f "default-desktop.tar.gz" ];
    then
      cd / && tar -xvzf default-desktop.tar.gz
fi

# Add the ssh config if needed

if [ ! -f "/etc/ssh/sshd_config" ];
	then
		cp /ssh_orig/sshd_config /etc/ssh
fi

if [ ! -f "/etc/ssh/ssh_config" ];
	then
		cp /ssh_orig/ssh_config /etc/ssh
fi

if [ ! -f "/etc/ssh/moduli" ];
	then
		cp /ssh_orig/moduli /etc/ssh
fi

# generate fresh rsa key if needed
if [ ! -f "/etc/ssh/ssh_host_rsa_key" ];
	then
		ssh-keygen -f /etc/ssh/ssh_host_rsa_key -N '' -t rsa
fi

# generate fresh dsa key if needed
if [ ! -f "/etc/ssh/ssh_host_dsa_key" ];
	then
		ssh-keygen -f /etc/ssh/ssh_host_dsa_key -N '' -t dsa
fi

#prepare run dir
mkdir -p /var/run/sshd


# generate xrdp key
if [ ! -f "/etc/xrdp/rsakeys.ini" ];
	then
		xrdp-keygen xrdp auto
fi

# generate certificate for tls connection
if [ ! -f "/etc/xrdp/cert.pem" ];
	then
		# delete eventual leftover private key
		rm -f /etc/xrdp/key.pem || true
		cd /etc/xrdp
		if [ ! $CERTIFICATE_SUBJECT ]; then
			CERTIFICATE_SUBJECT="/C=US/ST=Some State/L=Some City/O=Some Org/OU=Some Unit/CN=Terminalserver"
		fi
		openssl req -x509 -newkey rsa:2048 -nodes -keyout /etc/xrdp/key.pem -out /etc/xrdp/cert.pem -days 365 -subj "$CERTIFICATE_SUBJECT"
		crudini --set /etc/xrdp/xrdp.ini Globals security_layer tls
		crudini --set /etc/xrdp/xrdp.ini Globals certificate /etc/xrdp/cert.pem
		crudini --set /etc/xrdp/xrdp.ini Globals key_file /etc/xrdp/key.pem

fi

# generate machine-id
uuidgen > /etc/machine-id

# set keyboard for all sh users
echo "export QT_XKB_CONFIG_ROOT=/usr/share/X11/locale" >> /etc/profile


exec "$@"
