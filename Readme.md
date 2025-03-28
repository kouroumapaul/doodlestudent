

## Tache 1. Préparation des Dockerfiles

### Backend (Quarkus)

N'ayant pas un ordinateur assez puissant pour executer la version native, nous avons utilisé la version JVM 

Dockerfile pour le backend dans `src/main/docker/Dockerfile.jvm` :


```dockerfile
# Etape de build rajouté
FROM maven:3.8-eclipse-temurin-17 AS build
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn package -DskipTests

# Runtime stage
FROM registry.access.redhat.com/ubi8/openjdk-17:1.16


# Nous créons quatre couches distinctes pour optimiser la réutilisation des couches
COPY --from=build --chown=185 /app/target/quarkus-app/lib/ /deployments/lib/
COPY --from=build --chown=185 /app/target/quarkus-app/*.jar /deployments/
COPY --from=build --chown=185 /app/target/quarkus-app/app/ /deployments/app/
COPY --from=build --chown=185 /app/target/quarkus-app/quarkus/ /deployments/quarkus/

EXPOSE 8080
USER 185
ENV JAVA_OPTS="-Dquarkus.http.host=0.0.0.0 -Djava.util.logging.manager=org.jboss.logmanager.LogManager"
ENV JAVA_APP_JAR="/deployments/quarkus-run.jar"

ENTRYPOINT [ "/opt/jboss/container/java/run/run-java.sh" ]
```

### Frontend (Angular + Nginx)

Nous avons rajouté à l'image de l'application frontend un serveur nginx qui servira de reverse proxy

Dockerfile pour le frontend dans `../front/Dockerfile` :

```dockerfile
# Stage 1: Build the Angular application
FROM node:18 as build
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

# Stage 2: Serve the application with Nginx
FROM nginx:alpine
COPY --from=build /app/dist/* /usr/share/nginx/html/
```

## Configuration des Docker Compose

Nous avons créé deux fichiers docker-compose distincts pour différents environnements :

### Version pour développement local (construction des images)

Cette version est utilisée pour le développement local et construit les images à partir des Dockerfiles locaux.

Créez un fichier `api/docker-compose.yaml` :

```yaml
services:
  db:
    image: mysql:8.0
    environment:
      - MYSQL_ROOT_PASSWORD=root
      - MYSQL_DATABASE=tlc
      - MYSQL_USER=tlc
      - MYSQL_PASSWORD=tlc
    volumes:
      - mysql_data:/var/lib/mysql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-proot"]
      interval: 10s
      timeout: 5s
      retries: 10
      start_period: 30s
    networks:
      - app-network

  etherpad:
    image: etherpad/etherpad
    volumes:
      - ./APIKEY.txt:/opt/etherpad-lite/APIKEY.txt
    networks:
      - app-network

  mail:
    image: bytemark/smtp
    restart: always
    networks:
      - app-network

  backend:
    build:
      context: .
      dockerfile: src/main/docker/Dockerfile.jvm
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
      etherpad:
        condition: service_started
      mail:
        condition: service_started
    environment:
      - quarkus_datasource_jdbc_url=jdbc:mysql://db:3306/tlc?useUnicode=true&characterEncoding=utf8&useSSL=false&allowPublicKeyRetrieval=true&useLegacyDatetimeCode=false&createDatabaseIfNotExist=true&serverTimezone=Europe/Paris
      - quarkus_datasource_username=tlc
      - quarkus_datasource_password=tlc
      - quarkus_hibernate_orm_database_generation=update
      - quarkus_mailer_from=olivier.barais@gmail.com
      - quarkus_mailer_host=mail
      - quarkus_mailer_port=25
      - quarkus_mailer_ssl=false
      - quarkus_mailer_username=""
      - quarkus_mailer_password=""
      - quarkus_mailer_mock=true
      - doodle_usepad=false
      - doodle_padUrl=http://etherpad:9001/
      - doodle_padApiKey=changeit
      - doodle_organizermail=olivier.barais@gmail.com
    networks:
      - app-network

  myadmin:
    image: phpmyadmin/phpmyadmin
    environment:
      - PMA_HOST=db
      - PMA_USER=root
      - PMA_PASSWORD=root
    depends_on:
      - db
    networks:
      - app-network

  frontend:
    build:
      context: ../front
      dockerfile: Dockerfile
    ports:
      - "80:80"
    depends_on:
      - backend
      - myadmin
      - etherpad
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d:rw
    networks:
      - app-network

networks:
  app-network:

volumes:
  mysql_data:
```

