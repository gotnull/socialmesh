Resend unsent bug report emails (GitHub Action)

This workflow runs daily and can also be triggered manually. It finds `bugReports` documents that have not been emailed and resends them using ImprovMX SMTP.

Required GitHub Secrets
- `GCP_SA_KEY` (optional but recommended): JSON contents of a GCP service account key with `cloud-platform` and Firestore read/write access. If present, the workflow will write it to a temporary file and set `GOOGLE_APPLICATION_CREDENTIALS`.
- `IMPROVMX_SMTP_USER`: ImprovMX SMTP username (required if you want the workflow to send emails).
- `IMPROVMX_SMTP_PASS`: ImprovMX SMTP password (required).
- `IMPROVMX_SMTP_FROM` (optional): From address to use. Defaults to `IMPROVMX_SMTP_USER`.
- `IMPROVMX_SMTP_TO` (optional): Override recipient address (useful for testing).

Notes
- The workflow runs the `scripts/resend_unsent_reports.py --send --yes` command in non-interactive mode.
- Keep secrets scoped to the repository or an appropriate organization secret for security.
- You can manually run the workflow from the Actions tab ("Run workflow").
