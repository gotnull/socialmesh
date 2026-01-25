#!/usr/bin/env python3
"""
Resend unsent bug report emails using local SMTP credentials (IMPROVMX).
Usage:
  python3 scripts/resend_unsent_reports.py [--days N] [--send]

- Default behavior: dry-run (shows unsent reports in last 7 days).
- Pass --send to actually send emails (will prompt for confirmation).

Notes:
- Requires GOOGLE_APPLICATION_CREDENTIALS set or ADC available to access Firestore.
- Requires IMPROVMX_SMTP_USER and IMPROVMX_SMTP_PASS in environment or .env.
- Installs: pip install google-cloud-firestore python-dotenv
"""

import os
import sys
import smtplib
import html as _html
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from datetime import datetime, timedelta
import argparse
import textwrap

try:
    from dotenv import load_dotenv
    from google.cloud import firestore
except Exception as e:
    print("Missing dependency:", e)
    print("Install with: pip install google-cloud-firestore python-dotenv")
    sys.exit(1)

load_dotenv()

SMTP_HOST = os.getenv("IMPROVMX_SMTP_HOST", "smtp.improvmx.com")
SMTP_PORT = int(os.getenv("IMPROVMX_SMTP_PORT", "587"))
SMTP_USER = os.getenv("IMPROVMX_SMTP_USER")
SMTP_PASS = os.getenv("IMPROVMX_SMTP_PASS")
SMTP_STARTTLS = os.getenv("IMPROVMX_SMTP_STARTTLS", "true").lower() == "true"
FROM_EMAIL = os.getenv("IMPROVMX_SMTP_FROM", SMTP_USER)
TO_OVERRIDE = os.getenv("IMPROVMX_SMTP_TO")  # optional override

if not SMTP_USER or not SMTP_PASS:
    print("Warning: IMPROVMX_SMTP_USER or IMPROVMX_SMTP_PASS missing in environment. You can still run dry-run to list reports.")

parser = argparse.ArgumentParser(description="Resend unsent bug report emails")
parser.add_argument("--days", type=int, default=7, help="how many days back to look (default 7)")
parser.add_argument("--send", action="store_true", help="actually send emails (default is dry-run)")
parser.add_argument("--yes", "-y", action="store_true", help="non-interactive confirmation for --send (use in CI)")
parser.add_argument("--id", type=str, help="optional single bug report ID to resend")
args = parser.parse_args()

# Initialize Firestore
try:
    db = firestore.Client()
except Exception as e:
    print("Failed to initialize Firestore client. Make sure GOOGLE_APPLICATION_CREDENTIALS is set or ADC is available.")
    print(e)
    sys.exit(1)

cutoff = datetime.utcnow() - timedelta(days=args.days)
print(f"Querying bugReports since {cutoff.isoformat()} UTC\n")

unsent = []
if args.id:
    doc = db.collection('bugReports').document(args.id).get()
    if not doc.exists:
        print(f"Report with ID {args.id} not found.")
        sys.exit(1)
    data = doc.to_dict()
    if data.get('emailSent') is True:
        print(f"Report {args.id} already marked as emailed.")
        sys.exit(0)
    unsent.append((doc.id, data))
else:
    q = db.collection('bugReports').where('createdAt', '>', cutoff).order_by('createdAt', direction=firestore.Query.ASCENDING)
    for doc in q.stream():
        data = doc.to_dict()
        # Consider emailSent true only if explicitly True
        if data.get('emailSent') is True:
            continue
        unsent.append((doc.id, data))

if not unsent:
    print("No unsent reports found in the time window.")
    sys.exit(0)

print(f"Found {len(unsent)} unsent reports:\n")
for i, (docid, data) in enumerate(unsent, start=1):
    print(f"{i}. ID: {docid}")
    print(f"   createdAt: {data.get('createdAt')}")
    print(f"   email: {data.get('email')}")
    desc = data.get('description', '')
    desc_sanitized = desc[:120].replace("\n", " ")
    desc_suffix = '...' if len(desc) > 120 else ''
    print(f"   description: {desc_sanitized}{desc_suffix}")
    print(f"   screenshot: {data.get('screenshotUrl')}")
    print(f"   emailError: {data.get('emailError')}")
    print()

if not args.send:
    print("Dry-run complete. Re-run with --send to actually attempt to send emails from this machine.")
    sys.exit(0)

# Confirmation (non-interactive allowed with --yes or CI env)
if args.yes or os.getenv('CI') == 'true':
    confirmed = True
else:
    ans = input("Proceed to send these emails now from THIS machine? (type YES): ")
    confirmed = ans.strip() == 'YES'
if not confirmed:
    print("Aborted by user.")
    sys.exit(0)


