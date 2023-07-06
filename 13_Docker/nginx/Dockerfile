FROM alpine:3.14
RUN apk update && apk add nginx \
&& rm -rf /var/cache/apk/*
RUN adduser -D -g 'www' www \
&& mkdir /www \
&& chown -R www:www /var/lib/nginx \
&& chown -R www:www /www \
&& mkdir -p /run/nginx
COPY nginx.conf /etc/nginx
COPY index.html /www
EXPOSE 80
ENTRYPOINT ["nginx", "-g", "daemon off;"]