from django.contrib import admin
from django.contrib.auth.admin import UserAdmin

from apps.accounts.models import User


class KabinUserAdmin(UserAdmin):
    list_display = ("email", "username", "is_staff")


admin.site.register(User, KabinUserAdmin)
