#!/bin/bash -ex

##########################
## To run on the server ##
##########################

# We expect the following arguments
#
#   domain                   Which site we are deploying
#   repo                     Name of ComputerMinds guthub repo holding fully
#                            built drupal site.
#   <gitref>                 Of commit to deploy
#   'reinstall' (optional)   Forces a destructive re-installation.

DOMAIN="$1"
REPO_NAME="$2"
GIT_REF="$3"
REINSTALL="$4"

# This script requires the following about the server:
#
#  1. The site you are deploying *already* exists. This script can only migrate
#     not deploy-from-scratch (a future job perhaps),
#
#  2. The site we are deploying is already fully installed and generally works,
#
#  3. The site is installed in the following place:
#
#       /var/www-builds/SOMEFOLDERNAME
#
#     which is symlinked to from /var/www as follows:
#
#       /var/www/DOMAIN -> /var/www-builds/SOMEFOLDERNAME
#
#  4. That drush is installed and usable by the user running this script.
#
#  5. That there is already a drush alias defined for @DOMAIN, i.e:
#
#       drush @DOMAIN status  # <-- This needs to work
#
#     This might be achieved by adding the following config:
#
#       $ cat /etc/drush/aliases.drushrc.php
#
#         <?php
#
#         $aliases['DOMAIN'] = array(
#           'uri' => 'DOMAIN',
#           'root' => '/var/www/DOMAIN',
#         );
#
#  6. That the sites directory for the site is called DOMAIN, i.e:
#
#       /var/www/DOMAIN/sites/DOMAIN
#
#  7. That the various Drupal files directories are in the following locations:
#
#       public:    /var/www/DOMAIN/sites/DOMAIN/files
#       private:   /var/www/DOMAIN/sites/DOMAIN/private/files
#       temporary: /var/www/DOMAIN/sites/DOMAIN/private/temp
#
#     To ensure that these are always defined this way, even on fresh installs,
#     we recommend that you add the following lines in your settings.php:
#
#       <?php
#         $conf['file_public_path'] = 'sites/DOMAIN/files';
#         $conf['file_private_path'] = 'sites/DOMAIN/private/files';
#         $conf['file_temporary_path'] = 'sites/DOMAIN/private/temp';
#

LIVE_DIR="/var/www/$DOMAIN"
SITES_DIR="$DOMAIN"

# Create new directory to build site into.
cd /var/www-builds
BUILD_DIR=`mktemp -dt "$DOMAIN-XXXXXXXXXX" --tmpdir="/var/www-builds"`
chmod 755 "$BUILD_DIR"

cd "$BUILD_DIR"

# Pull fully built drupal in.
git init
git remote add origin "git@github.com:computerminds/$REPO_NAME"
git fetch origin "$GIT_REF"
git reset --hard FETCH_HEAD

# Copy sites directory across.
cp -R "$LIVE_DIR/sites/$SITES_DIR" "sites/$SITES_DIR"
chown -R www-data:www-data "sites/$SITES_DIR/files"
chown -R www-data:www-data "sites/$SITES_DIR/private/files"
chown -R www-data:www-data "sites/$SITES_DIR/private/temp"

# Flip symlink to new build
OLDBUILD=`readlink "$LIVE_DIR"`
rm "$LIVE_DIR" && ln -s "$BUILD_DIR" "$LIVE_DIR"

# Either re-install or run updates
if [[ "$REINSTALL" == "reinstall" ]]
then
  # Clear out files first.
  rm -rf "sites/$SITES_DIR/files/*"
  rm -rf "sites/$SITES_DIR/private/files/*"
  rm -rf "sites/$SITES_DIR/private/temp/*"
  drush "@$DOMAIN" si --site-name="Training" --account-pass="admin" -y
else
  drush "@$DOMAIN" updb -y
  drush "@$DOMAIN" fra -y
  drush "@$DOMAIN" cc all
fi

service varnish-drupal restart || true

# Delete old build
rm -rf "$OLDBUILD"
