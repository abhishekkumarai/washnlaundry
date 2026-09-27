FROM node:20-alpine

WORKDIR /app

# Install build dependencies if needed
COPY package*.json ./
RUN npm install --omit=dev

# Copy application source
COPY src/ ./src/

ENV PORT=3000
ENV NODE_ENV=production
ENV SESSION_DIR=/app/session

EXPOSE 3000

CMD ["node", "src/index.js"]
