# --------------------------------------------------------------
#  1️⃣ Builder stage – compile NestJS + Prisma
# --------------------------------------------------------------
FROM node:20-slim AS builder          # Debian‑based (glibc) Node image

WORKDIR /app

# Install OS packages needed to compile native modules (Python, make, g++)
RUN apt-get update && \
    apt-get install -y --no-install-recommends python3 make g++ && \
    rm -rf /var/lib/apt/lists/*

# Copy only the package files first – this caches the layer when deps don't change
COPY backend/package*.json ./

# Install all dependencies (including dev deps needed for Prisma)
RUN npm ci

# Copy the rest of the backend source code
COPY backend/ .

# Generate Prisma client and compile TypeScript
RUN npx prisma generate && npm run build   # creates ./dist

# --------------------------------------------------------------
#  2️⃣ Runtime stage – the image that Render actually runs
# --------------------------------------------------------------
FROM node:20-slim AS runtime          # Same base image but slimmer

WORKDIR /app

# Install only what the runtime needs: ffmpeg (video processing) and dumb‑init (proper PID 1 handling)
RUN apt-get update && \
    apt-get install -y --no-install-recommends ffmpeg dumb-init && \
    rm -rf /var/lib/apt/lists/*

# Copy compiled app and its node_modules from the builder stage
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/prisma ./prisma

# Also copy the worker source (the same image is used for the background worker)
COPY worker ./worker

ENV NODE_ENV=production
EXPOSE 3001

# Render will override the command:
#   • API container → `node dist/main.js`
#   • Worker container → `node worker/src/worker.js`
ENTRYPOINT ["dumb-init", "--"]