### Version pour production (utilisant les images d'un registry)

Pour le déploiement en production, on a utilisé une version qui récupère les images pré-construites dans notre registry

 `docker-compose.prod.yaml` :

```yaml
services:
  db:
    image: mysql:8.0
    environment:
      - MYSQL_ROOT_PASSWORD=root
      - MYSQL_DATABASE=tlc
      - MYSQL_USER=tlc
      - MYSQL_PASSWORD=tlc
    volumes:
      - mysql_data:/var/lib/mysql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-proot"]
      interval: 10s
      timeout: 5s
      retries: 10
      start_period: 30s
    networks:
      - app-network

  etherpad:
    image: etherpad/etherpad
    volumes:
      - ./APIKEY.txt:/opt/etherpad-lite/APIKEY.txt
    networks:
      - app-network

  mail:
    image: bytemark/smtp
    restart: always
    networks:
      - app-network

  backend:
    image: paulkourouma/tlc-backend:latest
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
      etherpad:
        condition: service_started
      mail:
        condition: service_started
    environment:
      - quarkus_datasource_jdbc_url=jdbc:mysql://db:3306/tlc?useUnicode=true&characterEncoding=utf8&useSSL=false&allowPublicKeyRetrieval=true&useLegacyDatetimeCode=false&createDatabaseIfNotExist=true&serverTimezone=Europe/Paris
      - quarkus_datasource_username=tlc
      - quarkus_datasource_password=tlc
      - quarkus_hibernate_orm_database_generation=update
      - quarkus_mailer_from=votre-email@example.com
      - quarkus_mailer_host=mail
      - quarkus_mailer_port=25
      - quarkus_mailer_ssl=false
      - quarkus_mailer_username=""
      - quarkus_mailer_password=""
      - quarkus_mailer_mock=true
      - doodle_usepad=false
      - doodle_padUrl=http://etherpad:9001/
      - doodle_padApiKey=changeit
      - doodle_organizermail=votre-email@example.com
    networks:
      - app-network

  myadmin:
    image: phpmyadmin/phpmyadmin
    environment:
      - PMA_HOST=db
      - PMA_USER=root
      - PMA_PASSWORD=root
    depends_on:
      - db
    networks:
      - app-network

  frontend:
    image: paulkourouma/tlc-frontend:latest
    ports:
      - "80:80" # Seul ces ports sont exposés
      - "443:443" # Pareil
    depends_on:
      - backend
      - myadmin
      - etherpad
    volumes:
      - ./nginx/conf.d:/etc/nginx/conf.d:rw
    networks:
      - app-network
    restart: always

    depends_on:
      - frontend

networks:
  app-network:

volumes:
  mysql_data:
```



## Préparez les répertoires pour Certbot et Nginx

```bash
# Créez les répertoires nécessaires
mkdir -p nginx/conf.d
mkdir -p certbot/www certbot/conf
```

## Déploiement complet avec SSL

### Tache 2 : Configuration Nginx comme reverse proxy

Pour se faciliter la tâche on a utilisé un DNS custom

```
doodle.paulkourouma.com    IN A    103.241.67.30
myadmin.paulkourouma.com   IN A    103.241.67.30
pad.paulkourouma.com       IN A    103.241.67.30
```
 
On crée un nouveau fichier de configuration nginx  `front/nginx.conf` :

```nginx
# Journalisation
error_log /var/log/nginx/error.log warn;
access_log /var/log/nginx/access.log;

# Configuration pour doodle.paulkourouma.com (application principale)
server {
    listen 80;
    server_name doodle.paulkourouma.com;
    
    # Routage des API vers le backend
    location /api {
        proxy_pass http://backend:8080/api;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Servir les fichiers statiques du frontend
    location / {
        root   /usr/share/nginx/html;
        index  index.html index.htm;
        try_files $uri $uri/ /index.html?$args;
    }
}

# Configuration pour myadmin.paulkourouma.com (phpMyAdmin)
server {
    listen 80;
    server_name myadmin.paulkourouma.com;
    
    # Redirection vers phpMyAdmin
    location / {
        proxy_pass http://myadmin:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# Configuration pour pad.paulkourouma.com (Etherpad)
server {
    listen 80;
    server_name pad.paulkourouma.com;
    
    # Redirection vers Etherpad
    location / {
        proxy_pass http://etherpad:9001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# Configuration par défaut
server {
    listen 80 default_server;
    server_name _;
    
    return 301 http://doodle.paulkourouma.com$request_uri;
}
```


