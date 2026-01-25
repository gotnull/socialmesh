#!/usr/bin/env python3
import os
import smtplib
from email.mime.text import MIMEText

from dotenv import load_dotenv

load_dotenv()

SMTP_HOST = os.getenv("SMTP_HOST", "smtp.gmail.com")
SMTP_PORT = int(os.getenv("SMTP_PORT", "465"))
SMTP_USER = os.getenv("SMTP_USER")  # e.g. your@gmail.com
SMTP_PASS = os.getenv("SMTP_PASS")  # app password

TO_EMAIL = os.getenv("SMTP_TO", SMTP_USER)
FROM_EMAIL = os.getenv("SMTP_FROM", SMTP_USER)

if not SMTP_USER or not SMTP_PASS:
    raise SystemExit("Set SMTP_USER and SMTP_PASS env vars.")

msg = MIMEText("SMTP test from Socialmesh functions config.")
msg["Subject"] = "SMTP test"
msg["From"] = FROM_EMAIL
msg["To"] = TO_EMAIL

with smtplib.SMTP_SSL(SMTP_HOST, SMTP_PORT) as server:
    server.login(SMTP_USER, SMTP_PASS)
    server.send_message(msg)

print("SMTP test sent.")
