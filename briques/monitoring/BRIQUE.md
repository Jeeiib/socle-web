---
nom: monitoring
prerequis: deploiement-serveur
remplace:
checks-requis:
---

# monitoring

Prometheus, une sonde blackbox, Alertmanager et Grafana provisionné en code. Les alertes arrivent sur le téléphone par ntfy. Les règles d'alerte sont testées avec `promtool`.

## Quand la prendre

- L'application tourne sur un serveur (brique `deploiement-serveur`) et on veut être prévenu avant les utilisateurs.
- On veut un objectif mesurable (SLO) et des alertes qui renvoient à un runbook.

## Quand ne pas la prendre

- Hébergement géré avec sa propre supervision (Vercel, Fly.io) : s'en remettre à elle.
- Serveur trop petit : la pile consomme environ 500 Mo de mémoire.

## Prérequis

Brique `deploiement-serveur` : le compose rejoint son réseau `app-prod` (déclaré `external`), la prod doit donc tourner avant. Conseillé : `logs-metriques-next` ou `logs-metriques-express`, qui exposent `http_requests_total`, `http_request_duration_seconds` et `app_build_info`. Sans elles, seules les alertes de sonde (`ServiceInjoignable`, `CertificatExpireBientot`) fonctionnent. Conseillé aussi : la brique `incidents`, dont les alertes ont des sections de runbook (`runbook_url`).

## Fichiers apportés

Tout vit dans `monitoring/` :

- `compose.monitoring.yaml` : Prometheus (rétention 35 jours), blackbox, Alertmanager, Grafana, images épinglées par version et digest. Aucun port public : les ports sont liés à `127.0.0.1`.
- `prometheus/prometheus.yml` : cibles `app:3000/api/metrics` et sonde `https://exemple.fr/api/health`. Express : remplacer `metrics_path` par `/metrics`.
- `prometheus/rules/app.yml` : règles d'enregistrement RED et quatre alertes. `prometheus/tests/app_test.yml` : chaque alerte se déclenche au-dessus du seuil et reste muette en dessous.
- `blackbox/blackbox.yml` : module `https_sante` (HTTPS obligatoire, code 200, corps `"status":"ok"`).
- `alertmanager/alertmanager.yml` : récepteur `telephone` (webhook vers ntfy).
- `grafana/` : source de données et dashboard `app-red.json` (Rate, Errors, Duration p50 et p95, disponibilité de la sonde, version en ligne, jours avant expiration du certificat).
- `secrets/.gitignore` : le dossier existe, son contenu n'est jamais commité.

## Activation

1. Dans `prometheus/prometheus.yml`, remplacer `exemple.fr` par le domaine réel (et `metrics_path` pour Express).
2. Installer l'appli ntfy sur le téléphone (iOS, Android) et choisir un sujet long et impossible à deviner (par exemple `openssl rand -hex 16`, préfixé du nom du projet). Sur ntfy.sh, qui connaît le sujet le lit : c'est un secret.
3. Créer les fichiers secrets sur le serveur, dans `monitoring/secrets/` :

   ```bash
   cd monitoring/secrets
   echo 'https://ntfy.sh/<sujet long>?template=alertmanager' > ntfy-url
   openssl rand -base64 24 > grafana-mot-de-passe
   chmod 600 ntfy-url grafana-mot-de-passe
   sudo chown 65534 ntfy-url        # utilisateur d'Alertmanager (nobody)
   sudo chown 472 grafana-mot-de-passe  # utilisateur de Grafana
   ```

   Les conteneurs ne tournent pas en root : un fichier en 600 doit appartenir à leur utilisateur. Le modèle `alertmanager` est intégré à ntfy : il met en forme les alertes (déclenchée, résolue) sans pont à maintenir.

4. S'abonner au sujet dans l'appli ntfy.
5. Lancer : `cd monitoring && docker compose -f compose.monitoring.yaml up -d`.

### Accès : tunnel SSH

Rien n'est exposé. Depuis le poste, ouvrir un tunnel puis les adresses locales :

```bash
ssh -L 3001:127.0.0.1:3001 -L 9090:127.0.0.1:9090 -L 9093:127.0.0.1:9093 deploy@exemple.fr
```

Grafana http://localhost:3001 (utilisateur `admin`, mot de passe dans `secrets/grafana-mot-de-passe`), Prometheus http://localhost:9090 (_Alerts_, _Targets_), Alertmanager http://localhost:9093 (silences).

### Option : ntfy auto-hébergé

Ajouter un service `ntfy` (image `binwiederhier/ntfy`, `serve`, `auth-default-access: deny-all`) au compose, créer un jeton (`ntfy token add <utilisateur>`) et le mettre dans `secrets/ntfy-jeton` (600, propriétaire 65534). Dans `compose.monitoring.yaml`, décommenter le montage de `ntfy-jeton` ; dans `alertmanager.yml`, retirer le préfixe `# jeton: ` des trois lignes. `ntfy-url` pointe alors vers ce serveur. L'accès public à ntfy suppose un nom de domaine et un proxy HTTPS : c'est plus lourd que ntfy.sh, à ne prendre que si l'on refuse un service tiers.

