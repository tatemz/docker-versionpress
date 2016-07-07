#!/bin/bash
set -e

# Turn off caching
if [ "$WORDPRESS_OPCACHE" = 'off' ]; then
  rm -rf /usr/local/etc/php/conf.d/opcache-recommended.ini
fi

# Declare project vars
if [ ! -z $WP_SKELETON ]; then
  PROJECT_DIR="/var/www/html/default"
  WP_DIR="$PROJECT_DIR/wp"
  WP_CONTENT_DIR="$PROJECT_DIR/content"
  WP_CONFIG="$PROJECT_DIR/local-config.php"
  WP_CONFIG_SAMPLE="$PROJECT_DIR/local-config-sample.php"
else
  PROJECT_DIR="/var/www/html/default"
  WP_DIR=$PROJECT_DIR
  WP_CONTENT_DIR="$WP_DIR/wp-content"
  WP_CONFIG="$WP_DIR/wp-config.php"
  WP_CONFIG_SAMPLE="$WP_DIR/wp-config-sample.php"
fi

if [[ "$1" == apache2* ]] || [ "$1" == php-fpm ]; then
  : "${WORDPRESS_DB_HOST:=mysql}"
  # if we're linked to MySQL and thus have credentials already, let's use them
  : ${WORDPRESS_DB_USER:=${MYSQL_ENV_MYSQL_USER:-root}}
  if [ "$WORDPRESS_DB_USER" = 'root' ]; then
    : ${WORDPRESS_DB_PASSWORD:=$MYSQL_ENV_MYSQL_ROOT_PASSWORD}
  fi
  : ${WORDPRESS_DB_PASSWORD:=$MYSQL_ENV_MYSQL_PASSWORD}
  : ${WORDPRESS_DB_NAME:=${MYSQL_ENV_MYSQL_DATABASE:-wordpress}}

  if [ -z "$WORDPRESS_DB_PASSWORD" ]; then
    echo >&2 'error: missing required WORDPRESS_DB_PASSWORD environment variable'
    echo >&2 '  Did you forget to -e WORDPRESS_DB_PASSWORD=... ?'
    echo >&2
    echo >&2 '  (Also of interest might be WORDPRESS_DB_USER and WORDPRESS_DB_NAME.)'
    exit 1
  fi

  mkdir -p $PROJECT_DIR && chown www-data:www-data $PROJECT_DIR && chown -R www-data:www-data $PROJECT_DIR

  if [ ! -z $WP_SKELETON ] && [ ! -e $PROJECT_DIR/index.php ]; then
    echo >&2 "WordPress Skeleton not found in $PROJECT_DIR - copying now..."
    if [ "$(ls -A $PROJECT_DIR)" ]; then
      echo >&2 "WARNING: $PROJECT_DIR is not empty - press Ctrl+C now if this is an error!"
      ( set -x; ls -A $PROJECT_DIR; sleep 10 )
    fi
    git clone https://github.com/markjaquith/WordPress-Skeleton.git $PROJECT_DIR
    rm -rf $PROJECT_DIR/.git
    echo >&2 "Complete! WordPress Skeleton has been successfully copied to $PROJECT_DIR"
    if [ ! -e $PROJECT_DIR/.htaccess ]; then
      # NOTE: The "Indexes" option is disabled in the php:apache base image
      cat > $PROJECT_DIR/.htaccess <<-'EOF'
        # BEGIN WordPress
        <IfModule mod_rewrite.c>
        RewriteEngine On
        RewriteBase /
        RewriteRule ^index\.php$ - [L]
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteCond %{REQUEST_FILENAME} !-d
        RewriteRule . /index.php [L]
        </IfModule>
        # END WordPress
