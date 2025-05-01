from django.db import models

class Equipment(models.Model):
    name = models.CharField(max_length=255)
    location = models.ForeignKey('locations.Location', on_delete=models.CASCADE, related_name='equipments', null=True, blank=True)
    school = models.ForeignKey('schools.School', on_delete=models.CASCADE, related_name='equipments', blank=True, null=True)
    state = models.CharField(max_length=50, choices=[('new', 'New'), ('used', 'Used'), ('damaged', 'Damaged'), ('missing', 'Missing')], null=True, blank=True)
    photo = models.ImageField(upload_to='equipment_photos/', blank=True, null=True)
    is_being_used = models.BooleanField(default=False)
    nothing_missing = models.BooleanField(default=True)
    usages = models.JSONField(blank=True, null=True)
    sports = models.ManyToManyField('sports.Sport', related_name='equipments', blank=True)
    size =  models.CharField(max_length=50, null=True, blank=True)
    is_for_kids = models.BooleanField(null=True, blank=True)
    description = models.CharField(max_length=255, null=True, blank=True)
    brand = models.CharField(max_length=255, null=True, blank=True)

    def __str__(self):
        return f"Equipment: {self.name} ({self.state})"

