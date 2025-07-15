#!/bin/bash

# Define cores para saída do terminal
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # Sem cor

# Função para imprimir mensagens de sucesso
print_success() {
    echo -e "${GREEN}[SUCESSO] $1${NC}"
}

# Função para imprimir mensagens de erro
print_error() {
    echo -e "${RED}[ERRO] $1${NC}" >&2
    exit 1
}

# Função para imprimir mensagens de aviso
print_warning() {
    echo -e "${YELLOW}[AVISO] $1${NC}"
}

# Função para imprimir mensagens de progresso
print_info() {
    echo -e "${NC}[INFO] $1${NC}"
}

# --- 1. Verificar privilégios de root ---
if [[ $EUID -ne 0 ]]; then
   print_error "Este script deve ser executado como root. Por favor, use 'sudo ./setup_server.sh'."
fi
print_success "Privilégios de root verificados."

# --- 2. Solicitar entrada do usuário e opções de serviço ---
print_info "Solicitando informações para a configuração do servidor..."

# Opção de usuário do sistema
CREATE_NEW_USER="no"
# Redireciona a entrada do read para /dev/tty para garantir que leia do terminal
read -p "Deseja criar um NOVO usuário do sistema? (s/n) [s]: " CREATE_NEW_USER_CHOICE < /dev/tty
CREATE_NEW_USER_CHOICE=${CREATE_NEW_USER_CHOICE:-s} # Default to 's'
if [[ "$CREATE_NEW_USER_CHOICE" =~ ^[Ss]$ ]]; then
    CREATE_NEW_USER="yes"
    read -p "Digite o nome de usuário do sistema a ser criado (ex: django_user): " USERNAME < /dev/tty
    if [[ -z "$USERNAME" ]]; then
        print_error "Nome de usuário não pode ser vazio."
    fi
    read -s -p "Digite a senha para o usuário '$USERNAME': " PASSWORD < /dev/tty
    echo # Adiciona uma nova linha após a entrada da senha silenciosa
    if [[ -z "$PASSWORD" ]]; then
        print_error "Senha não pode ser vazia."
    fi
else
    read -p "Digite o nome de usuário do sistema EXISTENTE a ser usado (ex: seu_usuario): " USERNAME < /dev/tty
    if [[ -z "$USERNAME" ]]; then
        print_error "Nome de usuário existente não pode ser vazio."
    fi
    if ! id "$USERNAME" &>/dev/null; then
        print_error "O usuário '$USERNAME' não existe no sistema. Por favor, crie-o ou escolha 's' para criar um novo."
    fi
    print_warning "Usando o usuário existente: '$USERNAME'. Certifique-se de que ele tenha as permissões necessárias."
fi

read -p "Digite o nome do seu projeto (ex: meuprojeto): " DJANGO_PROJECT_NAME < /dev/tty
if [[ -z "$DJANGO_PROJECT_NAME" ]]; then
    print_error "Nome do projeto não pode ser vazio."
fi

read -p "Digite o caminho de instalação base (ex: /opt, /var/www): " BASE_INSTALL_PATH < /dev/tty
if [[ -z "$BASE_INSTALL_PATH" ]]; then
    print_error "Caminho de instalação base não pode ser vazio."
fi

PROJECT_PATH="$BASE_INSTALL_PATH/$DJANGO_PROJECT_NAME"

# Opções de serviços
INSTALL_NGINX="no"
read -p "Deseja instalar e configurar Nginx? (s/n) [s]: " INSTALL_NGINX_CHOICE < /dev/tty
INSTALL_NGINX_CHOICE=${INSTALL_NGINX_CHOICE:-s}
if [[ "$INSTALL_NGINX_CHOICE" =~ ^[Ss]$ ]]; then INSTALL_NGINX="yes"; fi

INSTALL_VSFTPD="no"
read -p "Deseja instalar e configurar VSFTPD (FTP seguro)? (s/n) [s]: " INSTALL_VSFTPD_CHOICE < /dev/tty
INSTALL_VSFTPD_CHOICE=${INSTALL_VSFTPD_CHOICE:-s}
if [[ "$INSTALL_VSFTPD_CHOICE" =~ ^[Ss]$ ]]; then INSTALL_VSFTPD="yes"; fi

