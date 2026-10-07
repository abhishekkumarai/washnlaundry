from django.contrib import admin

from .models import EmailLinkRequest


@admin.register(EmailLinkRequest)
class EmailLinkRequestAdmin(admin.ModelAdmin):
    list_display = ('email', 'customer', 'status', 'created_at')
    list_filter = ('status',)
    actions = ['approve']

    @admin.action(description='Approve: attach the email to the customer')
    def approve(self, request, queryset):
        done = sum(1 for r in queryset if r.approve())
        self.message_user(request, f'{done} of {queryset.count()} approved.')
