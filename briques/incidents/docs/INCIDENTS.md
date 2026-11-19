# Gestion des incidents

Quand quelque chose casse en production, on répare d'abord, puis on comprend, puis on écrit ce qu'on a appris. Un post-mortem n'a pas pour but de trouver un coupable mais d'éviter que l'incident se reproduise : il est sans blâme, on parle de processus et de systèmes, pas de personnes. Chaque post-mortem se termine par au moins une issue qui améliore le code, le pipeline ou la supervision.

```
alerte -> incident (diagnostic, correction) -> post-mortem sans blâme -> issue -> amélioration
```

## Supervision en place

| Outil        | Adresse               | Sert à                                                      |
| ------------ | --------------------- | ----------------------------------------------------------- |
| Prometheus   | http://localhost:9090 | alertes (_Alerts_), cibles (_Targets_), requêtes PromQL     |
| Alertmanager | http://localhost:9093 | alertes actives ; poser un silence pendant une intervention |
| Grafana      | http://localhost:3001 | tableau de bord RED et disponibilité                        |

Ces adresses ne sont joignables que par tunnel SSH (`ssh -L 3001:127.0.0.1:3001 -L 9090:127.0.0.1:9090 -L 9093:127.0.0.1:9093 deploy@exemple.fr`), voir la fiche de la brique `monitoring`.

## Méthode de diagnostic

Du symptôme vers la cause, jamais l'inverse.

- **RED** (côté service, ce que voit l'utilisateur) : **R**ate (requêtes par seconde), **E**rrors (part de 5xx), **D**uration (latence p95). On commence ici.
- **USE** (côté ressource, ce qui explique le symptôme) : pour chaque ressource (CPU, mémoire, disque, réseau, connexions à la base), **U**tilisation, **S**aturation, **E**rreurs.

Étapes :

1. **Alerte** : laquelle, depuis quand, quelle cible ? Noter l'heure : c'est le début de la chronologie.
2. **Tableau de bord** : depuis quand ? La version a-t-elle changé ? Les courbes RED montent-elles (erreurs) ou s'arrêtent-elles (service mort) ?
3. **Symptôme** : `curl -sI https://exemple.fr/api/health` ; que voit l'utilisateur ?
4. **Conteneurs** : `docker compose ps` (qui est `unhealthy`, `Restarting` ?).
5. **Journaux** du service suspect, filtrés : `docker compose logs --no-log-prefix --since 15m app | jq -c 'select(.level != "info")'`.
6. **Cause** : configuration, code, base, ressources ? La prouver (`docker inspect`, fichier, requête) avant de corriger.
7. **Correction**, puis **vérification** : état des conteneurs, `/api/health`, une action utilisateur, alerte résolue.

Pendant une intervention longue, un silence dans Alertmanager (avec commentaire et durée) évite de recevoir la même alerte en boucle sans la supprimer.

## Runbook par alerte

### ServiceInjoignable

**Gravité** : critique. La sonde ne reçoit plus de réponse saine du service depuis 2 minutes.

1. `docker compose ps` : l'application tourne-t-elle, redémarre-t-elle en boucle ?
2. Journaux filtrés sur `level=fatal` et `level=error` : une configuration manquante ou une base injoignable apparaît ici.
3. `curl -sI https://exemple.fr/api/health` depuis l'extérieur, puis depuis le serveur : si seul l'extérieur échoue, regarder nginx et le pare-feu.
4. Dernier déploiement ? Si oui, revenir à la version précédente (`deploy.sh` avec le tag précédent), puis analyser.

### TauxErreurs5xxEleve

**Gravité** : critique. Plus de 5 % de réponses 5xx pendant 5 minutes.

1. Tableau de bord : les erreurs touchent-elles toutes les routes ou une seule ? Coïncident-elles avec un déploiement ?
2. Journaux `level=error` : message et route les plus fréquents.
3. Base de données : connexions saturées, disque plein, requête lente (USE).
4. Dépendance externe en panne ? Vérifier ses délais d'attente et sa page de statut.

### LatenceP95Elevee

**Gravité** : avertissement. Le p95 dépasse 500 ms pendant 10 minutes.

1. Panneau Duration par route : une route ou toutes ?
2. Ressources du serveur (USE) : CPU saturé, mémoire qui swape, disque lent.
3. Base : requêtes lentes, verrous, index manquant.
4. Pic de trafic légitime ou robot ? Comparer avec le panneau Rate.

### CertificatExpireBientot

**Gravité** : avertissement. Le certificat TLS expire dans moins de 14 jours.

1. Vérifier la date réelle : `echo | openssl s_client -connect exemple.fr:443 -servername exemple.fr 2>/dev/null | openssl x509 -noout -enddate`.
2. Le renouvellement automatique a échoué : lire ses journaux (le client ACME ou le proxy qui l'exécute).
3. Causes fréquentes : port 80 fermé pour le défi, DNS qui ne pointe plus vers le serveur, limite de débit de l'autorité.
4. Renouveler à la main, recharger le proxy, puis revérifier la date.

## Modèle de post-mortem

Copier ce modèle pour chaque incident.

```markdown
## Incident n° N - Titre court

**Gravité** : faible / moyenne / élevée
**Détection** : alerte <nom> / utilisateur / autre ; délai entre le début et la détection : X min
**Durée** : début hh:mm, fin hh:mm (MTTR = durée totale jusqu'au rétablissement)
**Rédaction** : ...

### Résumé

Deux ou trois phrases : ce qui s'est passé et l'impact pour les utilisateurs.

### Impact

Qui, combien de temps, quelles fonctions, quelles données.

### Chronologie (préciser UTC ou heure locale)

- hh:mm - Changement à l'origine de l'incident
- hh:mm - Premier signal (alerte, message d'un utilisateur)
- hh:mm - Diagnostic : ce qu'on a regardé, ce qu'on a trouvé
- hh:mm - Correction appliquée
- hh:mm - Retour à la normale confirmé

### Cause racine (5 pourquoi)

1. Pourquoi ... ?

### Ce qui a bien fonctionné

### Ce qui a moins bien fonctionné

### Actions

| Action | Type                               | Responsable | Date limite | Issue | Statut  |
| ------ | ---------------------------------- | ----------- | ----------- | ----- | ------- |
| ...    | prévention / détection / processus | ...         | AAAA-MM-JJ  | #N    | à faire |
```

---

<!-- Ajouter les post-mortems au-dessus de cette ligne, du plus récent au plus ancien. -->
