FROM node:20-alpine
WORKDIR /app
COPY packages/common /packages/common
RUN npm install --prefix /packages/common --omit=dev

COPY services/tax-service/package.json ./
COPY services/tax-service/src ./src
RUN npm install --omit=dev

ENV NODE_ENV=production
EXPOSE 3008
CMD ["node", "src/server.js"]