En executant la commande
```bash
docker compose up --build
```
On a l'application qui se lance mais sans certificat ssl


### Obtention dles certificats SSL avec Let's Encrypt et configuration

Pour ajouter certbot on a mis à jour notre docker compose

```yaml
version: "3.8"
services:
  db:
    image: mysql:8.0
    environment:
      - MYSQL_ROOT_PASSWORD=root
      - MYSQL_DATABASE=tlc
      - MYSQL_USER=tlc
      - MYSQL_PASSWORD=tlc
    volumes:
      - mysql_data:/var/lib/mysql
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-u", "root", "-proot"]
      interval: 10s
      timeout: 5s
      retries: 10
      start_period: 30s
    networks:
      - app-network

  etherpad:
    image: etherpad/etherpad
    volumes:
      - ./APIKEY.txt:/opt/etherpad-lite/APIKEY.txt
    networks:
      - app-network

  mail:
    image: bytemark/smtp
    restart: always
    networks:
      - app-network

  backend:
    image: paulkourouma/tlc-backend:latest
    restart: unless-stopped
    depends_on:
      db:
        condition: service_healthy
      etherpad:
        condition: service_started
      mail:
        condition: service_started
    environment:
      - quarkus_datasource_jdbc_url=jdbc:mysql://db:3306/tlc?useUnicode=true&characterEncoding=utf8&useSSL=false&allowPublicKeyRetrieval=true&useLegacyDatetimeCode=false&createDatabaseIfNotExist=true&serverTimezone=Europe/Paris
      - quarkus_datasource_username=tlc
      - quarkus_datasource_password=tlc
      - quarkus_hibernate_orm_database_generation=update
      - quarkus_mailer_from=olivier.barais@gmail.com
      - quarkus_mailer_host=mail
      - quarkus_mailer_port=25
      - quarkus_mailer_ssl=false
      - quarkus_mailer_username=""
      - quarkus_mailer_password=""
      - quarkus_mailer_mock=true
      - doodle_usepad=false
      - doodle_padUrl=http://etherpad:9001/
      - doodle_padApiKey=changeit
      - doodle_organizermail=olivier.barais@gmail.com
    networks:
      - app-network

  myadmin:
    image: phpmyadmin/phpmyadmin
    environment:
      - PMA_HOST=db
      - PMA_USER=root
      - PMA_PASSWORD=root
    depends_on:
      - db
    networks:
      - app-network

  frontend:
    image: paulkourouma/tlc-frontend:latest
    ports:
      - "80:80"
      - "443:443"
    depends_on:
      - backend
      - myadmin
      - etherpad
    volumes:
      - ./certbot/www:/var/www/certbot:ro
      - ./certbot/conf:/etc/letsencrypt:ro
    networks:
      - app-network
    restart: always

  certbot: # Ajout du service
    image: certbot/certbot
    volumes:
      - ./certbot/www:/var/www/certbot:rw
      - ./certbot/conf:/etc/letsencrypt:rw
    depends_on:
      - frontend
    # Pour le test, on va utiliser la commande "--dry-run"
    # Une fois testé, vous pouvez retirer "--dry-run"
    command: certonly --webroot --webroot-path=/var/www/certbot
             --email paulledadj@gmail.com --agree-tos --no-eff-email
             --force-renewal
             -d doodle.paulkourouma.com -d myadmin.paulkourouma.com -d pad.paulkourouma.com

networks:
  app-network:

volumes:
  mysql_data:

```

On note l'ajout du service, et à la suite on lance la commande pour obtenir les certificats pour nos dommais 