EOF
      chown www-data:www-data $PROJECT_DIR/.htaccess
    fi
  fi

  mkdir -p $WP_DIR && chown www-data:www-data $WP_DIR && chown -R www-data:www-data $WP_DIR

  if ! [ -e $WP_DIR/index.php -a -e $WP_DIR/wp-includes/version.php ]; then
    echo >&2 "WordPress not found in $WP_DIR - copying now..."
    if [ "$(ls -A $WP_DIR)" ]; then
      echo >&2 "WARNING: $WP_DIR is not empty - press Ctrl+C now if this is an error!"
      ( set -x; ls -A $WP_DIR; sleep 10 )
    fi
    tar cf - --one-file-system -C /usr/src/wordpress . | tar xf - -C $WP_DIR/
    echo >&2 "Complete! WordPress has been successfully copied to $WP_DIR"
    if [ -z $WP_SKELETON ] && [ ! -e $WP_DIR/.htaccess ]; then
      # NOTE: The "Indexes" option is disabled in the php:apache base image
      cat > $WP_DIR/.htaccess <<-'EOF'
        # BEGIN WordPress
        <IfModule mod_rewrite.c>
        RewriteEngine On
        RewriteBase /
        RewriteRule ^index\.php$ - [L]
        RewriteCond %{REQUEST_FILENAME} !-f
        RewriteCond %{REQUEST_FILENAME} !-d
        RewriteRule . /index.php [L]
        </IfModule>
        # END WordPress
EOF
      chown www-data:www-data $WP_DIR/.htaccess
    fi
  fi

  # Copy VersionPress
  if ! [ -e $WP_CONTENT_DIR/plugins/versionpress/versionpress.php ]; then
    echo >&2 "VersionPress not found in $WP_CONTENT_DIR/plugins/versionpress - copying now..."
    mkdir -p $WP_CONTENT_DIR/plugins/versionpress/
    if [ -e /versionpress/versionpress.php ] && [ ! -L $WP_CONTENT_DIR/plugins/versionpress ]; then
      echo >&2 "Copying versionpress via mounted volume..."
      ln -s /versionpress/ $WP_CONTENT_DIR/plugins/versionpress
    else
      echo >&2 "Copying versionpress via embedded src..."
      tar cf - --one-file-system -C /usr/src/versionpress . | tar xf - -C $WP_CONTENT_DIR/plugins
    fi

    echo >&2 "Complete! VersionPress has been successfully copied to $WP_CONTENT_DIR/plugins/versionpress"
    chown -R www-data:www-data $WP_CONTENT_DIR/plugins/versionpress
  fi

  # TODO handle WordPress upgrades magically in the same way, but only if wp-includes/version.php's $wp_version is less than /usr/src/wordpress/wp-includes/version.php's $wp_version

  # version 4.4.1 decided to switch to windows line endings, that breaks our seds and awks
  # https://github.com/docker-library/wordpress/issues/116
  # https://github.com/WordPress/WordPress/commit/1acedc542fba2482bab88ec70d4bea4b997a92e4
  sed -ri 's/\r\n|\r/\n/g' $WP_DIR/wp-config*

  if [ ! -e $WP_CONFIG ]; then
    awk '/^\/\*.*stop editing.*\*\/$/ && c == 0 { c = 1; system("cat") } { print }' $WP_CONFIG_SAMPLE > $WP_CONFIG <<'EOPHP'
// If we're behind a proxy server and using HTTPS, we need to alert Wordpress of that fact
// see also http://codex.wordpress.org/Administration_Over_SSL#Using_a_Reverse_Proxy
if (isset($_SERVER['HTTP_X_FORWARDED_PROTO']) && $_SERVER['HTTP_X_FORWARDED_PROTO'] === 'https') {
  $_SERVER['HTTPS'] = 'on';
}

