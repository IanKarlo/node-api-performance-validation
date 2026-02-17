# ============================================================
# Multi-stage Dockerfile for node-api-performance-validation
# Builds TypeScript, Rust (NAPI), and Zig native addons
# ============================================================

# ------ Stage 1: Base with Node.js ------
FROM node:20-bookworm-slim AS base

RUN corepack enable && corepack prepare yarn@4.9.1 --activate

WORKDIR /app

COPY package.json yarn.lock .yarnrc.yml ./
COPY src/native/rust/package.json src/native/rust/package.json

# ------ Stage 2: Install Node dependencies ------
FROM base AS deps

RUN yarn install --immutable

# ------ Stage 3: Build Rust native addon ------
FROM deps AS build-rust

# Install Rust toolchain
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl build-essential && \
    update-ca-certificates && \
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --profile minimal && \
    rm -rf /var/lib/apt/lists/*

ENV PATH="/root/.cargo/bin:${PATH}"

# Copy Rust source
COPY src/native/rust/ src/native/rust/

# Build Rust NAPI addon
WORKDIR /app/src/native/rust
RUN yarn install --immutable && yarn build
WORKDIR /app

# ------ Stage 4: Build Zig native addon ------
FROM deps AS build-zig

# Install Zig
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl xz-utils && \
    update-ca-certificates && \
    rm -rf /var/lib/apt/lists/*

ARG ZIG_VERSION=0.15.1
RUN curl -fsSL "https://ziglang.org/download/${ZIG_VERSION}/zig-x86_64-linux-${ZIG_VERSION}.tar.xz" \
    | tar -xJ -C /usr/local && \
    ln -s /usr/local/zig-x86_64-linux-${ZIG_VERSION}/zig /usr/local/bin/zig

# Copy Zig source
COPY src/native/zig/ src/native/zig/

# Build Zig addon
RUN cd src/native/zig && zig build -Doptimize=ReleaseFast

# ------ Stage 5: Build TypeScript ------
FROM deps AS build-ts

COPY tsconfig.json ./
COPY src/ src/

# Copy built native addons from previous stages
COPY --from=build-rust /app/src/native/rust/*.node src/native/rust/
COPY --from=build-rust /app/src/native/rust/index.js src/native/rust/
COPY --from=build-rust /app/src/native/rust/index.d.ts src/native/rust/
COPY --from=build-zig /app/src/native/zig/zig-out/lib/addon.node src/native/zig/zig-out/lib/

# Compile TypeScript
RUN yarn tsc

# Copy native files to dist
RUN yarn copy-native

# ------ Stage 6: Production image ------
FROM node:20-bookworm-slim AS production

RUN corepack enable && corepack prepare yarn@4.9.1 --activate

WORKDIR /app

# Copy package files and install production deps only
COPY package.json yarn.lock .yarnrc.yml ./
COPY src/native/rust/package.json src/native/rust/package.json
RUN yarn workspaces focus --production 2>/dev/null || yarn install --immutable

# Copy compiled dist
COPY --from=build-ts /app/dist ./dist

# Default env vars
ENV NODE_ENV=production
ENV PORT=3000
ENV LANG_MODEL=TS

EXPOSE 3000

CMD ["node", "dist/index.js"]
