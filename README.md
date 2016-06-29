# Supported tags and respective `Dockerfile` links

* `1.8.1`, `latest` [(1.8.1/Dockerfile)](1.8.1/Dockerfile)
* `1.8.1-skeleton`, `skeleton` [(1.8.1/skeleton/Dockerfile)](1.8.1/skeleton/Dockerfile)

# Docker VersionPress

This docker image is simply an official WordPress image with wp-cli and versionpress support.

## Environment Variables

The following environments are added to this image. See the [official wordpress image](https://hub.docker.com/_/wordpress/) for additional options:

- `WORDPRESS_OPCACHE` - Set to `on` or `off` to toggle PHP opcaching (defaults to `off`)
