#!/bin/bash

# Créer les répertoires nécessaires pour Certbot
mkdir -p ./certbot/conf
mkdir -p ./certbot/www

# Démarrer nginx pour qu'il soit disponible lors de la génération des certificats
docker compose up -d frontend

# Attendre que le service nginx soit complètement démarré
sleep 10

# Exécuter Certbot pour générer les certificats initiaux
docker compose run --rm certbot certonly --webroot --webroot-path=/var/www/certbot \
  --email paulledadj@gmail.com --agree-tos --no-eff-email \
  -d doodle.paulkourouma.com -d myadmin.paulkourouma.com -d pad.paulkourouma.com

# Redémarrer Nginx pour charger les nouveaux certificats
docker compose restart frontend

echo "Certificats SSL générés avec succès!"
echo "Votre application est maintenant accessible en HTTPS."
