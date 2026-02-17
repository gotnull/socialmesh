#!/usr/bin/env python3
"""
GitHub Copilot Pro+ Usage & Cost Calculator

Calculates your estimated monthly bill based on premium request usage.
Supports both manual percentage input and GitHub API lookups.

Usage:
  # Quick calculation from your settings page percentage
  python3 scripts/copilot_usage.py --percent 423.2

  # Set a monthly budget alert threshold
  python3 scripts/copilot_usage.py --percent 423.2 --budget 100

  # Show daily burn rate and end-of-month projection
  python3 scripts/copilot_usage.py --percent 423.2 --day 17

  # JSON output for piping to other tools
  python3 scripts/copilot_usage.py --percent 423.2 --json

Environment variables:
  GITHUB_TOKEN           GitHub PAT (alternative to --token)
  COPILOT_MONTHLY_BUDGET Budget threshold in USD (alternative to --budget)
"""

import argparse
import json
import os
import sys
from datetime import datetime, timezone
from calendar import monthrange
from typing import Optional

try:
    import urllib.request
    import urllib.error
    HAS_URLLIB = True
except ImportError:
    HAS_URLLIB = False


# ---------------------------------------------------------------------------
# Copilot Pro+ pricing constants (as of February 2026)
# Source: https://docs.github.com/en/copilot/get-started/plans
# ---------------------------------------------------------------------------

PLANS = {
    "free": {
        "name": "Copilot Free",
        "monthly_cost": 0.00,
        "included_premium": 50,
        "overage_enabled": False,
        "overage_rate": 0.00,
    },
    "pro": {
        "name": "Copilot Pro",
        "monthly_cost": 10.00,
        "yearly_cost": 100.00,
        "included_premium": 300,
        "overage_enabled": True,
        "overage_rate": 0.04,
    },
    "pro_plus": {
        "name": "Copilot Pro+",
        "monthly_cost": 39.00,
        "yearly_cost": 390.00,
        "included_premium": 1500,
        "overage_enabled": True,
        "overage_rate": 0.04,
    },
    "business": {
        "name": "Copilot Business",
        "monthly_cost": 19.00,
        "included_premium": 300,
        "overage_enabled": True,
        "overage_rate": 0.04,
    },
    "enterprise": {
        "name": "Copilot Enterprise",
        "monthly_cost": 39.00,
        "included_premium": 1000,
        "overage_enabled": True,
        "overage_rate": 0.04,
    },
}

# Premium request multipliers per model (informational).
# The percentage shown on github.com/settings/copilot already accounts
# for model multipliers, so no additional math is needed.
# This table is provided for reference.
PREMIUM_MODELS = {
    "Claude Opus 4.6": "Premium",
    "Claude Opus 4.6 (fast mode)": "Premium (Pro+ / Enterprise only)",
    "Claude Opus 4.5": "Premium",
    "Claude Opus 4.1": "Premium (Pro+ / Enterprise only)",
    "Claude Sonnet 4.5": "Premium",
    "Claude Sonnet 4": "Premium",
    "GPT-5": "Premium",
    "GPT-5.1": "Premium",
    "GPT-5.2": "Premium",
    "GPT-5-Codex": "Premium",
    "GPT-5.1-Codex": "Premium",
    "GPT-5.1-Codex-Mini": "Premium",
    "GPT-5.1-Codex-Max": "Premium",
    "GPT-5.2-Codex": "Premium",
    "GPT-5.3-Codex": "Premium",
    "Gemini 2.5 Pro": "Premium",
    "Gemini 3 Flash": "Premium",
    "Gemini 3 Pro": "Premium",
    "Grok Code Fast 1": "Premium",
}

INCLUDED_MODELS = {
    "GPT-4.1": "Included (all plans)",
    "GPT-5 mini": "Included (all plans)",
    "Claude Haiku 4.5": "Included (all plans)",
    "Raptor mini": "Included (Free/Pro/Pro+ only)",
}