INSTALL_POSTGRESQL="no"
read -p "Deseja instalar e configurar PostgreSQL? (s/n) [s]: " INSTALL_POSTGRESQL_CHOICE < /dev/tty
INSTALL_POSTGRESQL_CHOICE=${INSTALL_POSTGRESQL_CHOICE:-s}
if [[ "$INSTALL_POSTGRESQL_CHOICE" =~ ^[Ss]$ ]]; then INSTALL_POSTGRESQL="yes"; fi

INSTALL_MARIADB="no"
read -p "Deseja instalar e configurar MariaDB? (s/n) [n]: " INSTALL_MARIADB_CHOICE < /dev/tty
INSTALL_MARIADB_CHOICE=${INSTALL_MARIADB_CHOICE:-n}
if [[ "$INSTALL_MARIADB_CHOICE" =~ ^[Ss]$ ]]; then INSTALL_MARIADB="yes"; fi

INSTALL_REDIS="no"
read -p "Deseja instalar e configurar Redis? (s/n) [s]: " INSTALL_REDIS_CHOICE < /dev/tty
INSTALL_REDIS_CHOICE=${INSTALL_REDIS_CHOICE:-s}
if [[ "$INSTALL_REDIS_CHOICE" =~ ^[Ss]$ ]]; then INSTALL_REDIS="yes"; fi

INSTALL_CELERY="no"
read -p "Deseja instalar e configurar Celery? (s/n) [s]: " INSTALL_CELERY_CHOICE < /dev/tty
INSTALL_CELERY_CHOICE=${INSTALL_CELERY_CHOICE:-s}
if [[ "$INSTALL_CELERY_CHOICE" =~ ^[Ss]$ ]]; then INSTALL_CELERY="yes"; fi


print_info "Informações coletadas:"
print_info "  Usuário do Sistema: $USERNAME (Novo: $CREATE_NEW_USER)"
print_info "  Nome do Projeto: $DJANGO_PROJECT_NAME"
print_info "  Caminho do Projeto: $PROJECT_PATH"
print_info "  Nginx: $INSTALL_NGINX"
print_info "  VSFTPD: $INSTALL_VSFTPD"
print_info "  PostgreSQL: $INSTALL_POSTGRESQL"
print_info "  MariaDB: $INSTALL_MARIADB"
print_info "  Redis: $INSTALL_REDIS"
print_info "  Celery: $INSTALL_CELERY"
echo

# --- 3. Atualizar pacotes e instalar dependências ---
print_info "Atualizando a lista de pacotes e fazendo upgrade..."
apt update -y || print_error "Falha ao atualizar a lista de pacotes."
apt upgrade -y || print_error "Falha ao fazer upgrade dos pacotes."
print_success "Lista de pacotes atualizada e upgrade concluído."

print_info "Instalando pacotes essenciais..."
PACKAGES="ufw curl git build-essential software-properties-common python3 python3-pip python3-venv"

if [[ "$INSTALL_NGINX" == "yes" ]]; then PACKAGES+=" nginx"; fi
if [[ "$INSTALL_VSFTPD" == "yes" ]]; then PACKAGES+=" vsftpd"; fi
if [[ "$INSTALL_POSTGRESQL" == "yes" ]]; then PACKAGES+=" postgresql postgresql-contrib libpq-dev"; fi
if [[ "$INSTALL_MARIADB" == "yes" ]]; then PACKAGES+=" mariadb-server"; fi
if [[ "$INSTALL_REDIS" == "yes" ]]; then PACKAGES+=" redis-server"; fi
# Celery não instala um pacote de sistema, mas depende do Python e Redis

for PKG in $PACKAGES; do
    print_info "Instalando $PKG..."
    apt install -y "$PKG" || print_error "Falha ao instalar o pacote: $PKG"
    print_success "$PKG instalado."
done
print_success "Todos os pacotes essenciais instalados."

