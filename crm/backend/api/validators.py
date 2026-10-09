import re
from rest_framework import serializers

PHONE_10_DIGIT_REGEX = r'^[6-9]\d{9}$'

def validate_mobile_10_digit(value):
    """
    Validates that a mobile number is strictly 10 digits only.
    No ISD code (+91, 0, etc.), no non-digits, and starts with 6-9.
    Raises serializers.ValidationError if invalid.
    """
    cleaned = str(value or '').strip()
    if not re.fullmatch(PHONE_10_DIGIT_REGEX, cleaned):
        raise serializers.ValidationError(
            'Mobile number must be exactly 10 digits starting with 6-9 (no country code or leading 0).'
        )
    return cleaned

def clean_mobile_10_digit(raw):
    """
    Checks if raw input is strictly 10 digits only.
    Returns the 10-digit string if valid, otherwise None.
    """
    cleaned = str(raw or '').strip()
    return cleaned if re.fullmatch(PHONE_10_DIGIT_REGEX, cleaned) else None