# ---------------------------------------------------------------------------
# ANSI colour helpers
# ---------------------------------------------------------------------------

NO_COLOR = os.environ.get("NO_COLOR") is not None or not sys.stdout.isatty()

RESET = "\033[0m"
BOLD = "\033[1m"
DIM = "\033[2m"
RED = "\033[91m"
GREEN = "\033[92m"
YELLOW = "\033[93m"
CYAN = "\033[96m"
WHITE = "\033[97m"


def style(code: str, text: str) -> str:
    """Wrap *text* in ANSI colour if stdout is a TTY."""
    if NO_COLOR:
        return text
    return code + text + RESET


# ---------------------------------------------------------------------------
# Calculation engine
# ---------------------------------------------------------------------------

def calculate_bill(
    usage_percent: float,
    plan_key: str = "pro_plus",
    billing_cycle: str = "monthly",
) -> dict:
    """Return a cost breakdown dict given a usage percentage."""
    plan = PLANS[plan_key]
    included = plan["included_premium"]
    total_used = usage_percent / 100.0 * included
    overage = max(0, total_used - included)

    base_cost = plan["monthly_cost"]
    if billing_cycle == "yearly" and "yearly_cost" in plan:
        base_cost = plan["yearly_cost"] / 12  # amortised monthly

    overage_cost = 0.0
    if plan["overage_enabled"] and overage > 0:
        overage_cost = overage * plan["overage_rate"]

    total_cost = base_cost + overage_cost

    return {
        "plan": plan["name"],
        "billing_cycle": billing_cycle,
        "base_cost": round(base_cost, 2),
        "included_premium": included,
        "usage_percent": usage_percent,
        "total_requests": round(total_used),
        "overage_requests": round(overage),
        "overage_rate": plan.get("overage_rate", 0),
        "overage_cost": round(overage_cost, 2),
        "total_cost": round(total_cost, 2),
    }


def project_end_of_month(
    usage_percent: float,
    current_day: int,
    days_in_month: int,
    plan_key: str = "pro_plus",
    billing_cycle: str = "monthly",
) -> dict:
    """Project end-of-month cost at the current daily burn rate."""
    plan = PLANS[plan_key]
    included = plan["included_premium"]
    total_used_so_far = usage_percent / 100.0 * included
    daily_rate = total_used_so_far / current_day if current_day > 0 else 0
    remaining_days = days_in_month - current_day
    projected_total = total_used_so_far + (daily_rate * remaining_days)
    projected_percent = (projected_total / included) * 100 if included else 0

    projected = calculate_bill(projected_percent, plan_key, billing_cycle)
    projected["daily_burn_rate"] = round(daily_rate, 1)
    projected["remaining_days"] = remaining_days
    projected["projected_total_requests"] = round(projected_total)
    projected["projected_percent"] = round(projected_percent, 1)
    return projected


# ---------------------------------------------------------------------------
# GitHub API helper
# ---------------------------------------------------------------------------

