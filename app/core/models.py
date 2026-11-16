from django.db import models


class Visit(models.Model):
    created_at = models.DateTimeField(auto_now_add=True)
    hostname = models.CharField(max_length=255)

    def __str__(self):
        return f"Visit #{self.pk} from {self.hostname}"
