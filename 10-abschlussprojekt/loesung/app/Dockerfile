# Basis-Image: Node.js 22 auf dem sehr kleinen Alpine Linux
FROM node:22-alpine

# Arbeitsverzeichnis im Container
WORKDIR /app

# Nur die Dateien kopieren, die die App zum Laufen braucht (keine Tests)
COPY package.json server.js ./

# Build-Argument: wird mit "docker build --build-arg APP_VERSION=..." gesetzt
# und als Umgebungsvariable ins Image geschrieben
ARG APP_VERSION=dev
ENV APP_VERSION=$APP_VERSION

# Nicht als root laufen – das Image bringt den Benutzer "node" mit
USER node

# Dokumentation: Die App lauscht auf Port 3000
EXPOSE 3000

# Docker prüft regelmäßig selbst, ob die App noch antwortet
HEALTHCHECK --interval=30s --timeout=3s CMD wget -qO- http://localhost:3000/health || exit 1

# Startbefehl
CMD ["node", "server.js"]
