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

## Secret exposé

Dans cet ordre :

1. **Révoquer** chez le fournisseur : tant que la clé vit, elle est exploitable, purger l'historique n'y change rien ;
2. **Remplacer** par une nouvelle valeur, dans les secrets du dépôt et de l'hébergeur ;
3. **Purger l'historique** si besoin (détails dans [conventions-git.md](conventions-git.md)) ;
4. **Vérifier les journaux d'accès** du fournisseur sur la période d'exposition : la clé a-t-elle servi ?

## Registre des exceptions

Toute règle d'un scanner qu'on choisit de ne pas appliquer est inscrite ici, avec sa justification et une date de revue.

| Règle                                    | Justification                                        | Date de revue  |
| ---------------------------------------- | ---------------------------------------------------- | -------------- |
| ~~`javascript.exemple.regle-d-exemple`~~ | ~~Exemple : entrée jamais contrôlable par un tiers~~ | ~~2027-01-15~~ |

Règles :

- `// nosemgrep: <id-de-règle>` sur la ligne concernée, jamais un `nosemgrep` nu ;
- allowlist gitleaks par chemin ou par valeur précise, jamais une règle entière ;
- CVE d'image : `.trivyignore`, avec CVE, raison, date de revue et propriétaire.

## Modèle de menaces STRIDE

À remplir pour votre projet : une ligne par menace réellement pertinente.

| Menace                                  | Exemple dans le projet | Parade |
| --------------------------------------- | ---------------------- | ------ |
| **S**poofing (usurpation)               |                        |        |
| **T**ampering (altération)              |                        |        |
| **R**epudiation (déni)                  |                        |        |
| **I**nformation disclosure (fuite)      |                        |        |
| **D**enial of service (déni de service) |                        |        |
| **E**levation of privilege (élévation)  |                        |        |

## En-têtes HTTP

`src/lib/en-tetes-securite.ts` pose, via `headers()` dans `next.config.ts`, sur toutes les routes :

- `Content-Security-Policy` : `default-src 'self'`, `object-src 'none'`, `frame-ancestors 'none'`, `base-uri 'self'`, `form-action 'self'` ; `unsafe-eval` seulement en développement ;
- `Strict-Transport-Security` (un an, sous-domaines compris), `X-Content-Type-Options: nosniff`, `Referrer-Policy: strict-origin-when-cross-origin`, `Permissions-Policy` (caméra, micro, géolocalisation coupés), `Cross-Origin-Opener-Policy` et `Cross-Origin-Resource-Policy` à `same-origin`.

La CSP garde `'unsafe-inline'` pour les scripts : Next injecte des scripts inline et un nonce par requête oblige à un rendu dynamique de toutes les pages. Une application qui le justifie (données sensibles, exigence de conformité) peut passer à une CSP à nonce générée dans un `proxy.ts`, en acceptant ce rendu dynamique forcé (plus de pages statiques ni de cache CDN).

## Vérifier une image

Chaque release publie l'image sur GHCR avec une attestation de provenance et un SBOM CycloneDX (joint à la release, `sbom.cdx.json`). Vérifier qu'une image vient bien de ce dépôt :

```bash
gh attestation verify oci://ghcr.io/<dépôt>:<version> --owner <propriétaire>
```

Le tag de l'image n'a pas de `v` : pour la release `v1.2.3`, la version est `1.2.3` (`ghcr.io/<dépôt>:1.2.3`).

## Signaler une vulnérabilité

Voir [SECURITY.md](../SECURITY.md).
