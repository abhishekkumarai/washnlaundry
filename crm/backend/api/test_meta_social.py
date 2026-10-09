import json
from unittest import mock
from django.test import TestCase, override_settings
from rest_framework.test import APIClient
from api.models import MetaSettings, MetaPost, MetaMessage, MetaLead, Shop, Order

class MetaSocialTests(TestCase):
    def setUp(self):
        self.client = APIClient()
        self.shop = Shop.objects.first() or Shop.objects.create(name='Test Wash')
        self.settings = MetaSettings.objects.create(
            shop=self.shop,
            facebook_page_name='Test Laundry FB',
            instagram_username='test_laundry_ig',
            page_access_token='EAABdummytoken123',
            auto_reply_enabled=True,
        )

    def test_get_meta_settings(self):
        res = self.client.get('/api/meta-settings/')
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertEqual(data['facebook_page_name'], 'Test Laundry FB')
        self.assertEqual(data['instagram_username'], 'test_laundry_ig')

    def test_verify_credentials(self):
        with mock.patch('requests.get') as mock_get:
            mock_get.return_value.status_code = 200
            mock_get.return_value.json.return_value = {
                'id': 'page_123',
                'name': 'Wash & Laundry Co',
                'accounts': {
                    'data': [
                        {
                            'id': 'page_123',
                            'name': 'Wash & Laundry Co',
                            'instagram_business_account': {
                                'id': 'ig_456',
                                'username': 'washlaundry_official'
                            }
                        }
                    ]
                }
            }
            res = self.client.post('/api/meta-settings/verify/')
            self.assertEqual(res.status_code, 200)
            data = res.json()
            self.assertTrue(data['success'])
            self.assertTrue(data['connected'])
            self.assertEqual(data['page']['id'], 'page_123')
            self.assertEqual(data['instagram']['username'], 'washlaundry_official')

    def test_create_and_publish_post(self):
        res = self.client.post('/api/meta-posts/', {
            'platform': 'INSTAGRAM',
            'content': 'Special Weekend 20% Off on Dry Cleaning!',
            'image_url': 'https://example.com/banner.jpg',
            'status': 'PUBLISHED',
        }, format='json')
        self.assertEqual(res.status_code, 201)
        post_id = res.json()['id']
        post = MetaPost.objects.get(id=post_id)
        self.assertEqual(post.status, 'PUBLISHED')
        self.assertTrue(post.meta_post_id.startswith('sim_instagram_'))

    def test_meta_ai_reply_flow(self):
        with mock.patch('api.services.rag_service.RagService.stream_chat') as mock_rag:
            mock_rag.return_value = iter(["Hello! ", "Doorstep pickup ", "is available."])
            res = self.client.post('/api/meta-messages/reply/', {
                'conversation_id': 'conv_test_1',
                'platform': 'INSTAGRAM',
                'sender_name': 'Priya S',
                'text': 'Can I book a pickup today?',
                'use_ai': True,
            }, format='json')
            self.assertEqual(res.status_code, 200)
            data = res.json()
            self.assertIsNotNone(data['user_message'])
            self.assertIsNotNone(data['ai_message'])
            self.assertEqual(data['ai_message']['text'], 'Hello! Doorstep pickup is available.')

    def test_meta_leads_and_order_conversion(self):
        lead = MetaLead.objects.create(
            platform='INSTAGRAM',
            customer_name='Rohit Verma',
            customer_phone='9811223344',
            inquiry_notes='Interested in monthly subscription for suits',
        )
        res = self.client.post(f'/api/meta-leads/{lead.id}/convert/')
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertTrue(data['success'])
        lead.refresh_from_db()
        self.assertEqual(lead.status, 'CONVERTED')
        self.assertIsNotNone(lead.converted_order)
        self.assertEqual(lead.converted_order.customer_name, 'Rohit Verma')

    def test_meta_social_analytics(self):
        MetaPost.objects.create(content='Hello FB', platform='FACEBOOK', status='PUBLISHED', likes_count=15)
        MetaLead.objects.create(customer_name='Lead 1', platform='FACEBOOK')
        res = self.client.get('/api/meta-social/analytics/')
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertIn('overview', data)
        self.assertIn('channels', data)
        self.assertGreaterEqual(data['overview']['total_posts'], 1)