# --- 4. Criar e configurar o usuário fornecido ---
if [[ "$CREATE_NEW_USER" == "yes" ]]; then
    print_info "Criando e configurando o usuário '$USERNAME'..."
    if id "$USERNAME" &>/dev/null; then
        print_warning "Usuário '$USERNAME' já existe. Pulando a criação do usuário."
    else
        adduser --gecos "" --disabled-password "$USERNAME" || print_error "Falha ao criar o usuário '$USERNAME'."
        echo "$USERNAME:$PASSWORD" | chpasswd || print_error "Falha ao definir a senha para o usuário '$USERNAME'."
        print_success "Usuário '$USERNAME' criado e senha definida."
    fi
    usermod -aG sudo "$USERNAME" || print_error "Falha ao adicionar o usuário '$USERNAME' ao grupo sudo."
    print_success "Usuário '$USERNAME' adicionado ao grupo sudo."
else
    print_info "Usando o usuário existente '$USERNAME'."
    usermod -aG sudo "$USERNAME" || print_error "Falha ao adicionar o usuário existente '$USERNAME' ao grupo sudo."
    print_success "Usuário existente '$USERNAME' adicionado ao grupo sudo (se ainda não estivesse)."
fi


# --- 5. Criar pasta do projeto com permissões adequadas ---
print_info "Criando pasta do projeto em '$PROJECT_PATH'..."
mkdir -p "$PROJECT_PATH" || print_error "Falha ao criar o diretório do projeto: $PROJECT_PATH"
chown -R "$USERNAME":"$USERNAME" "$PROJECT_PATH" || print_error "Falha ao definir o proprietário do diretório do projeto."
chmod -R 755 "$PROJECT_PATH" || print_error "Falha ao definir permissões para o diretório do projeto."
print_success "Pasta do projeto criada e permissões configuradas."

# --- 6. Criar e ativar ambiente virtual Python ---
print_info "Criando ambiente virtual Python para o projeto..."
# Mudar para o diretório do projeto para criar o venv lá dentro
(cd "$PROJECT_PATH" && sudo -u "$USERNAME" python3 -m venv venv) || print_error "Falha ao criar o ambiente virtual."
print_success "Ambiente virtual criado em '$PROJECT_PATH/venv'."

print_info "Atualizando pip e wheel no ambiente virtual..."
sudo -u "$USERNAME" "$PROJECT_PATH/venv/bin/pip" install --upgrade pip wheel || print_error "Falha ao atualizar pip/wheel no ambiente virtual."
print_success "Pip e wheel atualizados no ambiente virtual."

# --- 7. Configurar UFW ---
print_info "Configurando UFW (Uncomplicated Firewall)..."

ufw allow 22/tcp comment 'SSH' || print_error "Falha ao permitir porta SSH."
ufw allow 80/tcp comment 'HTTP' || print_error "Falha ao permitir porta HTTP."
ufw allow 443/tcp comment 'HTTPS' || print_error "Falha ao permitir porta HTTPS."

if [[ "$INSTALL_VSFTPD" == "yes" ]]; then
    ufw allow 20/tcp comment 'FTP Data' || print_error "Falha ao permitir porta FTP Data."
    ufw allow 21/tcp comment 'FTP Control' || print_error "Falha ao permitir porta FTP Control."
    ufw allow 40000/tcp comment 'FTP Passive Port' || print_error "Falha ao permitir porta passiva FTP."
fi
if [[ "$INSTALL_POSTGRESQL" == "yes" ]]; then
    ufw allow 5432/tcp comment 'PostgreSQL' || print_error "Falha ao permitir porta PostgreSQL."
fi
if [[ "$INSTALL_MARIADB" == "yes" ]]; then
    ufw allow 3306/tcp comment 'MariaDB' || print_error "Falha ao permitir porta MariaDB."
fi
if [[ "$INSTALL_REDIS" == "yes" ]]; then
    ufw allow 6379/tcp comment 'Redis' || print_error "Falha ao permitir porta Redis."
fi

print_info "Ativando UFW (será forçado para evitar prompt interativo)..."
ufw --force enable || print_error "Falha ao ativar UFW."
print_success "UFW configurado e ativado."
ufw status verbose

# --- 8. Configurar FTP seguro usando vsftpd ---
if [[ "$INSTALL_VSFTPD" == "yes" ]]; then
    print_info "Configurando VSFTPD para acesso seguro..."

    # Fazer backup da configuração original
    if [[ -f "/etc/vsftpd.conf" ]]; then
        mv /etc/vsftpd.conf /etc/vsftpd.conf.bak || print_error "Falha ao fazer backup de vsftpd.conf."
        print_success "Backup de /etc/vsftpd.conf criado em /etc/vsftpd.conf.bak."
    fi

    # Criar nova configuração vsftpd.conf
    tee /etc/vsftpd.conf > /dev/null <<EOF
