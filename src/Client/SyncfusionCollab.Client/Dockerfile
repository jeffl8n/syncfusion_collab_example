FROM node:20-alpine AS build
WORKDIR /app

COPY src/Client/SyncfusionCollab.Client/package*.json ./
RUN npm ci

COPY src/Client/SyncfusionCollab.Client/ ./
RUN npm run build

FROM nginx:1.27-alpine
COPY --from=build /app/build /usr/share/nginx/html
COPY src/Client/SyncfusionCollab.Client/docker/entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
EXPOSE 80
ENTRYPOINT ["/bin/sh","/entrypoint.sh"]
