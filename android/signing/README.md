# Signing

`upload_certificate.pem` is the **public** certificate of the upload key, and
is committed on purpose. A certificate is the public half of a key pair: it
identifies the signer and verifies signatures, and it can do nothing on its
own. Play App Signing enrols it at the first upload, and having it in the
repository means that enrolment does not depend on anyone's laptop.

The private key it belongs to is **not** here and never will be. It lives at
`~/HonestArcadeApps/secrets/solitaire-upload.keystore`, outside this
repository, and `.gitignore` refuses every extension it could arrive under.
See `.n8/memory/android-signing.md` for the procedure and the rotation runbook.

## What this certificate is

| | |
|---|---|
| alias | `upload` |
| owner | `O=Honest Arcade, CN=Honest Solitaire` |
| SHA-256 | `61:EE:ED:0C:24:86:2E:3C:6D:3D:1D:95:64:56:A7:70:10:EA:08:F2:35:CB:3F:A2:EE:96:7E:5F:9D:E9:8D:30` |

The release build signs **by alias**, so `HS_KEY_ALIAS` must be `upload`.

## Check that a bundle was signed with this key

```sh
tools/verify_upload_cert.sh
```

It compares the bundle's fingerprint with the PEM above and exits 0 on a
match, 1 on a mismatch printing both, 2 for a missing input and 3 when
`keytool` cannot be found.