listen=NO
listen_ipv6=YES
anonymous_enable=NO
local_enable=YES
write_enable=YES
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES
chroot_local_user=YES
allow_writeable_chroot=YES
secure_chroot_dir=/var/run/vsftpd/empty
pam_service_name=vsftpd
rsa_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem
rsa_private_key_file=/etc/ssl/private/ssl-cert-snakeoil.key
ssl_enable=NO # Desabilitado por padrão para simplificar. Habilite manualmente com certificados válidos.
pasv_enable=YES
pasv_min_port=40000
pasv_max_port=40000
user_sub_token=$USERNAME
local_root=$PROJECT_PATH
userlist_enable=YES
userlist_deny=NO # Se NO, os usuários na userlist SÃO permitidos.
EOF
    print_success "Configuração básica de vsftpd.conf criada."

    # Criar o diretório secure_chroot_dir se não existir
    mkdir -p /var/run/vsftpd/empty || print_error "Falha ao criar /var/run/vsftpd/empty."
    chmod 755 /var/run/vsftpd/empty || print_error "Falha ao definir permissões para /var/run/vsftpd/empty."

    # Adicionar o usuário à lista de usuários permitidos no FTP
    echo "$USERNAME" | tee -a /etc/vsftpd.userlist > /dev/null || print_error "Falha ao adicionar usuário à vsftpd.userlist."
    print_success "Usuário '$USERNAME' adicionado à lista de usuários FTP permitidos."

    print_info "Reiniciando o serviço vsftpd para aplicar as configurações..."
    systemctl restart vsftpd || print_error "Falha ao reiniciar o serviço vsftpd."
    print_success "VSFTPD configurado e reiniciado."
fi

# --- 9. Configurar PostgreSQL ---
if [[ "$INSTALL_POSTGRESQL" == "yes" ]]; then
    print_info "Configurando PostgreSQL..."
    CREATE_DB_USER="no"
    read -p "Deseja criar um USUÁRIO de banco de dados PostgreSQL para '$USERNAME'? (s/n) [s]: " CREATE_DB_USER_CHOICE < /dev/tty
    CREATE_DB_USER_CHOICE=${CREATE_DB_USER_CHOICE:-s}
    if [[ "$CREATE_DB_USER_CHOICE" =~ ^[Ss]$ ]]; then
        CREATE_DB_USER="yes"
        read -s -p "Digite a senha para o usuário PostgreSQL '$USERNAME': " PG_PASSWORD < /dev/tty
        echo
        if [[ -z "$PG_PASSWORD" ]]; then
            print_error "Senha do PostgreSQL não pode ser vazia."
        fi

        print_info "Criando usuário PostgreSQL '$USERNAME'..."
        sudo -i -u postgres psql -c "CREATE USER $USERNAME WITH PASSWORD '$PG_PASSWORD';" || print_error "Falha ao criar usuário PostgreSQL."
        print_success "Usuário PostgreSQL '$USERNAME' criado."

        CREATE_DB="no"
        read -p "Deseja criar um BANCO DE DADOS PostgreSQL '$DJANGO_PROJECT_NAME' para '$USERNAME'? (s/n) [s]: " CREATE_DB_CHOICE < /dev/tty
        CREATE_DB_CHOICE=${CREATE_DB_CHOICE:-s}
        if [[ "$CREATE_DB_CHOICE" =~ ^[Ss]$ ]]; then
            CREATE_DB="yes"
            print_info "Criando banco de dados PostgreSQL '$DJANGO_PROJECT_NAME'..."
            sudo -i -u postgres psql -c "CREATE DATABASE $DJANGO_PROJECT_NAME OWNER $USERNAME;" || print_error "Falha ao criar banco de dados PostgreSQL."
            print_success "Banco de dados PostgreSQL '$DJANGO_PROJECT_NAME' criado."
        fi
    fi
    print_success "PostgreSQL configurado."
fi

