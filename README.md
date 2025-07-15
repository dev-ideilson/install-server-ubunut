# Script de Configuração Automatizada para Ubuntu Server

Este script Bash foi desenvolvido para automatizar a configuração inicial de um servidor Ubuntu Server (20.04 LTS ou superior), preparando-o para hospedar aplicações web, especialmente aquelas baseadas em Django. Ele oferece opções interativas para instalar e configurar serviços comuns, como servidores web, bancos de dados e ferramentas de fila de tarefas.

## Objetivo

O principal objetivo deste script é simplificar e padronizar o processo de setup de um novo servidor, reduzindo a necessidade de comandos manuais repetitivos e minimizando erros. Ele cuida de tarefas como:

- Atualização de pacotes do sistema.
- Instalação de dependências essenciais (Python, pip, venv, git, build-essential).
- Criação e configuração de um usuário de sistema dedicado para o projeto (ou uso de um existente).
- Criação da estrutura de diretórios do projeto com permissões adequadas.
- Configuração do firewall UFW para liberar portas de serviços.
- Instalação e configuração opcional de:
    - **Nginx**: Servidor web de alta performance.
    - **VSFTPD**: Servidor FTP seguro para transferência de arquivos.
    - **PostgreSQL**: Sistema de gerenciamento de banco de dados relacional.
    - **MariaDB**: Sistema de gerenciamento de banco de dados relacional (fork do MySQL).
    - **Redis**: Armazenamento de dados em memória, frequentemente usado como cache ou broker para filas de tarefas.
    - **Celery**: Sistema de fila de tarefas distribuídas para Python (depende do Redis como broker).

## Como Usar

### Pré-requisitos

- Um servidor Ubuntu Server (20.04 LTS ou superior) recém-instalado ou limpo.
- Acesso root ou um usuário com privilégios sudo.
- Conexão com a internet no servidor.

### Passos para Executar o Script

1. **Baixe o script para o seu servidor:**

     Você pode usar `curl` ou `wget` para baixar o script diretamente para o seu servidor. Por exemplo:

     ```sh
     curl -o setup_server.sh https://raw.githubusercontent.com/dev-ideilson/install-server-ubunut/main/setup_server.sh
     # Ou use wget:
     # wget https://raw.githubusercontent.com/dev-ideilson/install-server-ubunut/main/setup_server.sh
     ```

2. **Conceda permissões de execução:**

     ```sh
     chmod +x setup_server.sh
     ```

3. **Execute o script com privilégios de root:**

     ```sh
     sudo ./setup_server.sh
     ```

### Interação com o Script

O script irá guiá-lo através de uma série de perguntas:

- **Criação de Usuário do Sistema:** Você pode optar por criar um novo usuário dedicado para o seu projeto ou usar um usuário existente. Se for um novo usuário, será solicitada uma senha.
- **Nome do Projeto:** Um nome para o seu projeto (ex: `meuprojeto`). Isso será usado para nomes de diretórios e configurações.
- **Caminho de Instalação Base:** O diretório onde seu projeto será instalado (ex: `/opt`, `/var/www`).
- **Seleção de Serviços:** Para cada serviço (Nginx, VSFTPD, PostgreSQL, MariaDB, Redis, Celery), o script perguntará se você deseja instalá-lo e configurá-lo. Responda `s` para sim ou `n` para não.
- **Configuração de Banco de Dados (se selecionado):** Se você optar por instalar PostgreSQL ou MariaDB, o script perguntará se deseja criar um usuário de banco de dados e um banco de dados com o nome do seu projeto. Para MariaDB, você também poderá definir o host de acesso (`localhost` ou `%`).

## Serviços e Configurações Realizadas

O script automatiza a instalação e configuração básica dos seguintes componentes (baseado nas suas escolhas):

### Sistema

- Atualização de pacotes.
- Instalação de `ufw`, `curl`, `git`, `build-essential`, `software-properties-common`, `python3`, `python3-pip`, `python3-venv`.
- Criação/Configuração de usuário do sistema e adição ao grupo sudo.
- Criação de diretório do projeto (`<BASE_PATH>/<PROJECT_NAME>`) com permissões adequadas.
- Criação e atualização de ambiente virtual Python (venv) dentro do diretório do projeto.

### Rede/Segurança

- **UFW:** Configuração de regras para SSH (22), HTTP (80), HTTPS (443), FTP (20, 21, portas passivas 40000), PostgreSQL (5432), MariaDB (3306), Redis (6379). O firewall é ativado.

### FTP (se selecionado)

- **VSFTPD:** Configuração para acesso seguro (sem anônimo, chroot ativado para o diretório do projeto, portas passivas).

### Bancos de Dados (se selecionados)

- **PostgreSQL:** Instalação, e opcionalmente, criação de usuário e banco de dados.
- **MariaDB:** Instalação, e opcionalmente, criação de usuário e banco de dados com definição de host de acesso.

### Cache/Fila de Tarefas (se selecionado)

- **Redis:** Instalação e configuração padrão (escutando em localhost).

## Instruções Pós-Instalação (Passos Manuais Essenciais)

Após a execução bem-sucedida do script, você precisará seguir alguns passos manuais para finalizar a configuração do seu ambiente e implantar sua aplicação:

### 1. Acessar o Servidor

Conecte-se ao servidor via SSH usando o usuário configurado:

```sh
ssh seu_usuario@seu_ip_do_servidor
```

### 2. Configuração do Projeto Python (Django, Flask, etc.)

- Navegue até o diretório do seu projeto:  
    `cd /caminho/do/seu/projeto`
- Ative o ambiente virtual:  
    `source venv/bin/activate`
