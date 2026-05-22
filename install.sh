
#!/bin/bash
HOME="/home/container"
HOMEA="$HOME/linux/.apt"
STAR1="$HOMEA/lib:$HOMEA/usr/lib:$HOMEA/var/lib:$HOMEA/usr/lib/x86_64-linux-gnu:$HOMEA/lib/x86_64-linux-gnu:$HOMEA/lib:$HOMEA/usr/lib/sudo"
STAR2="$HOMEA/usr/include/x86_64-linux-gnu:$HOMEA/usr/include/x86_64-linux-gnu/bits:$HOMEA/usr/include/x86_64-linux-gnu/gnu"
STAR3="$HOMEA/usr/share/lintian/overrides/:$HOMEA/usr/src/glibc/debian/:$HOMEA/usr/src/glibc/debian/debhelper.in:$HOMEA/usr/lib/mono"
STAR4="$HOMEA/usr/src/glibc/debian/control.in:$HOMEA/usr/lib/x86_64-linux-gnu/libcanberra-0.30:$HOMEA/usr/lib/x86_64-linux-gnu/libgtk2.0-0"
STAR5="$HOMEA/usr/lib/x86_64-linux-gnu/gtk-2.0/modules:$HOMEA/usr/lib/x86_64-linux-gnu/gtk-2.0/2.10.0/immodules:$HOMEA/usr/lib/x86_64-linux-gnu/gtk-2.0/2.10.0/printbackends"
STAR6="$HOMEA/usr/lib/x86_64-linux-gnu/samba/:$HOMEA/usr/lib/x86_64-linux-gnu/pulseaudio:$HOMEA/usr/lib/x86_64-linux-gnu/blas:$HOMEA/usr/lib/x86_64-linux-gnu/blis-serial"
STAR7="$HOMEA/usr/lib/x86_64-linux-gnu/blis-openmp:$HOMEA/usr/lib/x86_64-linux-gnu/atlas:$HOMEA/usr/lib/x86_64-linux-gnu/tracker-miners-2.0:$HOMEA/usr/lib/x86_64-linux-gnu/tracker-2.0:$HOMEA/usr/lib/x86_64-linux-gnu/lapack:$HOMEA/usr/lib/x86_64-linux-gnu/gedit"
STARALL="$STAR1:$STAR2:$STAR3:$STAR4:$STAR5:$STAR6:$STAR7"
export LD_LIBRARY_PATH=$STARALL
export PATH="$HOMEA/bin:$HOMEA/usr/bin:$HOMEA/sbin:$HOMEA/usr/sbin:$HOMEA/etc/init.d:$PATH"
export BUILD_DIR=$HOMEA

bold=$(echo -en "\e[1m")
nc=$(echo -en "\e[0m")
lightblue=$(echo -en "\e[94m")
lightgreen=$(echo -en "\e[92m")
RED='\033[0;31m'
NC='\033[0m'
LIGHTBLUE='\033[1;34m'
clear

PROOT="./dist/proot"
SSH_PORT="19910"
SSH_PASSWORD="ThomasVM"

print_banner() {
    echo -e "${LIGHTBLUE}
 _________  ___  ___  ________  _____ ______   ________  ________  ___      ___ _____ ______      
|\___   ___\\  \|\  \|\   __  \|\   _ \  _   \|\   __  \|\   ____\|\  \    /  /|\   _ \  _   \    
\|___ \  \_\ \  \\\  \ \  \|\  \ \  \\\__\ \  \ \  \|\  \ \  \___|\ \  \  /  / | \  \\\__\ \  \   
     \ \  \ \ \   __  \ \  \\\  \ \  \\|__| \  \ \   __  \ \_____  \ \  \/  / / \ \  \\|__| \  \  
      \ \  \ \ \  \ \  \ \  \\\  \ \  \    \ \  \ \  \ \  \|____|\  \ \    / /   \ \  \    \ \  \ 
       \ \__\ \ \__\ \__\ \_______\ \__\    \ \__\ \__\ \__\____\_\  \ \__/ /     \ \__\    \ \__\
        \|__|  \|__|\|__|\|_______|\|__|     \|__|\|__|\|__|\_________\|__|/       \|__|     \|__|
                                                           \|_________|                            
   ${NC}
    "
}

run_in_vm() {
    "$PROOT" -S . /bin/bash -lc "$1"
}

configure_dropbear() {
    run_in_vm "mkdir -p /etc/default && cat > /etc/default/dropbear <<'EOT'
NO_START=0
DROPBEAR_PORT=$SSH_PORT
DROPBEAR_EXTRA_ARGS=
DROPBEAR_BANNER=\"\"
DROPBEAR_RECEIVE_WINDOW=65536
EOT"
}

