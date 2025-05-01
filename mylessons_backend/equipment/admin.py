from django.contrib import admin
from .models import Equipment

@admin.register(Equipment)
class EquipmentAdmin(admin.ModelAdmin):
    list_display = ('name', 'state', 'location', 'is_being_used', 'nothing_missing', 'school')  # Fields to display in the list view
    list_filter = ('state', 'is_being_used', 'nothing_missing')  # Filters for the list view
    search_fields = ('name', 'location__name')  # Search bar fields
    ordering = ('name',)  # Default ordering
    readonly_fields = ('usages',)  # Fields that cannot be edited
