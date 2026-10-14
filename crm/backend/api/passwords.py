from django.contrib.auth import get_user_model
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError as DjangoValidationError


def weak_password_message(password, email='', name=''):
    """A user-facing reason the password is too weak (Django's validators), or None if it is fine.

    Only strength is checked here; the 8-128 length rule stays with the callers.
    """
    probe = get_user_model()(username=email, email=email, first_name=name)
    try:
        validate_password(password, probe)
    except DjangoValidationError as e:
        return ' '.join(e.messages)
    return None