```bash
# Remplacez votre-email@example.com par votre adresse email réelle
docker compose run --rm certbot certonly --webroot --webroot-path=/var/www/certbot \
  --email paul@gmail.com --agree-tos --no-eff-email \
  -d doodle.paulkourouma.com -d myadmin.paulkourouma.com -d pad.paulkourouma.com
```

On aura donc les certificats qui seront généré et on les utilises dans l enouveau fichier de conf nginx pour en tenir compte


### Mise à jour de la configuration Nginx pour HTTPS

Modifiez le fichier `front/nginx.conf` :

```nginx
# Journalisation
error_log /var/log/nginx/error.log warn;
access_log /var/log/nginx/access.log;

# Journalisation
error_log /var/log/nginx/error.log warn;
access_log /var/log/nginx/access.log;

# Configuration HTTP pour tous les domaines (pour la vérification Certbot)
server {
    listen 80;
    listen [::]:80;
    
    # Cette location est utilisée par Certbot pour la validation
    location /.well-known/acme-challenge/ {
        root /var/www/certbot;
    }
    
    # Redirection vers HTTPS
    location / {
        return 301 https://$host$request_uri;
    }
}

# Configuration HTTPS pour doodle.paulkourouma.com
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name doodle.paulkourouma.com;

    ssl_certificate /etc/letsencrypt/live/doodle.paulkourouma.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/doodle.paulkourouma.com/privkey.pem;
    
    # Routage des API vers le backend
    location /api {
        proxy_pass http://backend:8080/api;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # Servir les fichiers statiques du frontend
    location / {
        root   /usr/share/nginx/html;
        index  index.html index.htm;
        try_files $uri $uri/ /index.html?$args;
    }
}

# Configuration HTTPS pour myadmin.paulkourouma.com
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name myadmin.paulkourouma.com;

    ssl_certificate /etc/letsencrypt/live/doodle.paulkourouma.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/doodle.paulkourouma.com/privkey.pem;
    
    # Redirection vers phpMyAdmin
    location / {
        proxy_pass http://myadmin:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}

# Configuration HTTPS pour pad.paulkourouma.com
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name pad.paulkourouma.com;

    ssl_certificate /etc/letsencrypt/live/doodle.paulkourouma.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/doodle.paulkourouma.com/privkey.pem;
    
    # Redirection vers Etherpad
    location / {
        proxy_pass http://etherpad:9001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Pour bien sécuriser le tout on ajout un Pare feu avec quelques règles




## Configuration du pare-feu UFW

Installez et configurez UFW :

```bash
# Installation
apt update
apt install ufw

# Configuration de base - bloquer tout le trafic entrant et autoriser tout le trafic sortant
ufw default deny incoming
ufw default allow outgoing

# Autoriser SSH (Pour maintenir l'accès au serveur)
ufw allow ssh

# Autoriser HTTP et HTTPS
ufw allow 80/tcp
ufw allow 443/tcp