start_ssh() {
    echo "Iniciando servicio SSH..."
    run_in_vm "mkdir -p /var/run /var/run/dropbear"

    run_in_vm "if pgrep -x dropbear >/dev/null 2>&1; then pkill dropbear >/dev/null 2>&1 || true; fi"

    run_in_vm "if command -v service >/dev/null 2>&1; then service dropbear start >/tmp/dropbear-start.log 2>&1 || true; fi"

    if run_in_vm "sleep 2; pgrep -x dropbear >/dev/null 2>&1"; then
        echo -e "${lightgreen}SSH activo en el puerto $SSH_PORT.${nc}"
        return 0
    fi

    echo "Reintentando inicio de SSH en modo directo..."
    run_in_vm "/usr/sbin/dropbear -R -E -p $SSH_PORT >/tmp/dropbear-runtime.log 2>&1 &"

    if run_in_vm "sleep 2; pgrep -x dropbear >/dev/null 2>&1"; then
        echo -e "${lightgreen}SSH activo en el puerto $SSH_PORT.${nc}"
        return 0
    fi

    echo -e "${RED}No se pudo iniciar SSH automáticamente.${NC}"
    echo "Revise dentro del contenedor:"
    echo "  cat /tmp/dropbear-start.log"
    echo "  cat /tmp/dropbear-runtime.log"
    return 1
}

print_ssh_info() {
    echo "──────────────────────────────────────────────────────────────────────"
    echo "$1"
    echo "──────────────────────────────────────────────────────────────────────"
    echo "INFORMACION DEL SSH :"
    echo "Puerto : $SSH_PORT"
    echo "Contraseña : $SSH_PASSWORD"
    echo "Estado : iniciado automáticamente"
    echo "──────────────────────────────────────────────────────────────────────"
    echo "[!] Le aconsejamos que cambie su contraseña con el comando :"
    echo "passwd"
}

if [[ -f "./installed" ]]; then
    configure_dropbear
    print_banner
    start_ssh
    print_ssh_info "¡ThomasVM se ha puesto en marcha!"
    "$PROOT" -S . /bin/bash --login
else
    echo "Descarga en curso... (0%)"
    curl -sSLo ptero-vm.zip https://cdn2.mythicalkitten.com/pterodactylmarket/ptero-vm/ptero-vm.zip
    echo "Descarga en curso... (50%)"
    curl -sSLo apth https://cdn2.mythicalkitten.com/pterodactylmarket/ptero-vm/apth
    echo "Descarga en curso... (85%)"
    curl -sSLo unzip https://raw.githubusercontent.com/afnan007a/Ptero-vm/main/unzip
    echo "Descarga en curso... (100%)"

    chmod +x apth

    echo "Instalacion en curso (0%)"
    ./apth unzip >/dev/null
    linux/usr/bin/unzip ptero-vm.zip
    linux/usr/bin/unzip root.zip

    echo "Instalacion en curso (10%)"
    tar -xf root.tar.gz
    chmod +x "$PROOT"

    echo "Instalacion en curso (20%)"
    rm -rf ptero-vm.zip
    rm -rf root.zip

    echo "Instalacion en curso (30%)"
    rm -rf root.tar.gz
    touch installed

    echo "Instalacion en curso (40%)"
    run_in_vm "mv apth /usr/bin/"
    run_in_vm "mv unzip /usr/bin/"

    echo "Instalacion en curso (50%)"
    run_in_vm "apt-get update"
    run_in_vm "apt-get -y upgrade"

    echo "Instalaciones en curso (60%)"
    run_in_vm "apt-get -y install curl"
    run_in_vm "apt-get -y install wget"

    echo "Instalacion en curso (70%)"
    run_in_vm "apt-get -y install neofetch"

    echo "Instalacion en curso (80%)"
    run_in_vm "curl -o /bin/systemctl https://raw.githubusercontent.com/gdraheim/docker-systemctl-replacement/master/files/docker/systemctl3.py"

    echo "Instalacion en curso (90%)"
    run_in_vm "chmod +x /bin/systemctl"

    echo "Instalación de los servicios SSH..."
    run_in_vm "apt-get -y install sudo"
    run_in_vm "chmod -R 777 /etc/default"
    run_in_vm "apt-get -y install dropbear"
    configure_dropbear
    run_in_vm "echo 'root:$SSH_PASSWORD' | chpasswd"

    print_banner
    start_ssh
    print_ssh_info "Su VPS se ha iniciado !"
    "$PROOT" -S . /bin/bash --login
fi
