#!/usr/bin/env python3
import os
import smtplib
from email.mime.text import MIMEText

from dotenv import load_dotenv

load_dotenv()

EMAIL_BODY="THIS WORKS!"
SMTP_HOST = os.getenv("IMPROVMX_SMTP_HOST", "smtp.improvmx.com")
SMTP_PORT = int(os.getenv("IMPROVMX_SMTP_PORT", "587"))
SMTP_USER = os.getenv("IMPROVMX_SMTP_USER")
SMTP_PASS = os.getenv("IMPROVMX_SMTP_PASS")
SMTP_STARTTLS = os.getenv("IMPROVMX_SMTP_STARTTLS", "true").lower() == "true"

TO_EMAIL = os.getenv("IMPROVMX_SMTP_TO", SMTP_USER)
FROM_EMAIL = os.getenv("IMPROVMX_SMTP_FROM", SMTP_USER)

if not SMTP_USER or not SMTP_PASS:
    raise SystemExit("Set IMPROVMX_SMTP_USER and IMPROVMX_SMTP_PASS env vars.")

msg = MIMEText(EMAIL_BODY)
msg["Subject"] = "SMTP test (Improvmx)"
msg["From"] = FROM_EMAIL
msg["To"] = TO_EMAIL

try:
    with smtplib.SMTP(SMTP_HOST, SMTP_PORT, timeout=20) as server:
        server.ehlo()
        if SMTP_STARTTLS:
            server.starttls()
            server.ehlo()
        server.login(SMTP_USER, SMTP_PASS)
        server.send_message(msg)
    print(EMAIL_BODY)
except smtplib.SMTPAuthenticationError as exc:
    raise SystemExit(f"SMTP auth failed: {exc}") from exc
except smtplib.SMTPException as exc:
    raise SystemExit(f"SMTP error: {exc}") from exc
except OSError as exc:
    raise SystemExit(f"Network error: {exc}") from exc