def build_bug_report_email_html(report_id, data):
    escape = _html.escape
    reportId = escape(report_id)
    userEmail = escape(data.get('email') or '')
    userId = escape(data.get('userId') or '')
    appVersion = escape(data.get('appVersion') or '')
    buildNumber = escape(str(data.get('buildNumber') or ''))
    platform = escape(data.get('platform') or '')
    description = escape(data.get('description') or '').replace('\n', '<br>')
    screenshot = escape(data.get('screenshotUrl') or '') or None

    html = f"""
    <div style="margin:0;padding:0;background:#0f1420;color:#e8edf7;font-family:Inter,Arial,sans-serif;">
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="border-collapse:collapse;">
        <tr>
          <td align="center" style="padding:32px 16px;">
            <table role="presentation" width="600" cellpadding="0" cellspacing="0" style="width:100%;max-width:600px;border-collapse:collapse;">
              <tr>
                <td style="padding:0 0 16px 0;">
                  <div style="font-size:20px;font-weight:700;letter-spacing:0.2px;">Socialmesh</div>
                  <div style="color:#98a2b3;font-size:13px;margin-top:4px;">Bug report</div>
                </td>
              </tr>
              <tr>
                <td style="background:#151b2b;border:1px solid #2a3245;border-radius:16px;padding:20px;">
                  <div style="display:inline-block;padding:6px 12px;border-radius:999px;background:linear-gradient(90deg,#ff2d95,#ff6a3d);color:#ffffff;font-size:12px;font-weight:700;letter-spacing:0.4px;text-transform:uppercase;">
                    Report {reportId}
                  </div>

                  <div style="margin-top:16px;font-size:18px;font-weight:700;">Summary</div>
                  <div style="margin-top:8px;color:#c2c8d6;font-size:14px;line-height:1.5;">{description}</div>

                  <div style="margin-top:18px;padding-top:14px;border-top:1px solid #2a3245;">
                    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="border-collapse:collapse;">
                      <tr>
                        <td style="color:#8b93a7;font-size:12px;padding:4px 0;">User</td>
                        <td style="color:#e8edf7;font-size:12px;padding:4px 0;text-align:right;">{userEmail}</td>
                      </tr>
                      <tr>
                        <td style="color:#8b93a7;font-size:12px;padding:4px 0;">UID</td>
                        <td style="color:#e8edf7;font-size:12px;padding:4px 0;text-align:right;">{userId}</td>
                      </tr>
                      <tr>
                        <td style="color:#8b93a7;font-size:12px;padding:4px 0;">App Version</td>
                        <td style="color:#e8edf7;font-size:12px;padding:4px 0;text-align:right;">{appVersion} ({buildNumber})</td>
                      </tr>
                      <tr>
                        <td style="color:#8b93a7;font-size:12px;padding:4px 0;">Platform</td>
                        <td style="color:#e8edf7;font-size:12px;padding:4px 0;text-align:right;">{platform}</td>
                      </tr>
                      <tr>
                        <td style="color:#8b93a7;font-size:12px;padding:4px 0;">Screenshot</td>
                        <td style="color:#e8edf7;font-size:12px;padding:4px 0;text-align:right;">{('Attached' if screenshot else 'None')}</td>
                      </tr>
                    </table>
                  </div>

                  {f'<div style="margin-top:16px;"><a href="{screenshot}" style="display:inline-block;padding:10px 16px;border-radius:10px;background:linear-gradient(90deg,#ff2d95,#ff6a3d);color:#ffffff;text-decoration:none;font-weight:600;font-size:13px;">View screenshot</a></div><div style="margin-top:12px;"><img src="{screenshot}" alt="Screenshot" style="width:100%;height:auto;border-radius:12px;border:1px solid #2a3245;display:block;"></div>' if screenshot else ''}

                </td>
              </tr>
              <tr>
                <td style="padding:16px 0 0 0;color:#6c7487;font-size:11px;text-align:center;">
                  Socialmesh bug report · support@socialmesh.app
                </td>
              </tr>
            </table>
          </td>
        </tr>
      </table>
    </div>
    """

    return html

# Send loop
for docid, data in unsent:
    to_email = TO_OVERRIDE or data.get('email') or os.getenv('IMPROVMX_SMTP_TO') or SMTP_USER
    subject = f"Bug report {docid}"

    text_body = "\n".join([
        f"Report ID: {docid}",
        f"Reporter email: {data.get('email')}",
        f"App version: {data.get('appVersion')}",
        "",
        data.get('description',''),
        "",
        f"Screenshot: {data.get('screenshotUrl')}",
    ])

    html_body = build_bug_report_email_html(docid, data)

    msg = MIMEMultipart('alternative')
    msg['Subject'] = subject
    msg['From'] = FROM_EMAIL
    msg['To'] = to_email
    msg.attach(MIMEText(text_body, 'plain'))
    msg.attach(MIMEText(html_body, 'html'))

    print(f"Sending {docid} -> {to_email} ... ")
    try:
        with smtplib.SMTP(SMTP_HOST, SMTP_PORT, timeout=30) as server:
            server.ehlo()
            if SMTP_STARTTLS:
                server.starttls()
                server.ehlo()
            server.login(SMTP_USER, SMTP_PASS)
            server.send_message(msg)
        db.collection('bugReports').document(docid).update({
            'emailSent': True,
            'emailSentAt': firestore.SERVER_TIMESTAMP,
            'emailSentMethod': 'improvmx',
            'emailError': firestore.DELETE_FIELD,
        })
        print("  sent OK")
    except Exception as e:
        print("  send failed:", e)
        db.collection('bugReports').document(docid).update({
            'emailSent': False,
            'emailError': str(e),
        })

print("Done.")