# --- 10. Configurar MariaDB ---
if [[ "$INSTALL_MARIADB" == "yes" ]]; then
    print_info "Configurando MariaDB..."
    # Executar o script de segurança inicial do MariaDB (opcional, mas recomendado)
    print_warning "Recomenda-se executar 'sudo mysql_secure_installation' manualmente para MariaDB."

    CREATE_DB_USER_MARIADB="no"
    read -p "Deseja criar um USUÁRIO de banco de dados MariaDB para '$USERNAME'? (s/n) [s]: " CREATE_DB_USER_MARIADB_CHOICE < /dev/tty
    CREATE_DB_USER_MARIADB_CHOICE=${CREATE_DB_USER_MARIADB_CHOICE:-s}
    if [[ "$CREATE_DB_USER_MARIADB_CHOICE" =~ ^[Ss]$ ]]; then
        CREATE_DB_USER_MARIADB="yes"
        read -s -p "Digite a senha para o usuário MariaDB '$USERNAME': " DB_PASSWORD_MARIADB < /dev/tty
        echo
        if [[ -z "$DB_PASSWORD_MARIADB" ]]; then
            print_error "Senha do MariaDB não pode ser vazia."
        fi

        DB_HOST_ACCESS="localhost"
        read -p "O usuário MariaDB '$USERNAME' terá acesso de qual host? (localhost ou %) [localhost]: " DB_HOST_ACCESS_CHOICE < /dev/tty
        DB_HOST_ACCESS_CHOICE=${DB_HOST_ACCESS_CHOICE:-localhost}
        if [[ "$DB_HOST_ACCESS_CHOICE" =~ ^%$ ]]; then
            DB_HOST_ACCESS="%"
            print_warning "Permitir acesso de '%' é menos seguro. Use com cautela."
        fi

        print_info "Criando usuário MariaDB '$USERNAME'@'$DB_HOST_ACCESS'..."
        mysql -u root -p -e "CREATE USER '$USERNAME'@'$DB_HOST_ACCESS' IDENTIFIED BY '$DB_PASSWORD_MARIADB';" || print_error "Falha ao criar usuário MariaDB."
        print_success "Usuário MariaDB '$USERNAME'@'$DB_HOST_ACCESS' criado."

        CREATE_DB_MARIADB="no"
        read -p "Deseja criar um BANCO DE DADOS MariaDB '$DJANGO_PROJECT_NAME' para '$USERNAME'? (s/n) [s]: " CREATE_DB_MARIADB_CHOICE < /dev/tty
        CREATE_DB_MARIADB_CHOICE=${CREATE_DB_MARIADB_CHOICE:-s}
        if [[ "$CREATE_DB_MARIADB_CHOICE" =~ ^[Ss]$ ]]; then
            CREATE_DB_MARIADB="yes"
            print_info "Criando banco de dados MariaDB '$DJANGO_PROJECT_NAME'..."
            mysql -u root -p -e "CREATE DATABASE $DJANGO_PROJECT_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" || print_error "Falha ao criar banco de dados MariaDB."
            print_success "Banco de dados MariaDB '$DJANGO_PROJECT_NAME' criado."

            print_info "Concedendo privilégios ao usuário '$USERNAME' no banco de dados '$DJANGO_PROJECT_NAME'..."
            mysql -u root -p -e "GRANT ALL PRIVILEGES ON $DJANGO_PROJECT_NAME.* TO '$USERNAME'@'$DB_HOST_ACCESS';" || print_error "Falha ao conceder privilégios MariaDB."
            mysql -u root -p -e "FLUSH PRIVILEGES;" || print_error "Falha ao recarregar privilégios MariaDB."
            print_success "Privilégios concedidos e recarregados para MariaDB."
        fi
    fi
    print_success "MariaDB configurado."
fi

# --- 11. Configurar Redis ---
if [[ "$INSTALL_REDIS" == "yes" ]]; then
    print_info "Configurando Redis..."
    # Configuração básica do Redis (pode ser aprimorada para segurança)
    # Por padrão, o Redis escuta em localhost (127.0.0.1)
    # Para acesso externo, edite /etc/redis/redis.conf e configure 'bind' e 'protected-mode no'
    print_success "Redis instalado. O Redis está configurado para escutar apenas em 127.0.0.1 por padrão (seguro)."
    print_info "Para acesso remoto ao Redis, edite '/etc/redis/redis.conf' e configure 'bind' e 'protected-mode no'."
    print_info "Lembre-se de reiniciar o serviço Redis após as alterações: 'sudo systemctl restart redis-server'."
