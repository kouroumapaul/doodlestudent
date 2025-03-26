#!/bin/bash

# Créer les répertoires nécessaires pour Certbot
mkdir -p ./certbot/conf
mkdir -p ./certbot/www

# Modifier le docker-compose.yml pour supprimer la version obsolète
sed -i '/^version:/d' docker-compose.yaml

# Étape 1 : Démarrer avec une configuration temporaire sans SSL
echo "Étape 1: Configuration sans SSL pour obtenir les certificats"
cp nginx-temp.conf ../front/nginx.conf

# Arrêter tous les conteneurs précédents
docker compose down

# Démarrer le frontend avec configuration temporaire
docker compose up -d frontend

# Attendre que le service nginx soit complètement démarré
echo "Attente de 10 secondes pour que Nginx démarre..."
sleep 10

# Étape 2 : Obtenir les certificats SSL avec Certbot
echo "Étape 2: Obtention des certificats SSL"
docker compose run --rm certbot certonly --webroot --webroot-path=/var/www/certbot \
  --email paulledadj@gmail.com --agree-tos --no-eff-email \
  --force-renewal \
  -d doodle.paulkourouma.com -d myadmin.paulkourouma.com -d pad.paulkourouma.com

# Vérifier si les certificats ont été générés avec succès
if [ -f "./certbot/conf/live/doodle.paulkourouma.com/fullchain.pem" ]; then
  echo "Certificats générés avec succès!"
  
  # Étape 3 : Passer à la configuration avec SSL
  echo "Étape 3: Activation de la configuration SSL"
  cp nginx-ssl.conf ../front/nginx.conf
  
  # Redémarrer le service frontend
  docker compose restart frontend
  
  echo "Configuration SSL terminée! Votre application est maintenant sécurisée avec HTTPS."
else
  echo "Erreur: Les certificats n'ont pas été générés correctement."
  echo "Vérifiez que vos domaines pointent vers l'adresse IP de ce serveur."
  echo "L'application reste en mode HTTP uniquement."
fi

# Démarrer tous les services
echo "Démarrage de tous les services..."
docker compose up -d