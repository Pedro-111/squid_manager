#!/bin/bash

# Función para verificar si Squid está instalado
check_squid() {
    if ! command -v squid &> /dev/null; then
        echo "Squid no está instalado. Instalando..."
        sudo apt-get update
        sudo apt-get install squid -y
    fi
}

# Función para configurar Squid
configure_squid() {
    sudo cp /etc/squid/squid.conf /etc/squid/squid.conf.bak
    sudo tee /etc/squid/squid.conf > /dev/null <<EOT
acl localnet src 192.168.0.0/16
acl SSL_ports port 443 8080
acl Safe_ports port 80          # http
acl Safe_ports port 21          # ftp
acl Safe_ports port 443         # https
acl Safe_ports port 70          # gopher
acl Safe_ports port 210         # wais
acl Safe_ports port 1025-65535  # unregistered ports
acl Safe_ports port 280         # http-mgmt
acl Safe_ports port 488         # gss-http
acl Safe_ports port 591         # filemaker
acl Safe_ports port 777         # multiling http
acl Safe_ports port 22          # ssh
acl Safe_ports port 8080        # alternative http
acl CONNECT method CONNECT

http_access deny !Safe_ports
http_access deny CONNECT !SSL_ports
http_access allow localhost manager
http_access deny manager
http_access allow localnet
http_access allow localhost
http_access deny all

http_port 3128
http_port 8080
http_port 22

# Allow SSH tunneling
always_direct allow SSL_ports

coredump_dir /var/spool/squid

refresh_pattern ^ftp:           1440    20%     10080
refresh_pattern ^gopher:        1440    0%      1440
refresh_pattern -i (/cgi-bin/|\?) 0     0%      0
refresh_pattern .               0       20%     4320
EOT

    sudo systemctl restart squid
    echo "Squid configurado y reiniciado"
}

# Función para abrir un puerto
open_port() {
    echo "Ingrese el puerto que desea abrir:"
    read port
    if grep -q "http_port $port" /etc/squid/squid.conf; then
        echo "El puerto $port ya está abierto."
        return
    fi
    echo "¿Desea configurar autenticación? (s/n)"
    read auth
    if [ "$auth" = "s" ]; then
        echo "Ingrese el nombre de usuario:"
        read username
        echo "Ingrese la contraseña:"
        read -s password
        echo "http_port $port" | sudo tee -a /etc/squid/squid.conf
        echo "auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/passwd" | sudo tee -a /etc/squid/squid.conf
        echo "acl authenticated proxy_auth REQUIRED" | sudo tee -a /etc/squid/squid.conf
        echo "http_access allow authenticated" | sudo tee -a /etc/squid/squid.conf
        sudo htpasswd -cb /etc/squid/passwd $username $password
    else
        echo "http_port $port" | sudo tee -a /etc/squid/squid.conf
    fi
    sudo sed -i "/acl Safe_ports port/a acl Safe_ports port $port" /etc/squid/squid.conf
    sudo sed -i "/acl SSL_ports port/s/$/ $port/" /etc/squid/squid.conf
    sudo systemctl restart squid
    echo "Puerto $port abierto y configurado como seguro"
}

# Función para cerrar un puerto
close_port() {
    echo "Ingrese el puerto que desea cerrar:"
    read port
    sudo sed -i "/http_port $port/d" /etc/squid/squid.conf
    sudo sed -i "/acl Safe_ports port $port/d" /etc/squid/squid.conf
    sudo sed -i "s/ $port//" /etc/squid/squid.conf
    sudo systemctl restart squid
    echo "Puerto $port cerrado"
}

# Función para ver puertos abiertos
view_ports() {
    echo "Puertos proxy abiertos:"
    echo "----------------------"
    echo "| Puerto | Autenticación |"
    echo "----------------------"
    grep "^http_port" /etc/squid/squid.conf | while read line; do
        port=$(echo $line | awk '{print $2}')
        if grep -q "auth_param.*basic.*ncsa_auth" /etc/squid/squid.conf; then
            auth="Sí"
        else
            auth="No"
        fi
        printf "| %-6s | %-13s |\n" "$port" "$auth"
    done
    echo "----------------------"
}

# Función para actualizar el script
update_script() {
    echo "Actualizando el script..."
    # Aquí puedes agregar la lógica para actualizar el script
    echo "Script actualizado"
}

# Función para desinstalar
uninstall() {
    echo "¿Desea desinstalar el servicio de proxy? (s/n)"
    read answer
    if [ "$answer" = "s" ]; then
        sudo apt-get remove squid -y
        sudo apt-get autoremove -y
        echo "Servicio de proxy desinstalado"
    fi
    
    echo "¿Desea desinstalar este script? (s/n)"
    read answer
    if [ "$answer" = "s" ]; then
        echo "Desinstalando el script..."
        # Aquí puedes agregar la lógica para eliminar el script
        echo "Script desinstalado"
        exit 0
    fi
}

# Menú principal
while true; do
    echo "==== Menú de Gestión de Squid ===="
    echo "1. Configurar Squid"
    echo "2. Abrir puerto"
    echo "3. Cerrar puerto"
    echo "4. Ver puertos abiertos"
    echo "5. Actualizar script"
    echo "6. Desinstalar"
    echo "7. Salir"
    echo "Seleccione una opción:"
    read option

    case $option in
        1) check_squid && configure_squid ;;
        2) open_port ;;
        3) close_port ;;
        4) view_ports ;;
        5) update_script ;;
        6) uninstall ;;
        7) exit 0 ;;
        *) echo "Opción inválida" ;;
    esac

    echo "Presione Enter para continuar..."
    read
done