fi

# --- 12. Iniciar e habilitar todos os serviços instalados ---
print_info "Iniciando e habilitando serviços essenciais..."

SERVICES_TO_START=()
if [[ "$INSTALL_NGINX" == "yes" ]]; then SERVICES_TO_START+=("nginx"); fi
if [[ "$INSTALL_VSFTPD" == "yes" ]]; then SERVICES_TO_START+=("vsftpd"); fi
if [[ "$INSTALL_POSTGRESQL" == "yes" ]]; then SERVICES_TO_START+=("postgresql"); fi
if [[ "$INSTALL_MARIADB" == "yes" ]]; then SERVICES_TO_START+=("mariadb"); fi
if [[ "$INSTALL_REDIS" == "yes" ]]; then SERVICES_TO_START+=("redis-server"); fi
# Celery não é um serviço de sistema que se inicia diretamente como os outros.
# Ele será configurado como um serviço systemd nas instruções pós-instalação.

for SVC in "${SERVICES_TO_START[@]}"; do
    print_info "Iniciando e habilitando $SVC..."
    systemctl start "$SVC" || print_error "Falha ao iniciar o serviço: $SVC"
    systemctl enable "$SVC" || print_error "Falha ao habilitar o serviço: $SVC"
    print_success "$SVC iniciado e habilitado."
done
print_success "Todos os serviços selecionados iniciados e habilitados."

# --- 13. Printar informações finais e instruções pós-instalação ---
echo -e "\n${YELLOW}====================================================${NC}"
echo -e "${YELLOW}           Configuração do Servidor Concluída!          ${NC}"
echo -e "${YELLOW}====================================================${NC}\n"

print_info "Detalhes da Instalação:"
print_info "  Caminho do Projeto: $PROJECT_PATH"
print_info "  Usuário do Sistema: $USERNAME"
print_info "  Ambiente Virtual: $PROJECT_PATH/venv"

echo -e "\n${YELLOW}Status dos Serviços:${NC}"
if [[ "$INSTALL_NGINX" == "yes" ]]; then systemctl status nginx --no-pager | grep "Active:"; fi
if [[ "$INSTALL_VSFTPD" == "yes" ]]; then systemctl status vsftpd --no-pager | grep "Active:"; fi
if [[ "$INSTALL_POSTGRESQL" == "yes" ]]; then systemctl status postgresql --no-pager | grep "Active:"; fi
if [[ "$INSTALL_MARIADB" == "yes" ]]; then systemctl status mariadb --no-pager | grep "Active:"; fi
if [[ "$INSTALL_REDIS" == "yes" ]]; then systemctl status redis-server --no-pager | grep "Active:"; fi
ufw status verbose | grep "Status:"

echo -e "\n${YELLOW}Instruções Pós-Instalação (Passos Manuais Essenciais):${NC}"
echo "1.  **Acessar o Servidor como o Usuário Configurado:**"
echo "    Você pode se conectar via SSH com o usuário '$USERNAME' e a senha que você definiu (se criou um novo)."
echo "    Ex: 'ssh $USERNAME@seu_ip_do_servidor'"

echo "2.  **Configuração do Projeto (Django, etc.):**"
echo "    a.  Acesse o diretório do projeto: 'cd $PROJECT_PATH'"
echo "    b.  Ative o ambiente virtual: 'source venv/bin/activate'"
echo "    c.  Instale suas dependências Python (Django, Gunicorn, psycopg2-binary, mysqlclient, redis, celery, etc.):"
echo "        'pip install django gunicorn'"
if [[ "$INSTALL_POSTGRESQL" == "yes" ]]; then echo "        'pip install psycopg2-binary'"; fi
if [[ "$INSTALL_MARIADB" == "yes" ]]; then echo "        'pip install mysqlclient'"; fi
if [[ "$INSTALL_REDIS" == "yes" ]]; then echo "        'pip install redis'"; fi
if [[ "$INSTALL_CELERY" == "yes" ]]; then echo "        'pip install celery'"; fi
echo "    d.  Crie seu projeto (se ainda não o fez): 'django-admin startproject $DJANGO_PROJECT_NAME .'"
echo "        (Se você já tem um projeto, copie-o para '$PROJECT_PATH' via FTP/SCP)"
echo "    e.  Configure 'settings.py' (DATABASES, ALLOWED_HOSTS, STATIC_ROOT, etc.)."
echo "    f.  Colete arquivos estáticos: 'python manage.py collectstatic'"
echo "    g.  Desative o ambiente virtual: 'deactivate'"

