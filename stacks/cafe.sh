# shellcheck shell=bash
# CRM Cafe (pardeep24/crm-cafe). Not in ALL_STACKS yet: it runs on systemd, a Python venv and
# host nginx today. Once it has Dockerfiles and a production compose file, this follows the
# retail pattern and cafe joins ALL_STACKS in lib/common.sh.
CAFE_REPO=pardeep24/crm-cafe

cafe_deploy() { die "Cafe does not run in Docker yet (README, \"Cafe\")."; }
cafe_start() { cafe_deploy; }
cafe_stop() { :; }
cafe_projects() { :; }
cafe_networks() { :; }
