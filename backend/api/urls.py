from django.urls import path, include
from rest_framework.routers import DefaultRouter

from .views import (
    ShopViewSet, CustomerViewSet, GarmentCategoryViewSet,
    GarmentItemViewSet, OrderViewSet, ExpenseViewSet,
    StaffViewSet, AttendanceViewSet, SalaryPaymentViewSet,
    ServiceAreaViewSet, TimeSlotViewSet, dashboard_stats, payroll_summary,
    reports, meta,
)

router = DefaultRouter()
router.register(r'shops', ShopViewSet)
router.register(r'customers', CustomerViewSet)
router.register(r'categories', GarmentCategoryViewSet)
router.register(r'items', GarmentItemViewSet, basename='garmentitem')
router.register(r'orders', OrderViewSet, basename='order')
router.register(r'expenses', ExpenseViewSet)
router.register(r'staff', StaffViewSet)
router.register(r'attendance', AttendanceViewSet, basename='attendance')
router.register(r'salary-payments', SalaryPaymentViewSet, basename='salarypayment')
router.register(r'service-areas', ServiceAreaViewSet)
router.register(r'time-slots', TimeSlotViewSet, basename='timeslot')

urlpatterns = [
    path('', include(router.urls)),
    path('dashboard/stats/', dashboard_stats, name='dashboard-stats'),
    path('payroll/', payroll_summary, name='payroll-summary'),
    path('reports/', reports, name='reports'),
    path('meta/', meta, name='meta'),
]