def fetch_copilot_info(token: str) -> Optional[dict]:
    """Attempt to fetch Copilot subscription info via the GitHub API.

    Returns a dict with available info, or None on failure.
    The individual Copilot usage percentage is not currently exposed
    via the REST API -- you must read it from github.com/settings/copilot.
    """
    if not HAS_URLLIB:
        return None

    headers = {
        "Accept": "application/vnd.github+json",
        "Authorization": "Bearer " + token,
        "X-GitHub-Api-Version": "2022-11-28",
    }

    req = urllib.request.Request(
        "https://api.github.com/user",
        headers=headers,
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            user_data = json.loads(resp.read().decode())
    except (urllib.error.URLError, urllib.error.HTTPError) as e:
        print(style(RED, "  API error: " + str(e)), file=sys.stderr)
        return None

    return {
        "login": user_data.get("login", "unknown"),
        "plan_name": user_data.get("plan", {}).get("name", "unknown"),
    }


# ---------------------------------------------------------------------------
# Display helpers
# ---------------------------------------------------------------------------

def divider(width: int = 60) -> None:
    print(style(DIM, "  " + "-" * width))


def usage_color(pct: float) -> str:
    """Return a coloured percentage string."""
    text = "{:.1f}%".format(pct)
    if pct <= 100:
        return style(GREEN, text)
    elif pct <= 200:
        return style(YELLOW, text)
    else:
        return style(RED, text)


def money(amount: float) -> str:
    return "${:.2f}".format(amount)


def row(label: str, value: str, label_w: int = 35) -> None:
    print("  {:<{w}} {}".format(label, value, w=label_w))


def print_bill(bill: dict, title: str = "CURRENT USAGE") -> None:
    """Pretty-print a cost breakdown."""
    w = 60
    bar = "=" * w
    print()
    print(style(BOLD + CYAN, "  " + bar))
    print(style(BOLD + CYAN, "  " + title.center(w)))
    print(style(BOLD + CYAN, "  " + bar))
    print()

    row("Plan:", style(WHITE, bill["plan"]))
    row("Billing cycle:", bill["billing_cycle"])
    divider()
    row("Base subscription:", style(WHITE, money(bill["base_cost"])))
    row("Included premium requests:", style(WHITE, "{:,}".format(bill["included_premium"])))
    row("Usage:", usage_color(bill["usage_percent"]))
    row("Total premium requests used:", style(WHITE, "{:,}".format(bill["total_requests"])))

    if bill["overage_requests"] > 0:
        divider()
        row("Overage requests:", style(YELLOW, "{:,}".format(bill["overage_requests"])))
        row("Overage rate:", money(bill["overage_rate"]) + "/request")
        row("Overage cost:", style(RED, money(bill["overage_cost"])))

    divider()
    total_clr = GREEN if bill["total_cost"] <= bill["base_cost"] else RED
    row("ESTIMATED TOTAL:", style(BOLD + total_clr, money(bill["total_cost"])))
    print()


def print_projection(proj: dict) -> None:
    """Pretty-print an end-of-month projection."""
    w = 60
    bar = "=" * w
    print(style(BOLD + YELLOW, "  " + bar))
    print(style(BOLD + YELLOW, "  " + "END-OF-MONTH PROJECTION".center(w)))
    print(style(BOLD + YELLOW, "  " + bar))
    print()

    row("Daily burn rate:", style(WHITE, "{:,.1f} requests/day".format(proj["daily_burn_rate"])))
    row("Remaining days in month:", style(WHITE, str(proj["remaining_days"])))
    row("Projected total requests:", style(WHITE, "{:,}".format(proj["projected_total_requests"])))
    row("Projected usage:", usage_color(proj["projected_percent"]))

    if proj["overage_requests"] > 0:
        divider()
        row("Projected overage requests:", style(YELLOW, "{:,}".format(proj["overage_requests"])))
        row("Projected overage cost:", style(RED, money(proj["overage_cost"])))

    divider()
    total_clr = GREEN if proj["total_cost"] <= proj["base_cost"] else RED
    row("PROJECTED MONTHLY TOTAL:", style(BOLD + total_clr, money(proj["total_cost"])))
    print()


def print_budget_alert(bill: dict, budget: float) -> None:
    """Print a budget warning if cost exceeds the budget."""
    total = bill["total_cost"]
    if total > budget:
        pct_over = ((total - budget) / budget) * 100
        print(style(BOLD + RED, "  *** BUDGET ALERT ***"))
        over = total - budget
        print(style(RED, "  Total {} exceeds budget {} by {} ({:.0f}%)".format(
            money(total), money(budget), money(over), pct_over)))
        print()
    elif bill["overage_cost"] > 0:
        remaining_budget = budget - total
        rate = bill["overage_rate"]
        remaining_reqs = remaining_budget / rate if rate else 0
        print(style(YELLOW, "  Budget remaining: {} (~{:,.0f} more premium requests)".format(
            money(remaining_budget), remaining_reqs)))
        print()
    else:
        print(style(GREEN, "  Within budget. {} remaining.".format(money(budget - total))))
        print()


def print_json_output(bill: dict, projection: Optional[dict] = None) -> None:
    """Print machine-readable JSON output."""
    output = {"current": bill}
    if projection:
        output["projection"] = projection
    print(json.dumps(output, indent=2))


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="GitHub Copilot Pro+ Usage & Cost Calculator",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--percent", "-p",
        type=float,
        help="Premium request usage %% from github.com/settings/copilot (e.g. 423.2)",
    )
    parser.add_argument(
        "--plan",
        choices=list(PLANS.keys()),
        default="pro_plus",
        help="Copilot plan (default: pro_plus)",
    )
    parser.add_argument(
        "--billing",
        choices=["monthly", "yearly"],
        default="monthly",
        help="Billing cycle (default: monthly)",
    )
    parser.add_argument(
        "--day", "-d",
        type=int,
        default=None,
        help="Current day of billing month (for projection). Defaults to today.",
    )
    parser.add_argument(
        "--days-in-month",
        type=int,
        default=None,
        help="Total days in billing month. Defaults to current month.",
    )
    parser.add_argument(
        "--budget", "-b",
        type=float,
        default=None,
        help="Monthly budget in USD for alerts (or COPILOT_MONTHLY_BUDGET env var)",
    )
    parser.add_argument(
        "--token", "-t",
        type=str,
        default=None,
        help="GitHub PAT for API lookup (or GITHUB_TOKEN env var)",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output results as JSON",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    # Resolve token
    token = args.token or os.environ.get("GITHUB_TOKEN")

    # Resolve budget
    budget = args.budget
    if budget is None:
        env_budget = os.environ.get("COPILOT_MONTHLY_BUDGET")
        if env_budget:
            budget = float(env_budget)

    # Resolve usage percentage
    usage_percent = args.percent

    # If we have a token but no percentage, try to get user info
    if token and usage_percent is None:
        print(style(DIM, "  Fetching Copilot info from GitHub API..."))
        info = fetch_copilot_info(token)
        if info:
            print(style(GREEN, "  Authenticated as: " + info["login"]))
            print()
            print(style(YELLOW, "  Note: The GitHub API does not expose individual premium"))
            print(style(YELLOW, "  request usage percentage. Please provide it manually."))
            print(style(YELLOW, "  Visit: https://github.com/settings/copilot"))
            print()

    if usage_percent is None:
        print(style(CYAN, "  Enter your premium request usage percentage"))
        print(style(DIM, "  (from https://github.com/settings/copilot)"))
        print()
        try:
            raw = input("  Usage %: ").strip().rstrip("%")
            usage_percent = float(raw)
        except (ValueError, EOFError):
            print(style(RED, "  Invalid input. Please enter a number like 423.2"))
            sys.exit(1)

    # Resolve day-of-month for projection
    now = datetime.now(timezone.utc)
    current_day = args.day if args.day is not None else now.day
    days_in_month = args.days_in_month or monthrange(now.year, now.month)[1]

    # Calculate current bill
    bill = calculate_bill(usage_percent, args.plan, args.billing)

    # Calculate projection (only if not at end of month)
    projection = None
    if current_day < days_in_month:
        projection = project_end_of_month(
            usage_percent, current_day, days_in_month,
            args.plan, args.billing,
        )

    # Output
    if args.json:
        print_json_output(bill, projection)
    else:
        print_bill(bill)
        if projection:
            print_projection(projection)
        if budget is not None:
            target = projection if projection else bill
            print_budget_alert(target, budget)

    # Exit with non-zero if over budget
    if budget is not None:
        target_cost = (projection or bill)["total_cost"]
        if target_cost > budget:
            sys.exit(2)


if __name__ == "__main__":
    main()
