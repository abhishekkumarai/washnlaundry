from django.contrib.auth.models import User
from django.test import TestCase
from rest_framework.test import APIRequestFactory, force_authenticate

from .models import GarmentCategory, GarmentItem, Shop, ShopMembership, ShopRole
from .serializers import GarmentCategorySerializer
from .views import GarmentCategoryViewSet, GarmentItemViewSet


class GarmentCategoryTagsTestCase(TestCase):
    def setUp(self):
        self.factory = APIRequestFactory()
        self.shop = Shop.objects.create(name='Tag Laundry Shop', order_prefix='TAG')
        self.user = User.objects.create_user(username='shopowner', email='owner@example.com', password='password123')
        ShopMembership.objects.create(shop=self.shop, user=self.user, role=ShopRole.OWNER)

        self.cat1 = GarmentCategory.objects.create(
            shop=self.shop,
            name='Dry Cleaning',
            tags=['express', 'delicate', 'premium'],
            display_order=1,
            is_active=True,
        )
        self.cat2 = GarmentCategory.objects.create(
            shop=self.shop,
            name='Wash and Fold',
            tags=['daily', 'bulk', 'economy'],
            display_order=2,
            is_active=True,
        )

        self.item1 = GarmentItem.objects.create(
            shop=self.shop,
            category=self.cat1,
            name='Silk Saree',
            price=250.0,
            is_active=True,
        )
        self.item2 = GarmentItem.objects.create(
            shop=self.shop,
            category=self.cat2,
            name='Cotton Bedsheet',
            price=80.0,
            is_active=True,
        )

    def test_category_tags_storage(self):
        cat = GarmentCategory.objects.get(id=self.cat1.id)
        self.assertEqual(cat.tags, ['express', 'delicate', 'premium'])

    def test_serializer_tags_validation_and_cleaning(self):
        # List of tags with whitespace and duplicates
        data = {
            'name': 'Steam Ironing',
            'tags': [' express ', 'quick', 'express', '  ', 'daily'],
            'is_active': True,
        }
        serializer = GarmentCategorySerializer(data=data)
        self.assertTrue(serializer.is_valid(), serializer.errors)
        self.assertEqual(serializer.validated_data['tags'], ['express', 'quick', 'daily'])

        # Comma-separated string format
        data_str = {
            'name': 'Shoes Care',
            'tags': 'leather, sports , shoes, leather',
            'is_active': True,
        }
        serializer2 = GarmentCategorySerializer(data=data_str)
        self.assertTrue(serializer2.is_valid(), serializer2.errors)
        self.assertEqual(serializer2.validated_data['tags'], ['leather', 'sports', 'shoes'])

    def test_category_viewset_tag_filtering(self):
        view = GarmentCategoryViewSet.as_view({'get': 'list'})
        request = self.factory.get('/api/categories/?tag=delicate')
        force_authenticate(request, user=self.user)
        request.tenant = self.shop
        response = view(request)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]['name'], 'Dry Cleaning')

    def test_category_viewset_search_by_tag(self):
        view = GarmentCategoryViewSet.as_view({'get': 'list'})
        request = self.factory.get('/api/categories/?search=bulk')
        force_authenticate(request, user=self.user)
        request.tenant = self.shop
        response = view(request)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(len(response.data), 1)
        self.assertEqual(response.data[0]['name'], 'Wash and Fold')

    def test_item_viewset_search_by_category_tag(self):
        view = GarmentItemViewSet.as_view({'get': 'list'})
        # Searching "express" matches Silk Saree because its category has tag "express"
        request = self.factory.get('/api/items/?search=express')
        force_authenticate(request, user=self.user)
        request.tenant = self.shop
        response = view(request)
        self.assertEqual(response.status_code, 200)
        item_names = [item['name'] for item in response.data]
        self.assertIn('Silk Saree', item_names)
        self.assertNotIn('Cotton Bedsheet', item_names)
