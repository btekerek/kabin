from django.contrib import admin
from django.contrib.auth.admin import UserAdmin

from apps.accounts.models import User


class KabinUserAdmin(UserAdmin):
    fieldsets = UserAdmin.fieldsets + (("Kabin", {"fields": ("role",)}),)
    list_display = ("email", "username", "role", "is_staff")


admin.site.register(User, KabinUserAdmin)
