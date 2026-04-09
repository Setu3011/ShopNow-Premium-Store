# ── Stage: Serve static HTML with nginx ──────────────────────────────────────
FROM nginx:alpine

# Remove default nginx static files
RUN rm -rf /usr/share/nginx/html/*

# Copy the app into the nginx serve directory
# Copy index.html from app/frontend (relative to project root ShopNow-Premium-Store)
# Run: docker build from ShopNow-Premium-Store/ using -f docker/Dockerfile
COPY app/frontend/index.html /usr/share/nginx/html/index.html

# Optional: lightweight custom nginx config
RUN printf 'server {\n\
    listen 80;\n\
    server_name localhost;\n\
    root /usr/share/nginx/html;\n\
    index index.html;\n\
    location / {\n\
        try_files $uri $uri/ /index.html;\n\
    }\n\
    gzip on;\n\
    gzip_types text/html text/css application/javascript;\n\
}\n' > /etc/nginx/conf.d/default.conf

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
