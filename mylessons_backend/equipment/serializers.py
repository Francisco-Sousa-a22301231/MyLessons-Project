import json
from rest_framework import serializers
from .models import Equipment
from sports.models import Sport

class EquipmentSerializer(serializers.ModelSerializer):
    # explicitly declare it so we can override validate_sports
    sports = serializers.PrimaryKeyRelatedField(
        many=True, queryset=Sport.objects.all()
    )

    class Meta:
        model = Equipment
        fields = [
            'id', 'name', 'school', 'location', 'state', 'photo',
            'is_being_used', 'nothing_missing', 'usages',
            'sports', 'size', 'is_for_kids',
            'description', 'brand',
        ]

    def validate_sports(self, value):
        # if it's coming in as a JSON‐encoded string, decode it
        if isinstance(value, str):
            try:
                value = json.loads(value)
            except json.JSONDecodeError:
                raise serializers.ValidationError("sports must be a JSON list of IDs")
        return value