### Autres récepteurs

Même mécanisme `webhook_configs`. Exemple e-mail, à ajouter dans `receivers` (SMTP à fournir) :

```yaml
- name: courriel
  email_configs:
    - to: equipe@exemple.fr
      from: alertes@exemple.fr
      smarthost: smtp.exemple.fr:587
      auth_username: alertes@exemple.fr
      auth_password_file: /etc/alertmanager/secrets/smtp-mot-de-passe
```

## SLO de référence

- Disponibilité : 99,5 % sur 30 jours (sonde), soit un budget d'erreur d'environ 3 h 36 de panne par mois (30 j × 24 h × 0,5 %).
- Latence : p95 sous 500 ms.
- Le panneau « Disponibilité sur 30 jours » affiche la mesure. Budget consommé à moitié avant la mi-mois : geler les changements risqués et traiter la cause des pannes avant d'ajouter des fonctions.

## Alertes

| Alerte                    | Condition                          | Gravité       |
| ------------------------- | ---------------------------------- | ------------- |
| `ServiceInjoignable`      | sonde en échec pendant 2 min       | critique      |
| `TauxErreurs5xxEleve`     | plus de 5 % de 5xx sur 5 min       | critique      |
| `LatenceP95Elevee`        | p95 au-dessus de 500 ms sur 10 min | avertissement |
| `CertificatExpireBientot` | certificat expirant sous 14 jours  | avertissement |

Chacune porte `summary`, `description` et `runbook_url` vers `docs/INCIDENTS.md` (brique `incidents`).

## Vérification

- `bash scripts/verifier-briques.sh monitoring` : `promtool check config`, `check rules`, `test rules`, `amtool check-config` (avec des fichiers secrets factices), et contrôle qu'aucun sujet ntfy ni jeton n'apparaît dans la brique hors de cette fiche.
- Test de bout en bout sur le serveur : l'alerte doit arriver sur le téléphone, puis sa résolution.

  ```bash
  docker compose -f compose.monitoring.yaml exec alertmanager amtool alert add AlerteDeTest severity=warning --annotation='summary="Test ntfy"' --alertmanager.url=http://localhost:9093
  ```

  Les valeurs sont entre guillemets doubles à l'intérieur de guillemets simples, sinon `amtool` affiche un avertissement sur son analyseur de filtres. Le message arrive après `group_wait` (30 s). Pour voir la résolution, renvoyer la même alerte avec `--end` : mêmes étiquettes et mêmes annotations, sinon c'est une autre alerte.

  ```bash
  docker compose -f compose.monitoring.yaml exec alertmanager amtool alert add AlerteDeTest severity=warning --annotation='summary="Test ntfy"' --end="$(date -u +%Y-%m-%dT%H:%M:%SZ)" --alertmanager.url=http://localhost:9093
  ```

  La notification « résolue » arrive après `group_interval` (5 min).

- `runbook_url` est relatif (`docs/INCIDENTS.md#...`) : il n'est pas cliquable depuis le téléphone. Le remplacer dans `rules/app.yml` (et `app_test.yml`) par l'URL complète du dépôt, par exemple `https://github.com/<organisation>/<depot>/blob/main/docs/INCIDENTS.md#serviceinjoignable`.

## Pièges connus

- `network app-prod not found` : la prod n'est pas démarrée, ou son compose n'est pas celui de `deploiement-serveur` (réseau nommé `app-prod`).
- Alertmanager redémarre en boucle avec `permission denied` sur `ntfy-url` : le fichier n'appartient pas à l'utilisateur 65534 (ou n'est pas lisible). Grafana : même symptôme sur `grafana-mot-de-passe` (472).
- Un fichier secret absent au premier `up` : Docker crée un dossier à sa place. Supprimer ce dossier, créer le fichier, relancer.
- Le sujet ntfy ne doit jamais entrer dans Git : le dépôt est public. Un sujet qui a fuité se remplace par un nouveau (modifier `ntfy-url`, redémarrer Alertmanager, se réabonner).
- La sonde interroge l'URL publique depuis le serveur : si le serveur ne peut pas se joindre par son IP publique, `ServiceInjoignable` se déclenchera à tort.
- Pas de métriques (`app` en `down` dans _Targets_) : `/api/metrics` est refusé en public par Nginx mais doit répondre sur `app:3000` ; vérifier la brique de métriques et le `metrics_path`.
- Sans trafic, `TauxErreurs5xxEleve` et `LatenceP95Elevee` ne se déclenchent pas (pas de données) : la sonde est le filet de sécurité.
