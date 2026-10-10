from . import media_views
from django.urls import path, include
from rest_framework.routers import DefaultRouter

from .views import (
    ShopViewSet, CustomerViewSet, GarmentCategoryViewSet,
    GarmentItemViewSet, OrderViewSet, ExpenseViewSet, CreditViewSet, CreditCategoryViewSet,
    StaffViewSet, AttendanceViewSet, SalaryPaymentViewSet, SalaryAdvanceViewSet,
    ServiceAreaViewSet, TimeSlotViewSet, dashboard_stats, payroll_summary,
    reports, meta,
    rag_chat, create_lead, public_lead, process_leads,
    MetaSettingsViewSet, MetaPostViewSet, MetaMessageViewSet, MetaLeadViewSet,
    meta_social_analytics, meta_social_sync,
    neonize_status, neonize_connect, neonize_disconnect,
    export_backup, export_section, import_section,
)
from .password_auth import signup, verify_email, login, forgot_password, reset_password
from .role_views import me, link_requests, link_request_approve, link_request_reject
from .customer_views import (
    customer_me, customer_orders, customer_order_detail, customer_rate_card,
)

router = DefaultRouter()
router.register(r'shops', ShopViewSet)
router.register(r'customers', CustomerViewSet)
router.register(r'categories', GarmentCategoryViewSet)
router.register(r'items', GarmentItemViewSet, basename='garmentitem')
router.register(r'orders', OrderViewSet, basename='order')
router.register(r'expenses', ExpenseViewSet)
router.register(r'credits', CreditViewSet)
router.register(r'credit-categories', CreditCategoryViewSet)
router.register(r'staff', StaffViewSet)
router.register(r'attendance', AttendanceViewSet, basename='attendance')
router.register(r'salary-payments', SalaryPaymentViewSet, basename='salarypayment')
router.register(r'salary-advances', SalaryAdvanceViewSet, basename='salaryadvance')
router.register(r'service-areas', ServiceAreaViewSet)
router.register(r'time-slots', TimeSlotViewSet, basename='timeslot')
router.register(r'meta-settings', MetaSettingsViewSet, basename='metasettings')
router.register(r'meta-posts', MetaPostViewSet, basename='metapost')
router.register(r'meta-messages', MetaMessageViewSet, basename='metamessage')
router.register(r'meta-leads', MetaLeadViewSet, basename='metalead')

urlpatterns = [
    path('', include(router.urls)),
    path('dashboard/stats/', dashboard_stats, name='dashboard-stats'),
    path('payroll/', payroll_summary, name='payroll-summary'),
    path('rag/chat/', rag_chat, name='rag-chat'),
    path('leads/', create_lead, name='create-lead'),
    path('leads/public/', public_lead, name='public-lead'),
    path('leads/process/', process_leads, name='process-leads'),
    path('reports/', reports, name='reports'),
    path('meta/', meta, name='meta'),
    path('meta-social/analytics/', meta_social_analytics, name='meta-social-analytics'),
    path('meta-social/sync/', meta_social_sync, name='meta-social-sync'),
    path('me/', me, name='me'),
    path('auth/signup/', signup, name='auth-signup'),
    path('auth/verify-email/', verify_email, name='auth-verify-email'),
    path('auth/login/', login, name='auth-login'),
    path('auth/forgot-password/', forgot_password, name='auth-forgot-password'),
    path('auth/reset-password/', reset_password, name='auth-reset-password'),
    path('link-requests/', link_requests, name='link-requests'),
    path('link-requests/<int:pk>/approve/', link_request_approve, name='link-request-approve'),
    path('link-requests/<int:pk>/reject/', link_request_reject, name='link-request-reject'),
    path('customer/me/', customer_me, name='customer-me'),
    path('customer/orders/', customer_orders, name='customer-orders'),
    path('customer/orders/<str:order_number>/', customer_order_detail, name='customer-order-detail'),
    path('customer/rate-card/', customer_rate_card, name='customer-rate-card'),
    path('whatsapp/neonize/status/', neonize_status, name='neonize-status'),
    path('whatsapp/neonize/connect/', neonize_connect, name='neonize-connect'),
    path('whatsapp/neonize/disconnect/', neonize_disconnect, name='neonize-disconnect'),
    path('order-media/', media_views.media_create, name='order-media-create'),
    path('order-media/<uuid:media_id>/', media_views.media_delete, name='order-media-delete'),
    path('order-media/<uuid:media_id>/content/', media_views.media_content, name='order-media-content'),
    path('order-media/<uuid:media_id>/complete/', media_views.media_complete, name='order-media-complete'),
    path('order-media/<uuid:media_id>/file/', media_views.media_file, name='order-media-file'),
    path('backup/export/', export_backup, name='backup-export'),
    path('backup/export/<str:section>/', export_section, name='backup-export-section'),
    path('backup/import/<str:section>/', import_section, name='backup-import-section'),
]

