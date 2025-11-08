FROM node:20-alpine AS build
WORKDIR /app

COPY src/Client/SyncfusionCollab.Client/package*.json ./
RUN npm ci

COPY src/Client/SyncfusionCollab.Client/ ./
ARG SYNCFUSION_API_BASE
ARG SYNCFUSION_LICENSE_KEY
ENV SYNCFUSION_API_BASE=${SYNCFUSION_API_BASE}
ENV SYNCFUSION_LICENSE_KEY=${SYNCFUSION_LICENSE_KEY}
RUN npm run build

FROM nginx:1.27-alpine
COPY --from=build /app/build /usr/share/nginx/html
EXPOSE 80
