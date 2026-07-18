param (
    [string]$ProjectName = "config",
    [string]$AppName = "app_main"
)

# -----------------------------
# ERROR: If There is Any Error
# Run this command -> 
# Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
# -----------------------------

# -----------------------------
# Step 1: Setup virtual environment
# -----------------------------
Write-Host "Creating virtual environment..." -ForegroundColor Cyan
python -m venv .venv

Write-Host "Activating virtual environment..." -ForegroundColor Cyan
& "$PWD\.venv\Scripts\Activate.ps1"

Write-Host "Installing Django & Django REST Framework..." -ForegroundColor Cyan
pip install django djangorestframework djangorestframework-simplejwt

# -----------------------------
# Step 2: Create Django project and app
# -----------------------------
Write-Host "Creating Django project..." -ForegroundColor Cyan
django-admin startproject $ProjectName .

Write-Host "Creating app..." -ForegroundColor Cyan
python manage.py startapp $AppName

# -----------------------------
# Step 3: Update settings.py
# -----------------------------
Write-Host "Updating settings.py..." -ForegroundColor Cyan
$settingsPath = "$ProjectName\settings.py"

# Add app to INSTALLED_APPS
(Get-Content $settingsPath) -replace "INSTALLED_APPS = \[", "INSTALLED_APPS = [`n    '$AppName',`n    'rest_framework',`n    'rest_framework_simplejwt',`n    'rest_framework_simplejwt.token_blacklist'," | Set-Content $settingsPath

@"

# Custom user model
AUTH_USER_MODEL = 'app_main.CustomUser'

# REST Framework configuration
REST_FRAMEWORK = {
    'DEFAULT_AUTHENTICATION_CLASSES': (
        'rest_framework_simplejwt.authentication.JWTAuthentication',
    ),
}

# Additional customizations of JWT settings in `settings.py`
from datetime import timedelta

SIMPLE_JWT = {
    'ACCESS_TOKEN_LIFETIME': timedelta(minutes=5),
    'REFRESH_TOKEN_LIFETIME': timedelta(days=1),
    'ROTATE_REFRESH_TOKENS': True,
    'BLACKLIST_AFTER_ROTATION': True,
}
"@ | Add-Content $settingsPath

# -----------------------------
# Step 4: Update models.py
# -----------------------------
Write-Host "Updating models.py..." -ForegroundColor Cyan
$modelsPath = "$AppName\models.py"

@"
from django.db import models
from django.contrib.auth.models import AbstractUser

class CustomUser(AbstractUser):
    USER_TYPES = [
        ('Admin', 'Admin'),
        ('Employee', 'Employee'),
    ]

    user_type = models.CharField(choices=USER_TYPES, max_length=100, null=True)
"@ | Set-Content $modelsPath

# -----------------------------
# Step 5: Create and run migrations
# -----------------------------
Write-Host "Creating and running migrations..." -ForegroundColor Cyan
python manage.py makemigrations
python manage.py migrate

# -----------------------------
# Step 6: Update serializers.py
# -----------------------------
Write-Host "Updating serializers.py..." -ForegroundColor Cyan
$serializersPath = "$AppName\serializers.py"

@"
from rest_framework import serializers
from django.contrib.auth import get_user_model

User = get_user_model()

class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = '__all__'

class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)

    class Meta:
        model = User
        fields = ['username', 'email', 'password', 'user_type']

    def create(self, validated_data):
        user = User.objects.create_user(
            username=validated_data['username'],
            email=validated_data['email'],
            password=validated_data['password'],
            user_type=validated_data['user_type'],
        )
        return user
"@ | Set-Content $serializersPath

# -----------------------------
# Step 7: Update views.py
# -----------------------------
Write-Host "Updating views.py..." -ForegroundColor Cyan
$viewsPath = "$AppName\views.py"

@"
from rest_framework import generics, status, permissions
from rest_framework.response import Response
from rest_framework_simplejwt.tokens import RefreshToken
from .serializers import *
from django.contrib.auth import authenticate
from rest_framework.views import APIView

class RegisterView(generics.CreateAPIView):
    serializer_class = RegisterSerializer
    permission_classes = [permissions.AllowAny]

class LogInView(APIView):
    permission_classes = [permissions.AllowAny]

    def post(self, request):
        username = request.data.get("username")
        password = request.data.get("password")

        user = authenticate(username=username, password=password)

        if user is not None:
            refresh = RefreshToken.for_user(user)
            data = {
                'refresh': str(refresh),
                'access': str(refresh.access_token),
                'user': UserSerializer(user).data,
            }
            return Response(data, status=status.HTTP_200_OK)
        else:
            return Response(
                {"error": "Invalid Username and Password"},
                status=status.HTTP_401_UNAUTHORIZED
            )

class LogoutView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def post(self, request):
        try:
            refresh_token = request.data["refresh"]
            token = RefreshToken(refresh_token)
            token.blacklist()
            return Response(
                {"message": "Successfully logged out"},
                status=status.HTTP_205_RESET_CONTENT
            )
        except Exception as e:
            return Response(
                {"error": f"{e}"},
                status=status.HTTP_400_BAD_REQUEST
            )
"@ | Set-Content $viewsPath

# -----------------------------
# Step 8: Update urls.py
# -----------------------------
Write-Host "Updating urls.py..." -ForegroundColor Cyan
$urlsPath = "$AppName\urls.py"

@"
from django.contrib import admin
from django.urls import path
from .views import *
from rest_framework_simplejwt.views import TokenRefreshView

urlpatterns = [
    path('token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('register/', RegisterView.as_view(), name='register'),
    path('login/', LogInView.as_view(), name='login'),
    path('logout/', LogoutView.as_view(), name='logout'),
]
"@ | Set-Content $urlsPath

# -----------------------------
# Step 9: Connecting all urls to the root urls.py 
# -----------------------------
Write-Host "Updating urls.py..." -ForegroundColor Cyan
$purlsPath = "$ProjectName\urls.py"

@"
from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/', include('app_main.urls')),
]
"@ | Set-Content $purlsPath

# -----------------------------
# Step 10: Create .gitignore
# -----------------------------
@"
.venv/
__pycache__/
migrations/
*.pyc
db.sqlite3
"@ | Set-Content .gitignore

# -----------------------------
# Step 11: Save requirements
# -----------------------------
pip freeze > requirements.txt

# -----------------------------
# Step 12: Create superuser
# -----------------------------
Write-Host "----------------------------" -ForegroundColor Cyan
Write-Host "Creating Django superuser..." -ForegroundColor Cyan
Write-Host "username: admin" -ForegroundColor Cyan
Write-Host "email: admin@example.com" -ForegroundColor Cyan
Write-Host "password: 1234" -ForegroundColor Cyan
Write-Host "----------------------------" -ForegroundColor Cyan

$superuserScript = @"
import os
import django
from django.contrib.auth import get_user_model

os.environ.setdefault('DJANGO_SETTINGS_MODULE', '$ProjectName.settings')
django.setup()

User = get_user_model()

if not User.objects.filter(username='admin').exists():
    User.objects.create_superuser('admin', 'admin@example.com', '1234')
    print('Superuser created: username=admin, password=1234')
else:
    print('Superuser already exists')
"@

$superuserScript | Set-Content "create_superuser.py"
python create_superuser.py
Remove-Item "create_superuser.py"

# -----------------------------
# Step 15: Run server
# -----------------------------
Write-Host "`n[DONE] Basic Django project setup complete!" -ForegroundColor Green
Start-Process code .
Start-Process "http://127.0.0.1:8000/api/"
python manage.py runserver
