# ==============================
#  1️⃣  Builder stage – compile NestJS + Prisma
# ==============================
FROM node:20-slim AS builder            # Debian‑based (glibc) Node image
WORKDIR /app

# ---- Install OS packages needed to compile native modules (Python, make, g++) ----
RUN apt-get update && \
    apt-get install -y --no-install-recommends python3 make g++ && \
    rm -rf /var/lib/apt/lists/*

# ---- Copy only the package files first (caches layer if they don't change) ----
COPY backend/package*.json ./

# ---- Clean install all dependencies (including dev deps for Prisma) ----
RUN npm ci

# ---- Copy the rest of the backend source code ----
COPY backend/ .

# ---- Generate Prisma client and compile TypeScript ----
RUN npx prisma generate && npm run build   # creates ./dist

# ==============================
#  2️⃣  Runtime stage – the image that Render will actually run
# ==============================
FROM node:20-slim AS runtime            # another small Debian‑based image
WORKDIR /app

# ---- Install ffmpeg (needed by the background worker) ----
RUN apt-get update && \
    apt-get install -y --no-install-recommends ffmpeg dumb-init && \
    rm -rf /var/lib/apt/lists/*

# ---- Copy compiled app and node_modules from the builder stage ----
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/prisma ./prisma

# ---- Copy the worker source (the same image is used for the background worker) ----
COPY worker ./worker

ENV NODE_ENV=production
EXPOSE 3001

# Render will override the command:
#   • API container → `node dist/main.js`
#   • Worker container → `node worker/src/worker.js`
ENTRYPOINT ["dumb-init", "--"]
