"""Role discovery and staff-side approval of customer email links."""
from django.shortcuts import get_object_or_404
from django.utils import timezone
from rest_framework.decorators import api_view, permission_classes
from rest_framework.response import Response

from .auth import CUSTOMER, IsOwner, IsSignedIn, Principal
from .customer_views import profile_json
from .models import EmailLinkRequest


@api_view(['GET'])
@permission_classes([IsSignedIn])
def me(request):
    """GET /api/me/ - who the verified Google token belongs to.

    The Flutter app calls this right after sign-in to choose between the full
    CRM (`staff`) and the customer-only shell (`customer`); `unlinked` means a
    valid Google account with no Staff or Customer record yet.
    """
    user: Principal = request.user
    data = {'role': user.role, 'email': user.email}

    # Include active shop and accessible shops for multitenant frontend context
    shop = getattr(request, 'shop', None) or getattr(user, 'shop', None)
    if shop:
        data['shop'] = {
            'id': shop.id,
            'name': shop.name,
            'slug': shop.slug,
            'currency_symbol': shop.currency_symbol,
        }

    django_user = getattr(user, 'user', None)
    if django_user and hasattr(django_user, 'shop_memberships'):
        memberships = django_user.shop_memberships.filter(is_active=True).select_related('shop')
        data['shops'] = [
            {
                'id': m.shop.id,
                'name': m.shop.name,
                'slug': m.shop.slug,
                'role': m.role,
                'is_default': m.is_default,
            }
            for m in memberships
        ]

    # First-time owner onboarding check:
    # If the user is an owner and has 0 active owned shop memberships, onboarding is mandatory.
    if user.role == 'owner':
        owned_count = 0
        if django_user and hasattr(django_user, 'shop_memberships'):
            owned_count = django_user.shop_memberships.filter(is_active=True, role='OWNER').count()
        data['needs_shop_onboarding'] = (owned_count == 0)

    if user.role == CUSTOMER:
        c = user.customer
        data['customer'] = {
            **profile_json(c),
            'total_orders': c.total_orders, 'total_spent': c.total_spent,
            'due_amount': c.due_amount,
        }
    else:
        data['pending_link'] = EmailLinkRequest.objects.filter(
            email__iexact=user.email, status=EmailLinkRequest.PENDING).exists()
    return Response(data)


def _link_json(r):
    return {
        'id': r.id, 'email': r.email, 'status': r.status,
        'customer_id': str(r.customer_id), 'customer_name': r.customer.name,
        'customer_phone': r.customer.phone, 'customer_email': r.customer.email,
        'created_at': r.created_at.isoformat(),
    }


@api_view(['GET'])
@permission_classes([IsOwner])
def link_requests(request):
    """GET /api/link-requests/ - pending requests to attach an email to a customer."""
    pending = EmailLinkRequest.objects.filter(
        status=EmailLinkRequest.PENDING).select_related('customer')
    return Response({'requests': [_link_json(r) for r in pending]})


@api_view(['POST'])
@permission_classes([IsOwner])
def link_request_approve(request, pk):
    link = get_object_or_404(EmailLinkRequest.objects.select_related('customer'), pk=pk)
    if not link.approve():
        return Response(
            {'detail': 'Not pending, or the customer already has a different email.'},
            status=409)
    return Response(_link_json(link))


@api_view(['POST'])
@permission_classes([IsOwner])
def link_request_reject(request, pk):
    link = get_object_or_404(EmailLinkRequest.objects.select_related('customer'), pk=pk)
    if link.status != EmailLinkRequest.PENDING:
        return Response({'detail': 'Not pending.'}, status=409)
    link.status = EmailLinkRequest.REJECTED
    link.resolved_at = timezone.now()
    link.save(update_fields=['status', 'resolved_at'])
    return Response(_link_json(link))
