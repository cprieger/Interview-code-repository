"""EVE Deals Finder -- local Flask app.

Logs in via EVE SSO, finds your current system, scans public contracts in your
system and a chosen reference system, and flags item-exchange contracts priced
well below a trimmed-mean market reference.
"""

from flask import Flask, jsonify, redirect, render_template, request, session

from eve_deals import db, esi_client, poll, sso
from eve_deals.config import FLASK_SECRET_KEY

app = Flask(__name__)
app.secret_key = FLASK_SECRET_KEY

db.init_db()


@app.route("/")
def index():
    tokens = db.get_tokens()
    return render_template("index.html", tokens=tokens)


@app.route("/auth/login")
def auth_login():
    state = sso.new_state()
    session["oauth_state"] = state
    return redirect(sso.build_authorize_url(state))


@app.route("/auth/callback")
def auth_callback():
    if request.args.get("state") != session.get("oauth_state"):
        return "Invalid OAuth state", 400

    code = request.args.get("code")
    if not code:
        return "Missing authorization code", 400

    sso.exchange_code_for_tokens(code)
    return redirect("/")


@app.route("/api/location")
def api_location():
    tokens = db.get_tokens()
    if not tokens:
        return jsonify({"error": "not_authenticated"}), 401

    access_token = sso.get_valid_access_token()
    system_id = esi_client.get_character_location(tokens["character_id"], access_token)
    from eve_deals import universe

    system_name = universe.system_id_to_name(system_id)
    return jsonify({"system_id": system_id, "system_name": system_name})


@app.route("/api/poll", methods=["POST"])
def api_poll():
    tokens = db.get_tokens()
    if not tokens:
        return jsonify({"error": "not_authenticated"}), 401

    body = request.get_json(silent=True) or {}
    reference_system_name = (body.get("reference_system") or "").strip()
    if not reference_system_name:
        return jsonify({"error": "reference_system is required"}), 400

    access_token = sso.get_valid_access_token()
    home_system_id = esi_client.get_character_location(tokens["character_id"], access_token)

    try:
        polled_at, deals = poll.run_poll(home_system_id, reference_system_name, access_token)
    except ValueError as exc:
        return jsonify({"error": str(exc)}), 400

    return jsonify({"polled_at": polled_at, "deals": deals})


if __name__ == "__main__":
    app.run(port=5000, debug=True)
