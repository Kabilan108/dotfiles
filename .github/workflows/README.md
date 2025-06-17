# gh actions

- `deploy.yml` - deploys the server using `deploy-rs`
  - set the following env variables:
    - `DEPLOY_SSH_KEY` - the ssh private key to use for the deployment
    - `DEPLOY_HOST` - the hostname of the server to deploy to

**reminder:** `gh secret set <ENV_VAR>`