if [[ "$INSTALL_POSTGRESQL" == "yes" ]]; then
    echo "3.  **Configuração do Banco de Dados (PostgreSQL):**"
    if [[ "$CREATE_DB_USER" == "yes" && "$CREATE_DB" == "yes" ]]; then
        echo "    O usuário '$USERNAME' e o banco de dados '$DJANGO_PROJECT_NAME' já foram criados."
        echo "    Lembre-se de configurar as credenciais em seu 'settings.py'."
    else
        echo "    a.  Acesse o shell do PostgreSQL como usuário 'postgres': 'sudo -i -u postgres psql'"
        echo "    b.  Crie um usuário de banco de dados: 'CREATE USER seu_usuario_db WITH PASSWORD 'sua_senha_db';'"
        echo "    c.  Crie um banco de dados para seu projeto: 'CREATE DATABASE seu_nome_db OWNER seu_usuario_db;'"
        echo "    d.  Saia do psql: '\q'"
        echo "    e.  Lembre-se de configurar essas credenciais em seu 'settings.py'."
    fi
fi

if [[ "$INSTALL_MARIADB" == "yes" ]]; then
    echo "4.  **Configuração do Banco de Dados (MariaDB):**"
    echo "    a.  Recomenda-se executar o script de segurança inicial: 'sudo mysql_secure_installation'"
    if [[ "$CREATE_DB_USER_MARIADB" == "yes" && "$CREATE_DB_MARIADB" == "yes" ]]; then
        echo "    O usuário '$USERNAME'@'$DB_HOST_ACCESS' e o banco de dados '$DJANGO_PROJECT_NAME' já foram criados."
        echo "    Lembre-se de configurar as credenciais em seu 'settings.py'."
    else
        echo "    b.  Acesse o shell do MariaDB como root: 'sudo mysql -u root -p'"
        echo "    c.  Crie um banco de dados: 'CREATE DATABASE seu_nome_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;'"
        echo "    d.  Crie um usuário e conceda permissões: 'CREATE USER 'seu_usuario_db'@'seu_host' IDENTIFIED BY 'sua_senha_db';'"
        echo "        'GRANT ALL PRIVILEGES ON seu_nome_db.* TO 'seu_usuario_db'@'seu_host';'"
        echo "        'FLUSH PRIVILEGES;'"
        echo "    e.  Saia do mysql: 'exit;'"
        echo "    f.  Lembre-se de configurar essas credenciais em seu 'settings.py'."
    fi
fi

if [[ "$INSTALL_REDIS" == "yes" ]]; then
    echo "5.  **Configuração do Redis:**"
    echo "    O Redis está instalado e rodando. Para acesso externo, edite '/etc/redis/redis.conf' e configure 'bind' e 'protected-mode no'."
    echo "    Reinicie o serviço após as alterações: 'sudo systemctl restart redis-server'."
    echo "    Para uso com Celery, configure o broker em seu 'settings.py':"
    echo "    'CELERY_BROKER_URL = 'redis://localhost:6379/0''"
fi

