from django.urls import path, include
from rest_framework.routers import DefaultRouter

from .views import (
    ShopViewSet, CustomerViewSet, GarmentCategoryViewSet,
    GarmentItemViewSet, OrderViewSet, ExpenseViewSet, CreditViewSet, CreditCategoryViewSet,
    StaffViewSet, AttendanceViewSet, SalaryPaymentViewSet, SalaryAdvanceViewSet,
    ServiceAreaViewSet, TimeSlotViewSet, dashboard_stats, payroll_summary,
    reports, meta, send_payroll_whatsapp, whatsapp_status, whatsapp_qr,
    rag_chat, create_lead, process_leads,
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

urlpatterns = [
    path('', include(router.urls)),
    path('dashboard/stats/', dashboard_stats, name='dashboard-stats'),
    path('payroll/', payroll_summary, name='payroll-summary'),
    path('payroll/send-slip-whatsapp/', send_payroll_whatsapp, name='send-payroll-whatsapp'),
    path('whatsapp/status/', whatsapp_status, name='whatsapp-status'),
    path('whatsapp/qr/', whatsapp_qr, name='whatsapp-qr'),
    path('rag/chat/', rag_chat, name='rag-chat'),
    path('leads/', create_lead, name='create-lead'),
    path('leads/process/', process_leads, name='process-leads'),
    path('reports/', reports, name='reports'),
    path('meta/', meta, name='meta'),
]

