#!/usr/bin/env python3

# (ChatGPT generated) Utility to send emails to a sr.ht-container-compose list or todo.
#
# The script automatically picks the right port (on 127.0.0.1) from the destination
# domain (lists.sr.ht for lists, todo.sr.ht for todos).
#
# Example usages:
#  - Send a message to list "~root/super-list"
#      ./contrib/send_email.py --to '~root/super-list@lists.sr.ht' --subject="Salut les loulous" \
#                              --body="Incroyable message..."
#  - Ingest all the messages in mbox simartin-aerc-devel.mbox to list "~root/super-list"
#      ./contrib/send_email.py --to '~root/super-list@lists.sr.ht' \
#                              --mbox-file=simartin-aerc-devel.mbox --mbox-index=ALL
#  - Create a new ticket in todo "~root/super-todo":
#      ./contrib/send_email.py --to '~root/super-todo@todo.sr.ht' --subject="That's a great ticket" \
#                              --body="With an incredible description"
#  - Update ticket #3 in todo "~root/super-todo":
#      ./contrib/send_email.py --to '~root/super-todo/3@todo.sr.ht' --subject="Does not matter" \
#                              --body="Such an awesome update"

import argparse
import smtplib
import uuid
import mailbox
from email.message import EmailMessage
from datetime import datetime

# Domain-to-port mapping
DOMAIN_PORT_MAP = {
    "lists.sr.ht": 5906,
    "todo.sr.ht": 5903,
}

def extract_domain(email_address):
    return email_address.split("@")[-1].lower()

def read_body(args, fallback_body=None):
    if args.body:
        return args.body
    elif fallback_body:
        return fallback_body
    else:
        return "This is the body of the email."

def apply_headers(msg: EmailMessage, header_list):
    for header in header_list or []:
        if ":" not in header:
            print(f"⚠️  Skipping invalid header format: {header}")
            continue
        name, value = header.split(":", 1)
        msg[name.strip()] = value.strip()

def override_fields(msg: EmailMessage, original, args):
    msg["From"] = args.from_addr if args.from_addr else original["From"] or "send_email.py@localhost"
    msg["To"] = args.to_addr if args.to_addr else original["To"]
    msg["Subject"] = args.subject if args.subject else original["Subject"]
    msg["Message-ID"] = args.message_id if args.message_id else original["Message-ID"] or f"<{uuid.uuid4()}@localhost>"
    msg["Date"] = original["Date"] or datetime.utcnow().strftime('%a, %d %b %Y %H:%M:%S +0000')

    if args.in_reply_to:
        msg["In-Reply-To"] = args.in_reply_to
    elif original.get("In-Reply-To"):
        msg["In-Reply-To"] = original["In-Reply-To"]

    fallback_body = original.get_payload(decode=True)
    charset = original.get_content_charset() or "utf-8"
    if fallback_body:
        try:
            fallback_body = fallback_body.decode(charset)
        except Exception:
            fallback_body = "Failed to decode original body."

    msg.set_content(read_body(args, fallback_body=fallback_body))

    apply_headers(msg, args.header)
    return msg

def build_message_from_mbox_entry(original, args):
    msg = EmailMessage()
    return override_fields(msg, original, args)

def build_message_from_args(args):
    domain = extract_domain(args.to_addr)
    msg = EmailMessage()
    msg["From"] = args.from_addr or "send_email.py@localhost"
    msg["To"] = args.to_addr
    msg["Subject"] = args.subject
    msg["Date"] = datetime.utcnow().strftime('%a, %d %b %Y %H:%M:%S +0000')
    msg["Message-ID"] = args.message_id if args.message_id else f"<{uuid.uuid4()}@{domain}>"

    if args.in_reply_to:
        msg["In-Reply-To"] = args.in_reply_to

    msg.set_content(read_body(args))
    apply_headers(msg, args.header)
    return msg

def send_email(msg: EmailMessage):
    to_addr = msg["To"]
    domain = extract_domain(to_addr)
    port = DOMAIN_PORT_MAP.get(domain)

    if not port:
        print(f"❌ Domain '{domain}' not found in domain-port mapping.")
        return

    try:
        with smtplib.SMTP("127.0.0.1", port) as server:
            server.send_message(msg)
            print(f"✅ Email sent to {to_addr} via 127.0.0.1:{port}")
    except Exception as e:
        print(f"❌ Failed to send email to {to_addr}: {e}")

def main():
    parser = argparse.ArgumentParser(description="Send email via localhost SMTP based on domain-port map.")
    parser.add_argument("--from", dest="from_addr", help="From email address (default is send_email.py@localhost)")
    parser.add_argument("--to", dest="to_addr", help="To email address (required if not using --mbox-file)")
    parser.add_argument("--subject", help="Email subject (required if not using --mbox-file)")
    parser.add_argument("--message-id", help="Optional Message-ID header")
    parser.add_argument("--in-reply-to", help="Optional In-Reply-To header")
    parser.add_argument("--mbox-file", help="Path to mbox file containing the message(s)")
    parser.add_argument("--mbox-index", help="Use 'ALL' to send all messages or N (0-based) for the Nth message")
    parser.add_argument("--body", help="Raw email body as a string")
    parser.add_argument("--header", action="append", help="Add arbitrary header in 'Name: value' format (can be used multiple times)")

    args = parser.parse_args()

    if args.mbox_file:
        try:
            mbox = mailbox.mbox(args.mbox_file)
            mbox_len = len(mbox)

            if mbox_len == 0:
                print("❌ No messages found in the mbox file.")
                return

            if args.mbox_index is None:
                msg = build_message_from_mbox_entry(mbox[0], args)
                send_email(msg)

            elif args.mbox_index.upper() == "ALL":
                for i, original in enumerate(mbox):
                    print(f"📤 Sending message {i + 1}/{mbox_len}...")
                    msg = build_message_from_mbox_entry(original, args)
                    send_email(msg)
            else:
                try:
                    index = int(args.mbox_index)
                    if index < 0 or index >= mbox_len:
                        print(f"❌ Invalid mbox index {index}. File contains {mbox_len} messages.")
                        return
                    msg = build_message_from_mbox_entry(mbox[index], args)
                    send_email(msg)
                except ValueError:
                    print(f"❌ Invalid mbox index value: {args.mbox_index}. Use an integer or 'ALL'.")
                    return

        except Exception as e:
            print(f"❌ Failed to process mbox file: {e}")
            return

    else:
        if not args.to_addr or not args.subject:
            print("❌ Missing required arguments (--to, --subject) if --mbox-file is not provided.")
            return

        try:
            msg = build_message_from_args(args)
            send_email(msg)
        except Exception as e:
            print(f"❌ Failed to build or send message: {e}")

if __name__ == "__main__":
    main()
