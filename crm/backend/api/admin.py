from django.contrib import admin

from .models import EmailLinkRequest, OrderIssue


@admin.register(OrderIssue)
class OrderIssueAdmin(admin.ModelAdmin):
    list_display = ('order', 'category', 'customer', 'shop', 'status', 'created_at')
    list_filter = ('status', 'category')
    search_fields = ('order__order_number', 'customer__name', 'message')
    raw_id_fields = ('order', 'customer')


@admin.register(EmailLinkRequest)
class EmailLinkRequestAdmin(admin.ModelAdmin):
    list_display = ('email', 'customer', 'status', 'created_at')
    list_filter = ('status',)
    actions = ['approve']

    @admin.action(description='Approve: attach the email to the customer')
    def approve(self, request, queryset):
        done = sum(1 for r in queryset if r.approve())
        self.message_user(request, f'{done} of {queryset.count()} approved.')
