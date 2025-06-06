#!/bin/bash

# Activer les addons nécessaires de sudo microk8s
echo "Activation des addons nécessaires..."
sudo microk8s enable dns ingress storage metrics-server

# Appliquer la configuration
echo "Déploiement de l'application..."
sudo microk8s kubectl apply -k base/

# Vérifier le déploiement
echo "Vérification des ressources déployées..."
echo "Pods:"
sudo microk8s kubectl get pods
echo "Services:"
sudo microk8s kubectl get services
echo "Ingress:"
sudo microk8s kubectl get ingress

# Afficher l'adresse d'accès
IP=$(hostname -I | awk '{print $1}')
echo "----------------------------------------------------------------"
echo "Application déployée! Assurez-vous que vos domaines DNS pointent vers $IP"
echo "Ou ajoutez ces entrées dans /etc/hosts pour des tests locaux:"
echo "$IP doodle.paulkourouma.com pad.paulkourouma.com myadmin.paulkourouma.com"
echo "----------------------------------------------------------------"
