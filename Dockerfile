FROM node:20-alpine AS base

RUN npm install -g pnpm@9

WORKDIR /app

COPY package.json pnpm-lock.yaml ./
COPY vendor ./vendor

RUN pnpm install --frozen-lockfile

COPY . ./

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

RUN pnpm build

EXPOSE 3000

ENV PORT=3000
CMD ["pnpm", "start"]
