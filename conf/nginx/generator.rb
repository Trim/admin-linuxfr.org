#!/usr/bin/env ruby
# Generate the nginx configuration for a vhost

require 'erb'


if ARGV.empty?
  $stderr.puts "Usage: ./path/to/generator.rb env > sites-available/vhost"
  $stderr.puts "       where env is local, alpha or production"
  exit -1
end

case env = ARGV.first
when "local"
  user    = "nono"
  vserver = "nono"
  fqdn    = "dlfp.lo"
when "alpha"
  user    = "alpha"
  vserver = "alpha"
  fqdn    = "alpha.linuxfr.org"
when "production"
  user    = "linuxfr"
  vserver = "prod"
  fqdn    = "linuxfr.org"
end

# Gruikkkkk
puts ERB.new(DATA.read).result(binding)

__END__
# Please do not edit: this file was generated by conf/nginx/generator.rb

upstream linuxfr-frontend {
    server unix:/var/www/<%= user %>/<%= env %>/shared/tmp/sockets/<%= env %>.sock fail_timeout=0;
}

upstream board-frontend {
    server unix:/var/www/<%= user %>/board/board.sock;
}


server {
    server_name <%= fqdn %>;
    access_log /data/<%= vserver %>/logs/<%= user %>/access.log;
    error_log /data/<%= vserver %>/logs/<%= user %>/error.log error;
    root /var/www/<%= user %>/<%= env %>/current/public;

    listen 80;
    listen 443 default ssl;

    ssl_protocols SSLv3 TLSv1;
    ssl_certificate ssl.crt/<%= fqdn %>.crt;
    ssl_certificate_key ssl.key/<%= fqdn %>.key;
    ssl_session_cache shared:SSL:2m;

    add_header X-Frame-Options DENY;

    proxy_max_temp_file_size 0;
    client_max_body_size 2M;

    proxy_intercept_errors on;
    error_page  404              /errors/400.html;
    error_page  500 502 503 504  /errors/500.html;

    merge_slashes on;
    keepalive_timeout 5;

    set $redirect_to_https $cookie_https/$scheme;
    if ($redirect_to_https = '1/http') {
        rewrite ^(.*)$ https://<%= fqdn %>$1 break;
    }

    # Dispatching
    location ^~ /images/load/ {
        autoindex on;
        expires 5m;
    }

    location ~* \.(css|js|ico|gif|jpe?g|png|svg|xcf|ttf|otf|dtd)$ {
        expires 10d;
        if ($args ~* [0-9]+$) {
            expires max;
            break;
        }
    }
<% if env == "alpha" %>
    location = /robots.txt {
        rewrite ^(.*)$ /system/$1 last;
    }
<% end %>
    location ~* ^/(fonts|images|javascripts|stylesheets) {
        autoindex on;
        break;
    }

    location ^~ /b/ {
        proxy_pass http://board-frontend;
    }

    location ^~ /webalizer {
        root /data/<%= vserver %>/logs;
    }

    # Don't try to respond to PHP/ASP/Apple pages
    location ~* \.(php|asp|aspx|jsp|cgi|labels.rdf|apple-touch-icon(-precomposed)?.png)$ {
      return 410;
    }

    location / {
        # Redirections to preserve templeet URL
        rewrite ^/(pub|my|wap|pda|i|interviews|newsletter|rdf|sidebar|usenet)(/.*)?$ / permanent;
        rewrite ^/backend/news-homepage/rss20.rss$ /backend-news.rss break;
        rewrite ^.*\.rss$ /backend.rss break;
        rewrite ^/\d+/\d+/\d+/(\d+)\.html$ /news/$1 permanent;
        rewrite ^/(\d+/\d+/\d+)/index.html$ /$1 permanent;
        rewrite ^/topics/([^,./]*)(,.*)?(.html)?$ /section/$1 permanent;
        rewrite ^/~([^/]*)/?$ /users/$1 permanent;
        rewrite ^/~([^/]*)/(\d+)\.html$ /users/$1/journaux/$2 permanent;
        rewrite ^/~([^/]*)/news.*$ /users/$1/news permanent;
        rewrite ^/~([^/]*)/forums.*$ /users/$1/posts permanent;
        rewrite ^/~([^/]*)/tracker.*$ /users/$1/suivi permanent;
        rewrite ^/~([^/]*)/comments.*$ /users/$1/comments permanent;
        rewrite ^/forums/(\d+)/(\d+)\.html$ /forums/$1/posts/$2 permanent;
        rewrite ^/forums/(\d+)\.+$ /forums/$1 permanent;
        rewrite ^/journal.*$ /journaux permanent;
        rewrite ^/tracker.*$ /suivi permanent;
        rewrite ^/aide.+$ /aide permanent;
        rewrite ^/users/?$ /tableau-de-bord permanent;
        rewrite ^/dons.*$ /faire_un_don permanent;
        rewrite ^/moderateurs/moderation.html$ /regles_de_moderation permanent;
        rewrite ^/moderateurs.*$ /team permanent;
        rewrite ^/redacteurs.*$ /redaction permanent;
        rewrite ^/board/remote.xml$ /board/index.xml permanent;
        rewrite ^/bouchot.*$ /board permanent;
        rewrite ^/logos\.html$ /images/logos/ permanent;
        rewrite ^/submit.html$ /news/nouveau permanent;

        try_files $uri /pages/$uri /pages/$uri.html @dynamic;
    }

    location @dynamic {
        if (-f $document_root/system/maintenance.html ) {
            error_page 503 /system/maintenance.html;
            return 503;
        }

        proxy_set_header X_FORWARDED_PROTO $scheme;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header Host $http_host;
        proxy_redirect off;
        proxy_pass http://linuxfr-frontend;
    }
}

# No-www
server {
    server_name www.<%= fqdn %>;
    listen 80;
    listen 443;
    ssl_certificate ssl.crt/<%= fqdn %>.crt;
    ssl_certificate_key ssl.key/<%= fqdn %>.key;
    rewrite ^/(.*) $scheme://<%= fqdn %>/$1 permanent;
}
