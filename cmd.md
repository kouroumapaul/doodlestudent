# Arrêtez d'abord tout service utilisant le port 80
docker-compose -f docker-compose.prod.yml down

# Puis essayez Certbot en mode standalone
docker run -it --rm \
  -v "./certbot/conf:/etc/letsencrypt" \
  -v "./certbot/www:/var/www/certbot" \
  -p 80:80 \
  certbot/certbot certonly --standalone \
  --email votre-email@example.com --agree-tos \
  -d doodle.paulkourouma.com


  # Arrêter le frontend pour libérer le port 80
docker compose -f docker-compose.prod.yml stop frontend

# Obtenir les certificats
docker compose -f docker-compose.prod.yml run --rm certbot certonly --standalone \
  --email votre-email@example.com --agree-tos --no-eff-email \
  -d doodle.paulkourouma.com -d myadmin.paulkourouma.com -d pad.paulkourouma.com

# Redémarrer tous les services
docker compose -f docker-compose.prod.yml up -d


docker compose -f docker-compose.prod.yml restart frontend


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

chmod +x get-certificates-standalone.sh
./get-certificates-standalone.sh



Je vois que l'action SSH de GitHub échoue avec une erreur d'authentification. C'est un problème courant avec le workflow CI/CD lorsque la clé SSH n'est pas correctement configurée.

Voici comment résoudre ce problème :

## 1. Vérifiez la clé SSH configurée sur GitHub

L'erreur indique que l'authentification a échoué. Cela suggère que la clé SSH stockée dans les secrets GitHub (`SERVER_SSH_KEY`) ne correspond pas à celle autorisée sur votre VM.

## 2. Générez et configurez une nouvelle paire de clés

Sur votre machine locale (ou directement sur votre VM) :

```bash
# Génération d'une nouvelle clé SSH spécifique pour GitHub Actions
ssh-keygen -t ed25519 -f github-actions-key -C "github-actions"
```

Cela créera deux fichiers :
- `github-actions-key` (clé privée)
- `github-actions-key.pub` (clé publique)

## 3. Ajoutez la clé publique à votre VM

```bash
# Sur la VM
echo "votre-clé-publique-ici" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

Ou depuis votre machine locale :
```bash
cat github-actions-key.pub | ssh utilisateur@votre-serveur "cat >> ~/.ssh/authorized_keys"
```

## 4. Mettez à jour le secret dans GitHub

1. Copiez le contenu complet de la clé privée (`github-actions-key`) :
   ```bash
   cat github-actions-key
   ```

2. Allez dans votre dépôt GitHub > Settings > Secrets and variables > Actions
3. Mettez à jour le secret `SERVER_SSH_KEY` avec le contenu complet de la clé privée
   - Assurez-vous d'inclure les lignes `-----BEGIN OPENSSH PRIVATE KEY-----` et `-----END OPENSSH PRIVATE KEY-----`
   - Ne modifiez pas le format (préservez les sauts de ligne)

## 5. Vérifiez les autres secrets SSH

Assurez-vous également que :
- `SERVER_HOST` contient l'adresse IP correcte de votre VM
- `SERVER_USERNAME` contient le nom d'utilisateur correct pour se connecter à la VM

## 6. Vérifiez l'accessibilité SSH de votre VM

Assurez-vous que votre VM autorise les connexions SSH depuis l'extérieur et que le port SSH (22) est ouvert dans votre pare-feu.

```bash
# Sur votre VM
sudo ufw status
```

Si nécessaire, autorisez le port SSH :
```bash
sudo ufw allow ssh
```

Une fois ces étapes effectuées, relancez votre workflow GitHub Actions. L'erreur d'authentification SSH devrait être résolue.


# Arrêter Nginx pour libérer le port 80
docker compose -f docker-compose.prod.yml stop frontend

# Obtenir les certificats (ajoutez les nouveaux domaines)
docker run -it --rm \
  -v "/root/prod/certbot/conf:/etc/letsencrypt" \
  -v "/root/prod/certbot/www:/var/www/certbot" \
  -p 80:80 \
  certbot/certbot certonly --standalone \
  --email votre-email@example.com --agree-tos --no-eff-email \
  -d doodle.paulkourouma.com -d myadmin.paulkourouma.com -d pad.paulkourouma.com \
  -d grafana.paulkourouma.com -d munin.paulkourouma.com