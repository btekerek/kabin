"""
Auth serializers.

EmailTokenObtainPairSerializer is the one subtle piece here: simplejwt's
default TokenObtainPairSerializer authenticates against
AUTH_USER_MODEL.USERNAME_FIELD (still "username" on our model - see
models.py for why we didn't rename it). Since the API takes {email,
password}, not {username, password}, we fully override validate() rather
than trying to make Django's authenticate() machinery understand "email"
as a username-field alias. This is simplejwt's own documented pattern for
email-based login.
"""

from django.contrib.auth.models import update_last_login
from django.contrib.auth.password_validation import validate_password
from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from rest_framework_simplejwt.settings import api_settings

from apps.accounts.models import User
from apps.core.exceptions import KabinAPIException


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, validators=[validate_password])
    # ModelSerializer would otherwise auto-attach a UniqueValidator here
    # (because email has unique=True on the model) which fires before,
    # and instead of, validate_email() below - producing a generic 400
    # with no error code. validators=[] strips that auto-validator so our
    # EMAIL_IN_USE check is the one that actually runs.
    email = serializers.EmailField(validators=[])

    class Meta:
        model = User
        fields = ["email", "password"]

    def validate_email(self, value):
        value = value.lower().strip()
        if User.objects.filter(email__iexact=value).exists():
            raise KabinAPIException(
                code="EMAIL_IN_USE",
                message="An account with this email already exists.",
                status_code=400,
            )
        return value

    def create(self, validated_data):
        email = validated_data["email"]
        username = self._unique_username_from_email(email)
        user = User(email=email, username=username)
        user.set_password(validated_data["password"])
        user.save()
        return user

    @staticmethod
    def _unique_username_from_email(email: str) -> str:
        base = email.split("@")[0][:150] or "user"
        username = base
        suffix = 1
        while User.objects.filter(username=username).exists():
            suffix += 1
            username = f"{base}{suffix}"[:150]
        return username


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ["id", "email"]
        read_only_fields = fields


class EmailTokenObtainPairSerializer(TokenObtainPairSerializer):
    username_field = "email"

    def validate(self, attrs):
        email = attrs.get("email", "").lower().strip()
        password = attrs.get("password", "")

        user = User.objects.filter(email__iexact=email).first()
        if user is None or not user.check_password(password) or not user.is_active:
            raise KabinAPIException(
                code="INVALID_CREDENTIALS",
                message="Incorrect email or password.",
                status_code=401,
            )

        refresh = self.get_token(user)
        data = {"refresh": str(refresh), "access": str(refresh.access_token)}

        if api_settings.UPDATE_LAST_LOGIN:
            update_last_login(None, user)

        return data
