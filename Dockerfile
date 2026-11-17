# syntax=docker/dockerfile:1
# Image durcie en trois étapes (build multi-étapes, cours DevOps : image finale minimale).
# Tag précis avec numéro mineur, jamais `latest` : build reproductible.

# ---- Étape 1 : dépendances ----
FROM node:24.22-alpine AS deps
WORKDIR /app
# corepack active la version de pnpm figée dans package.json (packageManager).
RUN corepack enable
# On ne copie que les fichiers de dépendances : la couche est mise en cache
# tant que le lockfile ne change pas (cours : ordre des couches et cache).
# pnpm-workspace.yaml porte ignoredBuiltDependencies, sinon l'install s'interrompt.
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
RUN pnpm install --frozen-lockfile

# ---- Étape 2 : build ----
FROM node:24.22-alpine AS build
WORKDIR /app
RUN corepack enable
ENV NEXT_TELEMETRY_DISABLED=1
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN pnpm build

# ---- Étape 3 : exécution ----
FROM node:24.22-alpine AS runner
WORKDIR /app
# Applique les correctifs de sécurité Alpine publiés depuis la sortie de l'image de base.
# Image minimale (cours DevOps) : ni npm ni npx dans l'image finale. Ils embarquent leurs
# propres dépendances, qui remontent des CVE sans servir à l'exécution (node server.js).
# Même RUN que apk upgrade : pas de couche supplémentaire.
RUN apk upgrade --no-cache \
    && rm -rf /usr/local/lib/node_modules/npm /usr/local/lib/node_modules/corepack \
              /usr/local/bin/npm /usr/local/bin/npx /usr/local/bin/corepack

# La version est injectée au build (ex. tag Git) et lue par /api/health.
ARG APP_VERSION=dev
ENV NODE_ENV=production \
    PORT=3000 \
    HOSTNAME=0.0.0.0 \
    NEXT_TELEMETRY_DISABLED=1 \
    APP_VERSION=${APP_VERSION}

# Seule la sortie standalone est copiée : ni sources, ni devDependencies, ni pnpm.
# public/ (robots.txt, favicon, images) est copié sans condition : un fichier ajouté plus tard est livré.
COPY --from=build --chown=node:node /app/.next/standalone ./
COPY --from=build --chown=node:node /app/.next/static ./.next/static
COPY --from=build --chown=node:node /app/public ./public

# Principe du moindre privilège : le processus ne tourne pas en root.
USER node
EXPOSE 3000

# Pas de curl dans l'image : on interroge la route de santé avec Node (fetch natif).
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD node -e "fetch('http://127.0.0.1:3000/api/health').then(r=>process.exit(r.ok?0:1)).catch(()=>process.exit(1))"

# Forme exec : node est le PID 1 et reçoit directement SIGTERM (arrêt propre).
CMD ["node", "server.js"]
