from django.db import migrations, models


def copy_category_tags_to_items(apps, schema_editor):
    """Tags used to live on the category; carry them down so none are lost."""
    GarmentItem = apps.get_model('api', 'GarmentItem')
    for item in GarmentItem.objects.select_related('category').iterator():
        tags = item.category.tags or []
        if tags and not item.tags:
            item.tags = list(tags)
            item.save(update_fields=['tags'])


class Migration(migrations.Migration):

    dependencies = [
        ("api", "0040_garmentcategory_tags"),
    ]

    operations = [
        migrations.AddField(
            model_name="garmentitem",
            name="tags",
            field=models.JSONField(blank=True, default=list),
        ),
        migrations.RunPython(copy_category_tags_to_items, migrations.RunPython.noop),
    ]
