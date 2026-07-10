"""
Django settings for the Kabin backend.

Scaffold notes (see docs/adr/ for the reasoning behind these choices once
ADRs are written):
- Config is env-driven (python-dotenv loads a local .env in dev; in
  production real env vars are injected by the host).
- AUTH_USER_MODEL is set to a custom model from day one because swapping
  it later requires a destructive migration reset. The model itself is
  still a bare AbstractUser stub until the auth slice adds fields.
- SIMPLE_JWT is configured for the dual-token strategy (short-lived access
  token, rotating refresh token, blacklist-after-rotation) even though the
  login/refresh views are not wired up yet - that's the next slice.
"""

import os
from datetime import timedelta
from pathlib import Path

from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent.parent

load_dotenv(BASE_DIR / ".env")


def env_bool(name: str, default: bool) -> bool:
    val = os.environ.get(name)
    if val is None:
        return default
    return val.strip().lower() in ("1", "true", "yes", "on")


def env_list(name: str, default: str = "") -> list[str]:
    val = os.environ.get(name, default)
    return [item.strip() for item in val.split(",") if item.strip()]


SECRET_KEY = os.environ.get("DJANGO_SECRET_KEY", "insecure-dev-key-change-me")
DEBUG = env_bool("DJANGO_DEBUG", True)
ALLOWED_HOSTS = env_list("DJANGO_ALLOWED_HOSTS", "localhost,127.0.0.1,testserver")

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "rest_framework",
    "rest_framework_simplejwt",
    "rest_framework_simplejwt.token_blacklist",
    "channels",
    "corsheaders",
    "drf_spectacular",
    "apps.core",
    "apps.accounts",
    "apps.sessions",
    "apps.realtime",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "corsheaders.middleware.CorsMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "config.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.debug",
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "config.wsgi.application"
ASGI_APPLICATION = "config.asgi.application"

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": os.environ.get("POSTGRES_DB", "kabin"),
        "USER": os.environ.get("POSTGRES_USER", "kabin"),
        "PASSWORD": os.environ.get("POSTGRES_PASSWORD", "kabin"),
        "HOST": os.environ.get("POSTGRES_HOST", "localhost"),
        "PORT": os.environ.get("POSTGRES_PORT", "5432"),
    }
}

AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

AUTH_USER_MODEL = "accounts.User"

LANGUAGE_CODE = "en-us"
TIME_ZONE = "UTC"
USE_I18N = True
USE_TZ = True

STATIC_URL = "static/"
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

CORS_ALLOWED_ORIGINS = env_list("CORS_ALLOWED_ORIGINS")

REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": (
        "rest_framework_simplejwt.authentication.JWTAuthentication",
    ),
    "DEFAULT_PERMISSION_CLASSES": ("rest_framework.permissions.IsAuthenticated",),
    "EXCEPTION_HANDLER": "apps.core.exceptions.kabin_exception_handler",
    "DEFAULT_SCHEMA_CLASS": "drf_spectacular.openapi.AutoSchema",
}

SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(minutes=15),
    "REFRESH_TOKEN_LIFETIME": timedelta(days=7),
    "ROTATE_REFRESH_TOKENS": True,
    "BLACKLIST_AFTER_ROTATION": True,
    "UPDATE_LAST_LOGIN": True,
    "ALGORITHM": "HS256",
    "SIGNING_KEY": SECRET_KEY,
    "AUTH_HEADER_TYPES": ("Bearer",),
}

SPECTACULAR_SETTINGS = {
    "TITLE": "Kabin API",
    "DESCRIPTION": "Real-time event interpretation platform.",
    "VERSION": "0.1.0",
    "SERVE_INCLUDE_SCHEMA": False,
}

if os.environ.get("REDIS_URL"):
    CHANNEL_LAYERS = {
        "default": {
            "BACKEND": "channels_redis.core.RedisChannelLayer",
            "CONFIG": {"hosts": [os.environ["REDIS_URL"]]},
        }
    }
else:
    CHANNEL_LAYERS = {"default": {"BACKEND": "channels.layers.InMemoryChannelLayer"}}

AGORA_APP_ID = os.environ.get("AGORA_APP_ID", "")
AGORA_APP_CERTIFICATE = os.environ.get("AGORA_APP_CERTIFICATE", "")

SESSION_LISTENER_CAP_DEFAULT = int(os.environ.get("SESSION_LISTENER_CAP_DEFAULT", "500"))

LOGGING_FORMAT = (
    '{"time": "%(asctime)s", "level": "%(levelname)s", '
    '"logger": "%(name)s", "message": "%(message)s"}'
)

LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "formatters": {
        "json": {"format": LOGGING_FORMAT},
    },
    "handlers": {
        "console": {"class": "logging.StreamHandler", "formatter": "json"},
    },
    "root": {
        "handlers": ["console"],
        "level": os.environ.get("DJANGO_LOG_LEVEL", "INFO"),
    },
}
