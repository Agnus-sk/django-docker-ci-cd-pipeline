# Build stage
FROM node:20-alpine AS build
WORKDIR /app

COPY package*.json ./
RUN npm ci --no-audit --no-fund

COPY . .
RUN npm run build

# Runtime stage (non-root)
FROM node:20-alpine

WORKDIR /app
COPY --from=build /app/dist ./dist

RUN npm install -g serve \
 && adduser -D appuser \
 && chown -R appuser:appuser /app

USER appuser

EXPOSE 3000
CMD ["serve", "-s", "dist", "-l", "3000"]