- Instale as dependências Python do seu projeto (ex: `pip install django gunicorn psycopg2-binary mysqlclient redis celery`).
- Se ainda não tiver um projeto, crie um:  
    `django-admin startproject seu_projeto .` (o `.` é importante para criar o projeto no diretório atual).
- Copie seu código-fonte para o diretório do projeto (`/caminho/do/seu/projeto`) via SCP, FTP (se VSFTPD configurado) ou Git.
- Configure o arquivo `settings.py` do seu projeto Django (ou equivalente para outras frameworks):
    - **DATABASES:** Configure as credenciais do banco de dados (PostgreSQL/MariaDB).
    - **ALLOWED_HOSTS:** Adicione o IP do seu servidor e/ou nome de domínio.
    - **STATIC_ROOT:** Defina o diretório para arquivos estáticos.
    - **CELERY_BROKER_URL:** Se estiver usando Celery e Redis, configure `redis://localhost:6379/0`.
- Colete arquivos estáticos:  
    `python manage.py collectstatic`
- Desative o ambiente virtual:  
    `deactivate`

### 3. Configuração do Banco de Dados (se aplicável)

#### PostgreSQL

Se você não criou o usuário e banco de dados via script, faça-o manualmente:

```sh
sudo -i -u postgres psql
CREATE USER seu_usuario_db WITH PASSWORD 'sua_senha_db';
CREATE DATABASE seu_nome_db OWNER seu_usuario_db;
\q
```

#### MariaDB

Se você não criou o usuário e banco de dados via script, faça-o manualmente. Recomenda-se executar `sudo mysql_secure_installation` primeiro.

```sh
sudo mysql -u root -p
CREATE DATABASE seu_nome_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'seu_usuario_db'@'seu_host' IDENTIFIED BY 'sua_senha_db';
GRANT ALL PRIVILEGES ON seu_nome_db.* TO 'seu_usuario_db'@'seu_host';
FLUSH PRIVILEGES;
exit;
```

### 4. Configuração do Redis (se aplicável)

O Redis está configurado para escutar apenas em `127.0.0.1` por padrão. Se precisar de acesso externo, edite `/etc/redis/redis.conf` e configure a diretiva `bind` e `protected-mode no`. Lembre-se de reiniciar o serviço:

```sh
sudo systemctl restart redis-server
```

### 5. Configuração do Celery (se aplicável)

Crie um arquivo de serviço systemd para o Celery worker em `/etc/systemd/system/celery-seu_projeto.service`:

```ini
[Unit]
Description=Celery Worker for seu_projeto
After=network.target redis-server.service

[Service]
User=seu_usuario
Group=www-data
WorkingDirectory=/caminho/do/seu/projeto
Environment="PATH=/caminho/do/seu/projeto/venv/bin"
ExecStart=/caminho/do/seu/projeto/venv/bin/celery -A seu_projeto worker -l info
Restart=on-failure

[Install]
WantedBy=multi-user.target
```

Recarregue o systemd:

```sh
sudo systemctl daemon-reload
```

Habilite e inicie o Celery:

```sh
sudo systemctl enable celery-seu_projeto && sudo systemctl start celery-seu_projeto
```

Para o Celery Beat (agendador), crie outro serviço similar, alterando `ExecStart` para:

```ini
ExecStart=/caminho/do/seu/projeto/venv/bin/celery -A seu_projeto beat -l info --scheduler django_celery_beat.schedulers:DatabaseScheduler
```

### 6. Configuração do Gunicorn (se Nginx selecionado)

Crie um arquivo de serviço systemd para o Gunicorn em `/etc/systemd/system/seu_projeto.service`:

```ini
[Unit]
Description=Gunicorn instance for seu_projeto
After=network.target

[Service]
User=seu_usuario
Group=www-data
WorkingDirectory=/caminho/do/seu/projeto
Environment="PATH=/caminho/do/seu/projeto/venv/bin"
ExecStart=/caminho/do/seu/projeto/venv/bin/gunicorn --workers 3 --bind unix:/caminho/do/seu/projeto/seu_projeto.sock seu_projeto.wsgi:application

[Install]
WantedBy=multi-user.target
```

Recarregue o systemd:

```sh
sudo systemctl daemon-reload
```

Habilite e inicie o Gunicorn:

```sh
sudo systemctl enable seu_projeto && sudo systemctl start seu_projeto
```

### 7. Configuração do Nginx (se selecionado)

Crie um arquivo de configuração Nginx em `/etc/nginx/sites-available/seu_projeto`:

```nginx
server {
        listen 80;
        server_name seu_dominio.com seu_ip_do_servidor;

        location = /favicon.ico { access_log off; log_not_found off; }
        location /static/ {
                root /caminho/do/seu/projeto;
        }

        location / {
                include proxy_params;
                proxy_pass http://unix:/caminho/do/seu/projeto/seu_projeto.sock;
        }
}
```

Crie um link simbólico para `sites-enabled`:

```sh
sudo ln -s /etc/nginx/sites-available/seu_projeto /etc/nginx/sites-enabled/
```

Teste a configuração do Nginx:

```sh
sudo nginx -t
```

Reinicie o Nginx:

```sh
sudo systemctl restart nginx
```

### 8. Configuração SSL com Certbot (Opcional, mas Recomendado)

- Instale Certbot:  
    `sudo snap install --classic certbot`
- Obtenha e configure SSL:  
    `sudo certbot --nginx -d seu_dominio.com`
- Siga as instruções para configurar seu certificado SSL.

---

**Lembre-se de substituir todos os placeholders como `seu_usuario`, `seu_projeto`, `seu_ip_do_servidor`, `seu_dominio.com`, `sua_senha_db`, `seu_usuario_db`, `seu_nome_db` e `/caminho/do/seu/projeto` pelos seus valores reais.**
Script de Configuração Automatizada para Ubuntu Server
