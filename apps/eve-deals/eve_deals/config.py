"""Environment-based configuration for the EVE Deals app."""

import os

from dotenv import load_dotenv

load_dotenv()

ESI_CLIENT_ID = os.environ.get("ESI_CLIENT_ID", "")
ESI_CLIENT_SECRET = os.environ.get("ESI_CLIENT_SECRET", "")
ESI_CALLBACK_URL = os.environ.get("ESI_CALLBACK_URL", "http://localhost:5000/auth/callback")

ESI_BASE_URL = "https://esi.evetech.net/latest"
ESI_SSO_AUTHORIZE_URL = "https://login.eveonline.com/v2/oauth/authorize"
ESI_SSO_TOKEN_URL = "https://login.eveonline.com/v2/oauth/token"
ESI_SSO_JWKS_ISSUER = "login.eveonline.com"

ESI_SCOPES = "esi-location.read_location.v1"

# Deal detection: flag a contract if its price is at least this % below fair value.
DEAL_DISCOUNT_THRESHOLD_PCT = 15.0

DB_PATH = os.environ.get("EVE_DEALS_DB_PATH", os.path.join(os.path.dirname(os.path.dirname(__file__)), "eve_deals.db"))

FLASK_SECRET_KEY = os.environ.get("FLASK_SECRET_KEY", "dev-secret-change-me")