# Activer le pare-feu
ufw enable
```

Vérifiez l'état du pare-feu :

```bash
ufw status verbose
```

## Vérifiez que tout fonctionne correctement

Démarrez tous les services :

```bash
docker compose up -d
```

Puis vérifiez que tout fonctionne correctement :

- Accédez à https://doodle.paulkourouma.com 
![Doodle](/screenshots/doodle.png)

- Accédez à https://myadmin.paulkourouma.com 
![PhpMyAdmin](/screenshots/admin.png)

- Accédez à https://pad.paulkourouma.com 
![Pad](/screenshots/pad.png)


### Diagramme

Ci dessou un diagramme qui illustre notre deploiement

![Deploiment](/screenshots/deploiement.png)


# Aventure 1

Pour le deploiement continu, on a opté pour Github Actions après avoir eu plein de soucis avec GitlabCI notamment avec les runners auto hebergés et même sur des self hosted runners (machines de l'Istic).

Cela nous à permis aussi de comprendre et tester Github Actions
On a donc utilisé Github Actions avec les Runners hebergés chez Github


## Architecture de déploiement
Nous avons créé deux workflows distincts dans le repertoire `.github/workflows` :
1. **Backend CI/CD** : pour les composants API
2. **Frontend CI/CD** : pour l'application front

## Fonctionnement des workflows

### Points communs
Les deux workflows suivent une logique similaire :
- Déclenchement automatique lors des push sur la branche `main`
- Construction d'images Docker
- Publication sur DockerHub
- Déploiement sur notre serveur de production via SSH

### Spécificités techniques
- **Filtrage des chemins** : Chaque workflow ne s'exécute que lorsque des modifications sont apportées aux dossiers correspondants
- **Sécurité** : Utilisation de secrets GitHub pour stocker les informations sensibles
- **Déploiement** : Utilisation de Docker Compose pour orchestrer les conteneurs sur le serveur


## Resultat

![CI/CD](/screenshots/CI1.png)

![CI/CD](/screenshots/CI2.png)

![CI/CD](/screenshots/CI3.png)

![CI/CD](/screenshots/CI4.png)


- NB : On n'a pas eu le temps de faire passer les tests dans la Pipeline avant deploiement


# Aventure 2: Chaîne de monitoring de l'application en production

Pour assurer le suivi des performances et la santé de notre application en production, nous avons mis en place une chaîne de monitoring complète utilisant Prometheus et Grafana.

## Mise en place de Prometheus et Grafana

Nous avons ajouté les services de monitoring à notre stack Docker Compose existante :

```yaml
  prometheus:
    image: prom/prometheus:latest
    volumes:
      - ./prometheus:/etc/prometheus
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
    networks:
      - app-network
    restart: unless-stopped

  grafana:
    image: grafana/grafana:latest
    volumes:
      - grafana_data:/var/lib/grafana
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=admin
      - GF_SERVER_ROOT_URL=https://grafana.paulkourouma.com
    networks:
      - app-network
    restart: unless-stopped

  node-exporter:
    image: prom/node-exporter:latest
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.ignored-mount-points=^/(sys|proc|dev|host|etc|rootfs/var/lib/docker/containers|rootfs/var/lib/docker/overlay2|rootfs/run/docker/netns|rootfs/var/lib/docker/aufs)($$|/)'
    networks:
      - app-network
    restart: unless-stopped

  cadvisor:
    image: gcr.io/cadvisor/cadvisor:latest
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
    networks:
      - app-network
    restart: unless-stopped
```

Nous avons également configuré Prometheus pour collecter les métriques de nos services via un fichier `prometheus.yml` :

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['promotheus:9090']

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node-exporter:9100']

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']

  - job_name: 'backend'
    metrics_path: '/api/metrics'
    static_configs:
      - targets: ['backend:8080']
```

## Configuration du sous-domaine pour Grafana

Nous avons ajouté un nouveau sous-domaine `grafana.paulkourouma.com` à notre configuration DNS et configuré le proxy nginx pour rediriger le trafic vers le service Grafana :

```nginx
# Configuration HTTPS pour grafana.paulkourouma.com
server {
    listen 443 ssl;
    listen [::]:443 ssl;
    server_name grafana.paulkourouma.com;

    ssl_certificate /etc/letsencrypt/live/doodle.paulkourouma.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/doodle.paulkourouma.com/privkey.pem;
    
    # Redirection vers Grafana
    location / {
        proxy_pass http://grafana:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Nous avons également mis à jour la commande certbot pour inclure ce nouveau sous-domaine dans notre certificat SSL :

```yaml
command: certonly --webroot --webroot-path=/var/www/certbot
         --email paulledadj@gmail.com --agree-tos --no-eff-email
         --force-renewal
         -d doodle.paulkourouma.com -d myadmin.paulkourouma.com -d pad.paulkourouma.com 
         -d grafana.paulkourouma.com