if [[ "$INSTALL_CELERY" == "yes" ]]; then
    echo "6.  **Configuração do Celery (Serviço de Fila de Tarefas):**"
    echo "    a.  Certifique-se de que o Redis está configurado como broker em seu 'settings.py'."
    echo "    b.  Crie um arquivo de serviço Celery em '/etc/systemd/system/celery-$DJANGO_PROJECT_NAME.service':"
    echo "        [Unit]"
    echo "        Description=Celery Worker for $DJANGO_PROJECT_NAME"
    echo "        After=network.target redis-server.service"
    echo ""
    echo "        [Service]"
    echo "        User=$USERNAME"
    echo "        Group=www-data"
    echo "        WorkingDirectory=$PROJECT_PATH"
    echo "        Environment=\"PATH=$PROJECT_PATH/venv/bin\""
    echo "        ExecStart=$PROJECT_PATH/venv/bin/celery -A $DJANGO_PROJECT_NAME worker -l info"
    echo "        Restart=on-failure"
    echo ""
    echo "        [Install]"
    echo "        WantedBy=multi-user.target"
    echo "    c.  Recarregue o systemd: 'sudo systemctl daemon-reload'"
    echo "    d.  Habilite e inicie o Celery: 'sudo systemctl enable celery-$DJANGO_PROJECT_NAME && sudo systemctl start celery-$DJANGO_PROJECT_NAME'"
    echo "    e.  Para executar o Celery Beat (agendador), crie outro serviço similar, mas com 'ExecStart=$PROJECT_PATH/venv/bin/celery -A $DJANGO_PROJECT_NAME beat -l info --scheduler django_celery_beat.schedulers:DatabaseScheduler'"
fi


if [[ "$INSTALL_NGINX" == "yes" ]]; then
    echo "7.  **Configuração do Gunicorn (Serviço de Aplicação):**"
    echo "    a.  Crie um arquivo de serviço Gunicorn em '/etc/systemd/system/$DJANGO_PROJECT_NAME.service':"
    echo "        [Unit]"
    echo "        Description=Gunicorn instance for $DJANGO_PROJECT_NAME"
    echo "        After=network.target"
    echo ""
    echo "        [Service]"
    echo "        User=$USERNAME"
    echo "        Group=www-data"
    echo "        WorkingDirectory=$PROJECT_PATH"
    echo "        Environment=\"PATH=$PROJECT_PATH/venv/bin\""
    echo "        ExecStart=$PROJECT_PATH/venv/bin/gunicorn --workers 3 --bind unix:$PROJECT_PATH/$DJANGO_PROJECT_NAME.sock $DJANGO_PROJECT_NAME.wsgi:application"
    echo ""
    echo "        [Install]"
    echo "        WantedBy=multi-user.target"
    echo "    b.  Recarregue o systemd: 'sudo systemctl daemon-reload'"
    echo "    c.  Habilite e inicie o Gunicorn: 'sudo systemctl enable $DJANGO_PROJECT_NAME && sudo systemctl start $DJANGO_PROJECT_NAME'"

    echo "8.  **Configuração do Nginx (Servidor Web):**"
    echo "    a.  Crie um arquivo de configuração Nginx em '/etc/nginx/sites-available/$DJANGO_PROJECT_NAME':"
    echo "        server {"
    echo "            listen 80;"
    echo "            server_name seu_dominio.com seu_ip_do_servidor;"
    echo ""
    echo "            location = /favicon.ico { access_log off; log_not_found off; }"
    echo "            location /static/ {"
    echo "                root $PROJECT_PATH;"
    echo "            }"
    echo ""
    echo "            location / {"
    echo "                include proxy_params;"
    echo "                proxy_pass http://unix:$PROJECT_PATH/$DJANGO_PROJECT_NAME.sock;"
    echo "            }"
    echo "        }"
    echo "    b.  Crie um link simbólico para 'sites-enabled': 'sudo ln -s /etc/nginx/sites-available/$DJANGO_PROJECT_NAME /etc/nginx/sites-enabled/'"
    echo "    c.  Teste a configuração do Nginx: 'sudo nginx -t'"
    echo "    d.  Reinicie o Nginx: 'sudo systemctl restart nginx'"

    echo "9.  **Configuração SSL com Certbot (Opcional, mas Recomendado):**"
    echo "    a.  Instale Certbot: 'sudo snap install --classic certbot'"
    echo "    b.  Obtenha e configure SSL: 'sudo certbot --nginx -d seu_dominio.com'"
    echo "    c.  Siga as instruções para configurar seu certificado SSL."
fi

echo -e "\n${YELLOW}Lembre-se de substituir 'seu_dominio.com', 'seu_ip_do_servidor', 'sua_senha_db', 'seu_usuario_db' e 'seu_nome_db' pelos seus valores reais.${NC}"
echo -e "${YELLOW}====================================================${NC}\n"

print_success "Script de configuração do servidor concluído com sucesso!"
