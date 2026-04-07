# --------------------------------------------------------------
#  1️⃣ Builder stage – compile NestJS, generate Prisma client, build TS
# --------------------------------------------------------------
FROM node:20-slim AS builder               # ✅ valid FROM line (three‑argument form not needed)

# Set a working directory inside the container
WORKDIR /app

# ---- Install OS packages needed to compile native modules (Python, make, g++) ----
RUN apt-get update && \
    apt-get install -y --no-install-recommends python3 make g++ && \
    rm -rf /var/lib/apt/lists/*

# ---- Copy only the package‑json files first (caches this layer on rebuilds) ----
COPY backend/package*.json ./

# ---- Install **all** dependencies (dev‑deps are needed for Prisma) ----
RUN npm ci

# ---- Copy the rest of the backend source code ----
COPY backend/ .

# ---- Generate Prisma client and compile the NestJS TypeScript sources ----
RUN npx prisma generate && npm run build   # creates ./dist

# --------------------------------------------------------------
#  2️⃣ Runtime stage – the image
