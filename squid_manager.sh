#!/bin/bash

# Función para verificar si Squid está instalado
check_squid() {
    if ! command -v squid &> /dev/null; then
        echo "Squid no está instalado. Instalando..."
        sudo apt-get update
        sudo apt-get install squid -y
    fi
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
        echo "http_access allow all" | sudo tee -a /etc/squid/squid.conf
    fi
    sudo systemctl restart squid
    echo "Puerto $port abierto"
}

# Función para cerrar un puerto
close_port() {
    echo "Ingrese el puerto que desea cerrar:"
    read port
    sudo sed -i "/http_port $port/d" /etc/squid/squid.conf
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
    echo "1. Abrir puerto"
    echo "2. Cerrar puerto"
    echo "3. Ver puertos abiertos"
    echo "4. Actualizar script"
    echo "5. Desinstalar"
    echo "6. Salir"
    echo "Seleccione una opción:"
    read option

    case $option in
        1) check_squid && open_port ;;
        2) close_port ;;
        3) view_ports ;;
        4) update_script ;;
        5) uninstall ;;
        6) exit 0 ;;
        *) echo "Opción inválida" ;;
    esac

    echo "Presione Enter para continuar..."
    read
done