EOPHP
    chown www-data:www-data $WP_CONFIG
  fi

  # see http://stackoverflow.com/a/2705678/433558
  sed_escape_lhs() {
    echo "$@" | sed 's/[]\/$*.^|[]/\\&/g'
  }
  sed_escape_rhs() {
    echo "$@" | sed 's/[\/&]/\\&/g'
  }
  php_escape() {
    php -r 'var_export(('$2') $argv[1]);' "$1"
  }
  set_config() {
    key="$1"
    value="$2"
    configfile="$3"
    var_type="${4:-string}"
    start="(['\"])$(sed_escape_lhs "$key")\2\s*,"
    end="\);"
    if [ "${key:0:1}" = '$' ]; then
      start="^(\s*)$(sed_escape_lhs "$key")\s*="
      end=";"
    fi
    sed -ri "s/($start\s*).*($end.+?)$/\1$(sed_escape_rhs "$(php_escape "$value" "$var_type")")\3/" $configfile
  }

  set_config 'DB_HOST' "$WORDPRESS_DB_HOST" $WP_CONFIG
  set_config 'DB_USER' "$WORDPRESS_DB_USER" $WP_CONFIG
  set_config 'DB_PASSWORD' "$WORDPRESS_DB_PASSWORD" $WP_CONFIG
  set_config 'DB_NAME' "$WORDPRESS_DB_NAME" $WP_CONFIG

  # allow any of these "Authentication Unique Keys and Salts." to be specified via
  # environment variables with a "WORDPRESS_" prefix (ie, "WORDPRESS_AUTH_KEY")
  UNIQUES=(
    AUTH_KEY
    SECURE_AUTH_KEY
    LOGGED_IN_KEY
    NONCE_KEY
    AUTH_SALT
    SECURE_AUTH_SALT
    LOGGED_IN_SALT
    NONCE_SALT
  )
  for unique in "${UNIQUES[@]}"; do
    eval unique_value=\$WORDPRESS_$unique
    if [ "$unique_value" ]; then
      set_config "$unique" "$unique_value" $PROJECT_DIR/wp-config.php
    else
      # if not specified, let's generate a random value
      current_set="$(sed -rn "s/define\((([\'\"])$unique\2\s*,\s*)(['\"])(.*)\3\);/\4/p" $PROJECT_DIR/wp-config.php)"
      if [ "$current_set" = 'put your unique phrase here' ]; then
        set_config "$unique" "$(head -c1M /dev/urandom | sha1sum | cut -d' ' -f1)" $PROJECT_DIR/wp-config.php
      fi
    fi
  done

  if [ "$WORDPRESS_TABLE_PREFIX" ]; then
    set_config '$table_prefix' "$WORDPRESS_TABLE_PREFIX" $WP_CONFIG
  fi

  if [ "$WORDPRESS_DEBUG" ]; then
    set_config 'WP_DEBUG' 1 $WP_CONFIG boolean
  fi

  TERM=dumb php -- "$WORDPRESS_DB_HOST" "$WORDPRESS_DB_USER" "$WORDPRESS_DB_PASSWORD" "$WORDPRESS_DB_NAME" <<'EOPHP'
<?php
// database might not exist, so let's try creating it (just to be safe)

$stderr = fopen('php://stderr', 'w');

list($host, $port) = explode(':', $argv[1], 2);

$maxTries = 10;
do {
  $mysql = new mysqli($host, $argv[2], $argv[3], '', (int)$port);
  if ($mysql->connect_error) {
    fwrite($stderr, "\n" . 'MySQL Connection Error: (' . $mysql->connect_errno . ') ' . $mysql->connect_error . "\n");
    --$maxTries;
    if ($maxTries <= 0) {
      exit(1);
    }
    sleep(3);
  }
} while ($mysql->connect_error);

if (!$mysql->query('CREATE DATABASE IF NOT EXISTS `' . $mysql->real_escape_string($argv[4]) . '`')) {
  fwrite($stderr, "\n" . 'MySQL "CREATE DATABASE" Error: ' . $mysql->error . "\n");
  $mysql->close();
  exit(1);
}

$mysql->close();
EOPHP
fi

exec "$@"
