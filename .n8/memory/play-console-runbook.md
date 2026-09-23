# Play Console runbook — click by click

Generalized from Honest Sudoku's own launch, the first app built on this
template. Everything the owner must do by hand is marked *(owner)*;
everything a session running this template's tools can do is marked
*(agent)*. Where a value is fixed by this template's own scripts, it is
given as the variable name (`$APP_SLUG`, `$APP_PACKAGE_ID`) rather than a
literal — fill those in for your app before following the steps.

The Console steps are not automatable — there is no API for them. Every
agent-side step below is a script this template ships, already tested
against a real Play account and a real release.

---

## Before you start

You need a **Google Play developer account**. If you don't have one, that's
the real blocker for everything below:

- <https://play.google.com/console/signup>
- One-off **$25** registration fee; a personal account is fine to start.
- Identity verification can take a few days. Nothing else here works until
  it completes — start it first if it isn't already done.

---

## Step 1 — Create the app entry *(owner, ~2 minutes)*

Play Console → **All apps** → **Create app**.

| Field | Value |
|---|---|
| App name | your app's display name |
| Package name | `$APP_PACKAGE_ID` (e.g. `com.honestarcade.solitaire`) |
| Default language | your call |
| App or game | your call |
| Free or paid | your call |
| Declarations | tick both (Developer Program Policies; US export laws) |

Click **Check availability** under the package name before continuing. It
must come back available — the string is a one-time, permanent choice, and
a typo here cannot be corrected later, only abandoned along with the app
entry.

Then **Create app**.

> Copy `$APP_PACKAGE_ID` rather than retyping it. It must match
> `applicationId` in `android/app/build.gradle.kts` exactly — the release
> upload is rejected outright if the two differ, and `tools/check_aab.sh`
> asserts the same value against the built bundle.

