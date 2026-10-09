import json
from unittest import mock
from django.test import TestCase, override_settings
from rest_framework.test import APIClient
from api.models import MetaSettings, MetaPost, MetaMessage, MetaLead, Shop, Order
from api.services.neonize_service import NeonizeService

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

    def test_meta_social_sync(self):
        with mock.patch('requests.get') as mock_get:
            def side_effect(url, **kwargs):
                resp = mock.MagicMock()
                resp.status_code = 200
                if '/media' in url:
                    resp.json.return_value = {
                        'data': [
                            {
                                'id': 'ig_media_999',
                                'caption': 'Synced Reel Caption',
                                'media_type': 'VIDEO',
                                'media_url': 'https://example.com/reel.mp4',
                                'permalink': 'https://instagram.com/reel/123/',
                                'timestamp': '2026-10-09T10:37:58+0000',
                                'like_count': 10,
                                'comments_count': 2,
                            }
                        ]
                    }
                elif '/feed' in url:
                    resp.json.return_value = {'data': []}
                else:
                    resp.json.return_value = {
                        'id': '17841422947561202',
                        'username': 'washnlaundrydotcom',
                        'followers_count': 120,
                        'media_count': 5,
                        'profile_picture_url': 'https://example.com/pic.jpg',
                    }
                return resp

            mock_get.side_effect = side_effect
            res = self.client.post('/api/meta-social/sync/')
            self.assertEqual(res.status_code, 200)
            data = res.json()
            self.assertTrue(data['success'])
            self.assertEqual(data['synced_posts_count'], 1)
            self.assertTrue(MetaPost.objects.filter(meta_post_id='ig_media_999').exists())

    def test_send_whatsapp_simulated(self):
        """When phone_number_id is pending, send_whatsapp should gracefully simulate and store in MetaMessage."""
        res = self.client.post('/api/meta-messages/send-whatsapp/', {
            'phone': '+919876543210',
            'text': 'Hello, your laundry is scheduled for tomorrow at 10 AM.',
            'recipient_name': 'Aarav Sharma'
        }, format='json')
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertTrue(data['success'])
        self.assertTrue(data['simulated'])
        self.assertEqual(data['conversation_id'], 'wa_919876543210')
        self.assertTrue(MetaMessage.objects.filter(conversation_id='wa_919876543210', platform='WHATSAPP').exists())

    @mock.patch('requests.post')
    def test_send_whatsapp_live(self, mock_post):
        """When phone_number_id is configured, call Meta Cloud API."""
        self.settings.whatsapp_phone_number_id = 'wa_phone_id_12345'
        self.settings.save()

        mock_resp = mock.MagicMock()
        mock_resp.status_code = 200
        mock_resp.json.return_value = {
            'messaging_product': 'whatsapp',
            'contacts': [{'input': '919876543210', 'wa_id': '919876543210'}],
            'messages': [{'id': 'wamid.HBgLMTIzNDU='}]
        }
        mock_post.return_value = mock_resp

        res = self.client.post('/api/meta-messages/send-whatsapp/', {
            'phone': '919876543210',
            'text': 'Your clothes are dry cleaned and ready!',
        }, format='json')
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertTrue(data['success'])
        self.assertFalse(data['simulated'])
        self.assertEqual(data['message_id'], 'wamid.HBgLMTIzNDU=')
        self.assertTrue(MetaMessage.objects.filter(conversation_id='wa_919876543210', platform='WHATSAPP').exists())

    @mock.patch.object(NeonizeService, '_start_neonize_thread')
    def test_neonize_status_and_pairing(self, mock_start_thread):
        """Verify Neonize status, QR pairing generation, and disconnection."""
        # 1. Check initial status
        res = self.client.get('/api/whatsapp/neonize/status/')
        self.assertEqual(res.status_code, 200)
        data = res.json()
        self.assertTrue(data['success'])
        self.assertIn('status', data)

        # 2. Trigger QR pairing
        res_connect = self.client.post('/api/whatsapp/neonize/connect/')
        self.assertEqual(res_connect.status_code, 200)
        connect_data = res_connect.json()
        self.assertEqual(connect_data['status'], 'pairing')
        self.assertTrue(connect_data['has_qr'])
        self.assertTrue(connect_data['qr_code'].startswith('data:image/png;base64,'))

        # 3. Disconnect
        res_dc = self.client.post('/api/whatsapp/neonize/disconnect/')
        self.assertEqual(res_dc.status_code, 200)
        dc_data = res_dc.json()
        self.assertEqual(dc_data['status'], 'disconnected')


