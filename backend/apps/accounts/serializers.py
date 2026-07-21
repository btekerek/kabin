"""
Auth serializers.

LoginSerializer is the one subtle piece here: simplejwt's default
TokenObtainPairSerializer authenticates against
AUTH_USER_MODEL.USERNAME_FIELD (still "username" on our model - see
models.py). Since the API accepts either email or username in one field
(`identifier`), not a fixed username-field alias, we fully override
validate() rather than trying to make Django's authenticate() machinery
understand it. This is simplejwt's own documented pattern for
non-standard login identifiers.
"""

from django.contrib.auth.models import update_last_login
from django.contrib.auth.password_validation import validate_password
from django.db.models import Q
from rest_framework import serializers
from rest_framework_simplejwt.serializers import TokenObtainPairSerializer
from rest_framework_simplejwt.settings import api_settings

from apps.accounts.models import User
from apps.core.exceptions import KabinAPIException


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, validators=[validate_password])
    # ModelSerializer would otherwise auto-attach a UniqueValidator to
    # email/username (both unique=True on the model) which fires before,
    # and instead of, validate_email()/validate_username() below -
    # producing a generic 400 with no error code. validators=[] strips
    # that auto-validator so our own *_IN_USE checks are the ones that
    # actually run.
    email = serializers.EmailField(validators=[])
    # Optional - a blank/omitted username gets one generated from the
    # email's local part in create() below, so every account still ends
    # up with a real, usable-to-login username either way.
    username = serializers.CharField(
        max_length=150, required=False, allow_blank=True, validators=[]
    )

    class Meta:
        model = User
        fields = ["email", "password", "username"]

    def validate_email(self, value):
        value = value.lower().strip()
        if User.objects.filter(email__iexact=value).exists():
            raise KabinAPIException(
                code="EMAIL_IN_USE",
                message="An account with this email already exists.",
                status_code=400,
            )
        return value

    def validate_username(self, value):
        value = value.strip()
        if value and User.objects.filter(username__iexact=value).exists():
            raise KabinAPIException(
                code="USERNAME_IN_USE",
                message="An account with this username already exists.",
                status_code=400,
            )
        return value

    def create(self, validated_data):
        email = validated_data["email"]
        username = validated_data.get("username", "").strip()
        if not username:
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
        while User.objects.filter(username__iexact=username).exists():
            suffix += 1
            username = f"{base}{suffix}"[:150]
        return username


class UserSerializer(serializers.ModelSerializer):
    """Doubles as the read-only /api/auth/me/ + register response shape
    and the input shape for changing username via MeView's PATCH - id/
    email stay read-only either way.
    """

    class Meta:
        model = User
        fields = ["id", "email", "username"]
        read_only_fields = ["id", "email"]

    def validate_username(self, value):
        value = value.strip()
        if not value:
            raise KabinAPIException(
                code="MISSING_FIELDS", message="Username is required.", status_code=400
            )
        query = User.objects.filter(username__iexact=value)
        if self.instance is not None:
            query = query.exclude(pk=self.instance.pk)
        if query.exists():
            raise KabinAPIException(
                code="USERNAME_IN_USE",
                message="An account with this username already exists.",
                status_code=400,
            )
        return value


class LoginSerializer(TokenObtainPairSerializer):
    username_field = "identifier"

    def validate(self, attrs):
        identifier = attrs.get("identifier", "").strip()
        password = attrs.get("password", "")

        user = User.objects.filter(
            Q(email__iexact=identifier) | Q(username__iexact=identifier)
        ).first()
        if user is None or not user.check_password(password) or not user.is_active:
            raise KabinAPIException(
                code="INVALID_CREDENTIALS",
                message="Incorrect email/username or password.",
                status_code=401,
            )

        refresh = self.get_token(user)
        data = {"refresh": str(refresh), "access": str(refresh.access_token)}

        if api_settings.UPDATE_LAST_LOGIN:
            update_last_login(None, user)

        return data
