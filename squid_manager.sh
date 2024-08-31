#!/bin/bash

# Función para verificar si Squid está instalado
check_squid() {
    if ! command -v squid &> /dev/null; then
        echo "Squid no está instalado. Instalando..."
        sudo apt-get update
        sudo apt-get install squid -y
    fi
    if ! command -v htpasswd &> /dev/null; then
        echo "htpasswd no está instalado. Instalando..."
        sudo apt-get install apache2-utils -y
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

# Configuración de puertos
http_port 3128

# Configuraciones adicionales para resolver problemas de conexión
request_header_access Accept allow all
request_header_access Accept-Charset allow all
request_header_access Accept-Encoding allow all
request_header_access Accept-Language allow all
request_header_access Connection allow all
request_header_access Host allow all
request_header_access User-Agent allow all

# Aumentar el tiempo de espera para las conexiones
connect_timeout 1 minute
request_timeout 5 minutes

# Permitir conexiones SSL/TLS
ssl_bump server-first all
sslcrtd_program /usr/lib/squid/security_file_certgen -s /var/lib/ssl_db -M 4MB
sslcrtd_children 5

# Logging
access_log /var/log/squid/access.log squid
cache_log /var/log/squid/cache.log

# Configuración de caché
cache_mem 256 MB
maximum_object_size_in_memory 512 KB
maximum_object_size 64 MB
cache_dir ufs /var/spool/squid 1000 16 256

# Allow SSH tunneling
always_direct allow SSL_ports

coredump_dir /var/spool/squid

refresh_pattern ^ftp:           1440    20%     10080
refresh_pattern ^gopher:        1440    0%      1440
refresh_pattern -i (/cgi-bin/|\?) 0     0%      0
refresh_pattern .               0       20%     4320
EOT

    sudo systemctl stop squid
    sudo systemctl start squid
    sudo systemctl status squid
    echo "Squid configurado y reiniciado"
}
check_squid_status() {
    echo "Estado actual de Squid:"
    sudo systemctl status squid
    echo "Puertos actualmente en uso:"
    sudo netstat -tulpn | grep squid
}
# Función para abrir un puerto
open_port() {
    echo "Ingrese el puerto que desea abrir:"
    read port
    if netstat -tuln | grep ":$port " > /dev/null; then
        echo "El puerto $port ya está en uso por otro proceso. Por favor, elija otro puerto."
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
        if grep -q "auth_param.*basic.*ncsa_auth.*$port" /etc/squid/squid.conf; then
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


# Nueva función para verificar los logs de Squid
check_squid_logs() {
    echo "Últimas 20 líneas del log de acceso de Squid:"
    sudo tail -n 20 /var/log/squid/access.log
    
    echo -e "\nÚltimas 20 líneas del log de cache de Squid:"
    sudo tail -n 20 /var/log/squid/cache.log
}

# Nueva función para verificar la configuración de puertos
verify_port_config() {
    echo "Configuración actual de puertos en squid.conf:"
    grep "^http_port" /etc/squid/squid.conf
    
    echo -e "\nPuertos en uso por Squid:"
    sudo netstat -tlnp | grep squid
}

# Nueva función para reiniciar Squid
restart_squid() {
    echo "Reiniciando Squid..."
    sudo systemctl restart squid
    echo "Squid reiniciado. Verificando estado:"
    sudo systemctl status squid
}

# Nueva función para verificar permisos
check_permissions() {
    echo "Verificando permisos de archivos y directorios importantes:"
    ls -l /etc/squid/squid.conf
    ls -ld /var/spool/squid
    ls -ld /var/log/squid
}

# Actualizar el menú principal
while true; do
    echo "==== Menú de Gestión de Squid ===="
    echo "1. Configurar Squid"
    echo "2. Abrir puerto"
    echo "3. Cerrar puerto"
    echo "4. Ver puertos abiertos"
    echo "5. Actualizar script"
    echo "6. Desinstalar"
    echo "7. Verificar estado de Squid"
    echo "8. Verificar logs de Squid"
    echo "9. Verificar configuración de puertos"
    echo "10. Reiniciar Squid"
    echo "11. Verificar permisos"
    echo "12. Salir"
    echo "Seleccione una opción:"
    read option

    case $option in
        1) check_squid && configure_squid ;;
        2) open_port ;;
        3) close_port ;;
        4) view_ports ;;
        5) update_script ;;
        6) uninstall ;;
        7) check_squid_status ;;
        8) check_squid_logs ;;
        9) verify_port_config ;;
        10) restart_squid ;;
        11) check_permissions ;;
        12) exit 0 ;;
        *) echo "Opción inválida" ;;
    esac

    echo "Presione Enter para continuar..."
    read
done
