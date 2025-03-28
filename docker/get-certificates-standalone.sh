#!/bin/bash

# Créer les répertoires nécessaires
mkdir -p certbot/conf certbot/www

# Arrêter tous les services qui utilisent le port 80
docker compose -f docker-compose.prod.yml down

# Obtenir les certificats en mode standalone
docker run -it --rm \
  -v "$(pwd)/certbot/conf:/etc/letsencrypt" \
  -v "$(pwd)/certbot/www:/var/www/certbot" \
  -p 80:80 \
  certbot/certbot certonly --standalone \
  --email votre-email@example.com --agree-tos --no-eff-email \
  -d doodle.paulkourouma.com

# Démarrer tous les services
docker compose -f docker-compose.prod.yml up -d