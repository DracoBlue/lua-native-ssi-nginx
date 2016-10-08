FROM dracoblue/nginx-extras:1.10.1-0
RUN apt-get update
RUN apt-get install lua-cjson
ADD .travis/port-4777-app.conf /etc/nginx/sites-enabled/port-4777-app.conf
ADD .travis/port-4778-app.conf /etc/nginx/sites-enabled/port-4778-app.conf
ADD .travis/port-4779-app.conf /etc/nginx/sites-enabled/port-4779-app.conf
ADD .travis/port-4780-app.conf /etc/nginx/sites-enabled/port-4780-app.conf
ADD src/lua-ssi-content.lua /etc/nginx/lua-ssi-content.lua
ADD src/lua-ssi-header.lua /etc/nginx/lua-ssi-header.lua
ADD tests  /var/www/html
EXPOSE 4780
EXPOSE 4779
EXPOSE 4778
EXPOSE 4777
