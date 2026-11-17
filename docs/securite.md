# Sécurité

Plusieurs outils, chacun à une étape du pipeline : aucun ne voit tout, ensemble ils couvrent le code, les dépendances, les secrets et l'image.

## Les outils et où ils agissent

| Outil                            | Cherche                                             | Étape                           | Job ou fichier                          |
| -------------------------------- | --------------------------------------------------- | ------------------------------- | --------------------------------------- |
| gitleaks                         | Secrets dans le code et l'historique                | Commit (hook local), PR, `main` | `.githooks/pre-commit`, job `secrets`   |
| `pnpm audit`                     | Dépendances npm vulnérables (gravité haute et plus) | PR, `main`, hebdomadaire        | job `dependances`                       |
| Semgrep                          | Failles dans le code (règles TypeScript et Next.js) | PR, `main`                      | job `sast`                              |
| CodeQL                           | Analyse de flux de données (JS/TS)                  | PR, `main`                      | job `codeql`                            |
| Trivy                            | CVE dans l'image Docker                             | PR (job `docker`), release      | `ci.yml`, `release.yml`, `.trivyignore` |
| Dependabot                       | Mises à jour npm, Docker, Actions                   | Hebdomadaire (lundi)            | `.github/dependabot.yml`                |
| Secret scanning, push protection | Secrets poussés                                     | Au push                         | Réglage du dépôt                        |

Les jobs de sécurité sont dans `.github/workflows/security.yml`, qui tourne aussi chaque lundi : une CVE publiée entre deux commits est détectée sans qu'il faille pousser.

## gitleaks

Le job `secrets` récupère l'historique complet (`fetch-depth: 0`) : un secret commité puis supprimé reste dans l'historique. La configuration `.gitleaks.toml` étend les règles par défaut ; son allowlist est vide. Règle : si un faux positif doit être autorisé, on autorise un chemin précis ou une valeur précise, jamais une règle entière.

En local, le hook `pre-commit` lance gitleaks sur les fichiers indexés s'il est installé (`brew install gitleaks`), sinon il avertit. La CI reste le vrai filet.

## CodeQL : un seul mode à la fois

CodeQL tourne ici par le workflow avancé (job `codeql`, `github/codeql-action/init` puis `analyze`, avec `security-events: write` pour ce seul job). Le **« default setup » de CodeQL doit rester désactivé** dans les réglages du dépôt (Advanced Security, Code scanning). Avec les deux actifs, deux analyses du même langage publient des résultats et l'envoi du workflow est refusé.

## Réglages GitHub à activer

**Prérequis : dépôt public, ou GitHub Advanced Security activé sur un dépôt privé.** Sans GHAS sur un dépôt privé, le job `codeql` échoue et les trois réglages ci-dessous sont limités. Dans ce cas, supprimez le job `codeql` de `security.yml` (ce n'est pas un check requis).

À faire une fois par dépôt (aussi dans [demarrer-un-projet.md](demarrer-un-projet.md)) :

- **Secret scanning** et **push protection** : GitHub bloque le push d'un secret reconnu avant qu'il entre dans l'historique ;
- **Dependabot alerts** : alertes sur les dépendances vulnérables ;
- **Private vulnerability reporting** : permet le signalement privé décrit dans `SECURITY.md`.

## Triage d'une alerte : quatre questions

Un scanner remonte du bruit. Avant de corriger ou d'ignorer, répondre dans l'ordre :

1. **Est-ce atteignable en production ?** Une faille dans une dépendance de développement, ou dans un code jamais appelé, n'est pas exploitable.
2. **Une donnée utilisateur peut-elle y arriver ?** Sans entrée contrôlable par un tiers, le risque chute.
3. **Quel est l'impact ?** Fuite de données, exécution de code, simple déni de service : on priorise en conséquence.
4. **Décision.** Corriger (mettre à jour, patcher), accepter temporairement ou ignorer avec justification.

Ignorer une CVE d'image se fait dans `.trivyignore`, avec un commentaire qui porte la CVE, la raison, la date de revue et le propriétaire. Sans justification écrite, on corrige ou on met à jour l'image. Faux positif gitleaks : allowlist ciblée dans `.gitleaks.toml`, jamais une règle entière.

## Si un secret a fuité

Révoquer **d'abord** chez le fournisseur, purger l'historique ensuite. Détails dans [conventions-git.md](conventions-git.md).

## Signaler une vulnérabilité

Voir [SECURITY.md](../SECURITY.md).
