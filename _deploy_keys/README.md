# Deploy Keys for CI/CD

This directory contains the keys for CI/CD.  These
keys are applied at the repo level allowing Read Only access
to the source repositories for building.  These are used by
Docker container and by the CI/CD process.

To enable a GitLab dependent repo add this public key to 
`Settings -> Repository ->Deploy Keys`.  You may just need
to enable the key as it has already been added to GitLab.