```

## Configuration de Grafana

Après avoir déployé Grafana, nous avons importé plusieurs tableaux de bord pour surveiller notre application :

- 1860 : Node Exporter Full (pour surveiller les métriques du système)
- 10619 : MySQL Overview (pour surveiller votre base de données MySQL)
- 179 : Docker & System Monitoring (pour surveiller vos conteneurs Docker)

## Captures


![CI/CD](/screenshots/grafana.PNG)

![CI/CD](/screenshots/grafana1.JPG)


![CI/CD](/screenshots/grafana5.PNG)


## Problèmes rencontrés avec Munin

Nous avions également prévu d'installer Munin pour une surveillance complémentaire de notre machine virtuelle. Cependant, nous avons rencontré des difficultés avec la configuration de Munin dans notre environnement Docker. Malgré plusieurs tentatives avec différentes images Docker (notamment `dockurr/munin`), nous avons constaté des erreurs au niveau du montage des volumes et de la configuration.

# Aventure 3: Utilisation de Kubernetes comme orchestrateur d'un petit cluster

Pour cette aventure, nous avons migré notre déploiement Docker Compose vers Kubernetes afin de bénéficier des fonctionnalités avancées d'orchestration et d'ajouter de la redondance à notre backend.

## Installation de MicroK8s

Nous avons choisi MicroK8s pour sa simplicité d'installation et sa légèreté :

```bash
sudo snap install microk8s --classic --channel=1.28/stable
sudo usermod -a -G microk8s $USER
microk8s enable dns storage ingress metrics-server
```

## Organisation des manifestes Kubernetes

Nous avons adopté une structure organisée pour nos fichiers de configuration Kubernetes :

```
k8s-doodle/
├── base/
├── config/
├── services/
├── storage/
```

Cette structure facilite l'application séquentielle des manifestes en respectant les dépendances.

## Redondance du backend

L'un des principaux objectifs était d'ajouter de la redondance au microservice backend. Dans notre déploiement Kubernetes, nous avons configuré 2 réplicas du backend :

```yaml
# Extrait du fichier backend-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
spec:
  replicas: 2  # Redondance avec 2 réplicas
  # [...]
```

Cette configuration garantit que même si un pod tombe en panne, les deux autres continuent à servir les requêtes, assurant ainsi une haute disponibilité du service.

## Service Discovery et équilibrage de charge

Kubernetes gère automatiquement le service discovery et l'équilibrage de charge entre les pods du backend :

```yaml
# Extrait du fichier backend.yaml
apiVersion: v1
kind: Service
metadata:
  name: backend
spec:
  ports:
  - port: 8080
    targetPort: 8080
  selector:
    app: backend
```

Ce service dirige le trafic de manière équilibrée vers les trois pods du backend.

## Ingress pour l'accès externe

Pour exposer notre application à l'extérieur du cluster, nous avons configuré un Ingress :

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: app-ingress
spec:
  rules:
  - host: doodle.paulkourouma.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: frontend
            port:
              number: 80
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: backend
            port:
              number: 8080
  # [...]
```

## Tests de résilience

Pour valider la redondance du backend, nous avons simulé des pannes en supprimant manuellement des pods :

```bash
kubectl delete pod -n doodle backend-69d7bb56c9-z5xlp
```

Kubernetes a automatiquement créé un nouveau pod pour maintenir le nombre souhaité de 2 réplicas, et le service est resté disponible sans interruption pendant cette opération.

## Avantages observés par rapport à Docker Compose

1. **Haute disponibilité** - Le backend continue de fonctionner même lorsqu'un ou plusieurs pods tombent en panne
2. **Auto-réparation** - Kubernetes remplace automatiquement les pods défaillants
3. **Mise à l'échelle simplifiée** - Possibilité d'augmenter ou diminuer le nombre de réplicas avec une simple commande
4. **Gestion centralisée des ressources** - Limites de CPU et mémoire définies au niveau des pods
5. **Service discovery automatique** - Les services peuvent se découvrir par nom, facilitant la communication inter-services

## Conclusion

La migration vers Kubernetes nous a permis de comprendre les avantages d'un orchestrateur par rapport à une solution comme Docker Compose. La redondance du backend illustre parfaitement la valeur ajoutée de Kubernetes pour les applications critiques nécessitant une haute disponibilité. Ce déploiement offre une meilleure résilience et pose les bases d'une scalabilité future de notre application.

Bien que l'infrastructure soit plus complexe à mettre en place initialement, les bénéfices en termes de fiabilité et de flexibilité justifient pleinement cette migration pour un environnement de production.


# Aventure 4

Nous avons pas pu faire cette aventure

# Auteurs :
- Paul Kourouma
- Daouda Traoré
- Belal Ahmadi

# Conclusion
Ce projet etait très interessant, il nous a permis de découvrir l'univers du DevOps et d'implementer dans un cas réel le deploiement d'application Cloud Native
Nous avons apprecié travailler sur le projet

Merci