**Record two things**, in `.n8/memory/play-console.md` (create it from this
template's shape, or start one): the **app id** and the **developer id**,
both visible in the Console URL while the app is open
(`.../developers/<developer-id>/app/<app-id>/...`). Neither is a secret.

---

## Step 2 — Sign in to Google Cloud *(owner, ~1 minute)*

```
gcloud auth login
```

A browser opens. **Sign in with the same Google account that owns the Play
Console**, or the service account lands under the wrong account and the
invite in step 4 won't find it.

`tools/setup_play_ci.sh` prints the account it found and asks you to
confirm before creating anything, so a wrong login is caught rather than
silently used.

---

## Step 3 — Create the service account *(agent, ~1 minute)*

Run `tools/setup_play_ci.sh` (needs `HS_APP_SLUG` and `HS_APP_DISPLAY_NAME`
set, or its defaults edited). It is idempotent and grants **no IAM roles**.

It creates a Cloud project and service account named after `$APP_SLUG`, and
the `PLAY_SERVICE_ACCOUNT_JSON` repository secret. The key is written with
`umask 077`, uploaded, and deleted through a shell `trap` so it never
survives a failure. It prints the key's **id** — public, and what you'd
need later to revoke the right key — and never the key itself.

---

## Step 4 — Invite the service account *(owner, ~3 minutes)*

Play Console → **Users and permissions** → **Invite new users**.

| Field | Value |
|---|---|
| Email address | the service account email `tools/setup_play_ci.sh` printed |
| Account permissions | **none** — leave every box unticked |

Then **Add app** → select your app → grant exactly these two, and nothing
else:

- ☑ **Release to testing tracks**
- ☑ **View app information and download bulk reports**

Explicitly **not**:

- ☐ Release to production, exclude devices, and use Play App Signing
- ☐ Manage store presence
- ☐ Manage orders and subscriptions

Then **Apply** in the app dialog, and then **Save changes** at the bottom
of the page. Both are required and the second is easy to miss: the summary
screen looks the same either way, and an account saved with no app
permissions gets `403 PERMISSION_DENIED` from every API call, permanently.
That is not a propagation delay, and waiting will not fix it — this was
observed for real during Honest Sudoku's own launch.

**Send invitation.** A service account needs no inbox — there is nothing to
accept — but it is only usable once the page has actually been saved.

To tell the two apart when a later API call returns 403: open the account
and look at its **App permissions** tab. Empty means the save didn't
happen; your app with two permissions means wait and retry.

> This permission set is why the promote workflow cannot reach production
> even if every code-level barrier failed. It is the one control that does
> not live in the repository, which is why the repository has its own too
> (see `tools/play_promote.sh`'s refusal of the `production` track).

---

## Step 5 — Set the signing secrets *(agent, ~1 minute, needs your go-ahead)*

Run `tools/set_ci_secrets.sh` (needs `HS_APP_SLUG` and `HS_REPO` set), which
reads `~/HonestArcadeApps/secrets/$APP_SLUG-signing-credentials.txt` (written
by `tools/make_upload_key.sh` — run that first if you haven't) and sets four
repository secrets: `HS_KEYSTORE_B64`, `HS_KEYSTORE_PASS`, `HS_KEY_ALIAS`,
`HS_KEY_PASS`.

Do this deliberately, not automatically-in-passing: it's the moment your
real keystore password moves into a repository secret. The script parses
the credentials file rather than sourcing it, verifies the password and
alias actually open the keystore before uploading anything, and prints only
the secret names.

---

## Step 6 — Prove it works *(agent, ~2 minutes)*

Dispatch `.github/workflows/play-api-check.yml`. It opens and deletes a
throwaway edit, lists the tracks, and checks the keystore secrets. It
publishes nothing and changes nothing on Play.

A brand-new app has no tracks yet; that's a pass, and the summary says so.

Expected afterwards: `gh secret list` shows five secrets, and that run is
green.

---

## Step 7 — The first release *(agent, after 1–6)*

Push a version tag (`v0.1.0` or similar). The tag runs the full PR gate
again, builds a signed bundle, scans it for Android permissions, checks it
against the committed upload certificate, and uploads to the **internal**
track.

Play App Signing is enrolled by that first upload. After it, the upload key
cannot be regenerated — only reset through the Console — which is why
`tools/make_upload_key.sh` refuses to overwrite either of its outputs.

---

## The draft-app rule

Until an app's first release is **published**, Play refuses a `completed`
release on any testing track outside `internal`. `tools/play_promote.sh`
retries as a `draft` release **only when the API's response names that rule
exactly** — a 4xx status whose message contains the specific phrase, not
merely a status code, and not merely a message that mentions "draft" for an
unrelated reason. It says so on stderr rather than substituting silently.

Any other refusal — a 403, a quota error, a 5xx, a near-miss message — fails
the run with the response that caused it. A looser match here is a real
defect class: it turns a permission denial into a false "promoted as draft"
success. If you extend `is_draft_app_rule()` in `tools/play_promote.sh`,
extend its test coverage in the same change — the exact-phrase requirement
existed for a full round in Honest Sudoku's own history before anything
tested the requirement itself, rather than just the rule it replaced.

---

## Taking it out of draft, and to production

Two more things this template's scripts do NOT do, deliberately, matching
the division of labour above:

1. **Publishing the app out of draft** is a Console act (Store presence →
   set up the required listing details, then publish the release). Nothing
   in `tools/` or `.github/workflows/` performs it, and `play_promote.sh`
   explicitly refuses the `production` track before any API call — twice,
   once in the workflow's own input validation and once in the script.
2. **Production access on a personal developer account** requires a closed
   test with at least 12 testers, for 14 **continuous** days. Whether Play
   counts those days per-tester or across the whole cohort was never
   confirmed by Honest Sudoku's own launch — work to the **stricter**
   reading regardless: keep at least twelve testers enrolled continuously
   for the entire window, and treat any dip below twelve as restarting the
   clock. It satisfies either reading.

Both are the owner's to perform in the Console; an agent session can
prepare exact values (store listing text, content ratings answers, the
promote dispatch that moves a build between testing tracks) but not click
through either gate.
