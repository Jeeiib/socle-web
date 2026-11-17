# Politique de sécurité

## Signaler une vulnérabilité

Merci de ne pas ouvrir d'issue publique. Utilisez le signalement privé de GitHub :

1. Onglet **Security** du dépôt.
2. **Report a vulnerability**.
3. Décrivez le problème, comment le reproduire et son impact.

Vous recevrez une réponse sous quelques jours. Un correctif est préparé en privé, puis publié avec un avis de sécurité.

## Versions concernées

Seule la dernière version publiée (dernier tag `vX.Y.Z`) reçoit des correctifs.

## Ce que fait le dépôt pour se protéger

Scan de secrets, audit des dépendances, analyse statique et scan d'image tournent en CI. Le détail est dans [docs/securite.md](docs/securite.md).
