# Run Environment Config And Secrets

> See [Guide Usage](../README.md) for how to use these guides.

An environment is the final layer: every token in its manifests must resolve.

* **Config** goes in `src/config/`, one file per token, the file name being
  the token name (`src/config/DatabaseHost`, or nested as
  `src/config/Vendor/DbHost`). Values override the defaults its children ship.
* **Secrets** go in `src/secrets/`, encrypted (`kaptain encrypt`), named after
  the token (`src/secrets/DbPassword.age`). They are only decrypted at deploy
  time, into the `*.template.yaml` Secrets that reference them. Every
  secret-template token needs an encrypted value or the build fails.
* **Image pull secrets** are generated for each registry an `imagePullSecrets`
  entry names. Supply their credentials as
  `src/secrets/ImagePullSecrets/<Registry>/Username.age` and `Password.age`,
  where `<Registry>` is the hostname in the token name style (`ghcr.io` is
  `GhcrIo`).
* **Unused values fail the build** unless `failOnUnreferencedConfigOrSecrets`
  is false.

Secrets for the environment's own deploy image, such as its
`EnvironmentPassphrase`, belong to the run platform that deploys it, not here.
