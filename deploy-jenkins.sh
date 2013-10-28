#!/bin/bash

###############################
## To run on the jenkins box ##
###############################

# We expect the following arguments
#
#   domain                   Which site we are deploying
#   repo                     Name of ComputerMinds guthub repo holding fully
#                            built drupal site.
#   <gitref>                 Of commit to deploy
#   'reinstall' (optional)   Forces a destructive re-installation.

# Assume we have already checked out our deploy-server.sh script on the server.
# Also assume that jenkins has been set up with public/private key auth.
ssh root@162.13.146.249 "/root/spire_build_scripts/deploy-server.sh $1 $2 $3 $4"
