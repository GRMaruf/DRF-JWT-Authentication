# Full JWT Authentication Guide

This guide provides a step-by-step tutorial on implementing authentication in Django REST Framework using JWT (JSON Web Tokens) with a custom user model.

## Prerequisites

- Python 3.8+
- Django 4.2+
- Basic knowledge of Django and REST APIs

## Step 1: Project Setup

### 1.1 Create a new Django project

```bash
django-admin startproject config ExampleProject
cd ProjectJWT
```

### 1.2 Create a Django app

```bash
python manage.py startapp app_main
```

### 1.3 Install required packages

```bash
pip install django djangorestframework djangorestframework-simplejwt
```

### 1.4 Update settings.py

Add the following to your `settings.py`:

```python
INSTALLED_APPS = [
    # ... existing apps
    'app_main',
    'rest_framework',
    'rest_framework_simplejwt',
    'rest_framework_simplejwt.token_blacklist',
]

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
```

## Step 2: Create Custom User Model

### 2.1 Define the model

In `app_main/models.py`:

```python
from django.db import models
from django.contrib.auth.models import AbstractUser

class CustomUser(AbstractUser):
    USER_TYPES = [
        ('Admin', 'Admin'),
        ('Employee', 'Employee'),
    ]

    user_type = models.CharField(choices=USER_TYPES, max_length=100, null=True)
```

### 2.2 Create and run migrations

```bash
python manage.py makemigrations
python manage.py migrate
```

## Step 3: Create Serializers

### 3.1 User Serializer

In `app_main/serializers.py`:

```python
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
```

## Step 4: Create Views

### 4.1 Authentication Views

In `app_main/views.py`:

```python
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
```

## Step 5: Configure URLs

### 5.1 App URLs

In `app_main/urls.py`:

```python
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
```

### 5.2 Project URLs

In `myProject/urls.py`:

```python
from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path('admin/', admin.site.urls),
    path('api/', include('app_main.urls')),
]
```

## Step 6: Testing the Authentication

### 6.1 Start the server

```bash
python manage.py runserver
```

### 6.2 Test Registration

Use Thunder Client or curl:

**Method:** POST  
**URL:** `http://127.0.0.1:8000/api/register/`  
**Headers:** `Content-Type: application/json`  
**Body:**
```json
{
  "username": "testuser",
  "email": "test@example.com",
  "password": "password123",
  "user_type": "Employee"
}
```

**Expected Response:** User created successfully (201 status)

### 6.3 Test Login

**Method:** POST  
**URL:** `http://127.0.0.1:8000/api/login/`  
**Headers:** `Content-Type: application/json`  
**Body:**
```json
{
  "username": "testuser",
  "password": "password123"
}
```

**Expected Response:**
```json
{
  "refresh": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...",
  "access": "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9...",
  "user": {
    "id": 1,
    "username": "testuser",
    "email": "test@example.com",
    "User_Type": "Employee"
  }
}
```

### 6.4 Test Token Refresh

**Method:** POST  
**URL:** `http://127.0.0.1:8000/api/token/refresh/`  
**Headers:** `Content-Type: application/json`  
**Body:**
```json
{
  "refresh": "your_refresh_token_here"
}
```

### 6.5 Test Logout

**Method:** POST  
**URL:** `http://127.0.0.1:8000/api/logout/`  
**Headers:**
- `Content-Type: application/json`
- `Authorization: Bearer your_access_token_here`  
**Body:**
```json
{
  "refresh": "your_refresh_token_here"
}
```

## Step 7: Protecting Views

To protect a view with authentication, add the permission class:

```python
from rest_framework.permissions import IsAuthenticated

class ProtectedView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response({"message": "This is a protected view"})
```

## Conclusion

You now have a complete Django REST Framework authentication system with JWT tokens. The system supports user registration, login, logout, and token refresh, with a custom user model that includes user types.
