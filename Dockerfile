FROM nginx
LABEL maintainer="Simon Waterer <waterer.simon@gmail.com>"

COPY ./website /website
COPY ./website.conf /etc/nginx/nginx.conf