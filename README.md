# Docker VersionPress

This docker imgae is simply an official WordPress image with wp-cli and versionpress support.

To see a full example (complete with starting commands) of a site that uses this docker image, checkout my [VersionPress Skeleton](https://github.com/tatemz/versionpress-skeleton).

**IMPORTANT NOTE**

This image modifies the default wordpress image folder structure to use [Mark Jaquith's WordPress Skeleton](https://github.com/markjaquith/WordPress-Skeleton).

## Environment Variables

The following environments are added to this image. See the [official wordpress image](https://hub.docker.com/_/wordpress/) for additional options:

- `WORDPRESS_OPCACHE` - Set to `on` or `off` to toggle PHP opcaching (defaults to `off`)
- `VERSIONPRESS_VERSION` - Set to a valid VersionPress version (defaults to `3.0.1`).
- `VERSIONPRESS_RESTORE_URL` - Set to a valid VersionPress URL if you would like to restore a site upon installation (defaults to `false`.
