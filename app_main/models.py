from django.db import models
from django.contrib.auth.models import AbstractUser

class CustomUser(AbstractUser):
    USER_TYPES = [
        ('Admin', 'Admin'),
        ('Employee', 'Employee'),
    ]

    user_type = models.CharField(choices=USER_TYPES, max_length=100, null=True)