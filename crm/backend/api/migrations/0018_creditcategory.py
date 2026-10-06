import django.db.models.deletion
from django.db import migrations, models

# Frozen copy rather than an import of models.DEFAULT_CREDIT_CATEGORIES, so
# later edits to the default list can't change what this migration did.
DEFAULTS = [
    'Laundry Income',
    'Dry Cleaning Income',
    'Delivery Charges',
    'Customer Advance',
    'Owner Investment',
    'Other',
]


def seed_and_link(apps, schema_editor):
    CreditCategory = apps.get_model('api', 'CreditCategory')
    Credit = apps.get_model('api', 'Credit')
    for order, name in enumerate(DEFAULTS):
        CreditCategory.objects.get_or_create(name=name, defaults={'display_order': order})
    # Credits filed under an old fixed choice ("Service Income", …) keep that
    # label as a category of its own rather than being silently re-filed.
    next_order = len(DEFAULTS)
    for credit in Credit.objects.all():
        name = (credit.category or '').strip() or 'Other'
        category, created = CreditCategory.objects.get_or_create(
            name=name, defaults={'display_order': next_order})
        if created:
            next_order += 1
        credit.category_ref = category
        credit.save(update_fields=['category_ref'])


class Migration(migrations.Migration):

    dependencies = [
        ('api', '0017_credit'),
    ]

    operations = [
        migrations.CreateModel(
            name='CreditCategory',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('name', models.CharField(max_length=100, unique=True)),
                ('display_order', models.IntegerField(default=0)),
                ('is_active', models.BooleanField(default=True)),
            ],
            options={
                'verbose_name_plural': 'Credit categories',
                'ordering': ['display_order', 'name'],
            },
        ),
        migrations.AddField(
            model_name='credit',
            name='category_ref',
            field=models.ForeignKey(null=True, on_delete=django.db.models.deletion.PROTECT, related_name='+', to='api.creditcategory'),
        ),
        migrations.RunPython(seed_and_link, migrations.RunPython.noop),
        migrations.RemoveField(model_name='credit', name='category'),
        migrations.RenameField(model_name='credit', old_name='category_ref', new_name='category'),
        migrations.AlterField(
            model_name='credit',
            name='category',
            field=models.ForeignKey(on_delete=django.db.models.deletion.PROTECT, related_name='credits', to='api.creditcategory'),
        ),
    ]
