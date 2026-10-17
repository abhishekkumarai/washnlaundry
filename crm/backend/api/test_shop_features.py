"""Per-shop features (Social Suite, Chat): off by default, switched on per shop by a
superuser, and enforced by the API as well as hidden in the app."""
from io import StringIO
from unittest import mock

from django.contrib.auth import get_user_model
from django.core.management import call_command
from django.test import TestCase, override_settings
from rest_framework.test import APIClient

from api.models import Shop, ShopMembership, ShopRole

SOCIAL_PATHS = ('/api/meta-settings/', '/api/meta-posts/', '/api/meta-messages/', '/api/meta-leads/',
                '/api/meta-social/analytics/', '/api/whatsapp/neonize/status/')


@override_settings(GOOGLE_CLIENT_ID='c', API_AUTH_ENFORCED=True)
class ShopFeatureTests(TestCase):
    def setUp(self):
        self.on = Shop.objects.create(name='On Wash', slug='on-wash', social_suite_enabled=True,
                                      chat_enabled=True)
        self.off = Shop.objects.create(name='Off Wash', slug='off-wash')
        owner = get_user_model().objects.create_user('owner@x.com', 'owner@x.com', 'pw')
        for shop in (self.on, self.off):
            ShopMembership.objects.create(user=owner, shop=shop, role=ShopRole.OWNER)
        patcher = mock.patch('api.auth.id_token.verify_oauth2_token',
                             return_value={'email': 'owner@x.com', 'email_verified': True})
        patcher.start()
        self.addCleanup(patcher.stop)
        self.client = APIClient()

    def get(self, path, shop):
        return self.client.get(path, HTTP_AUTHORIZATION='Bearer tok', HTTP_X_TENANT_ID=shop.slug)

    def chat(self, shop):
        return self.client.post('/api/rag/chat/', {'message': 'hi'}, format='json',
                                HTTP_X_TENANT_ID=shop.slug)

    def test_off_by_default(self):
        shop = Shop.objects.create(name='New', slug='new')
        self.assertFalse(shop.social_suite_enabled)
        self.assertFalse(shop.chat_enabled)

    def test_social_suite_api_is_closed_for_a_shop_without_it_even_for_its_owner(self):
        for path in SOCIAL_PATHS:
            self.assertEqual(self.get(path, self.off).status_code, 403, path)
            self.assertNotEqual(self.get(path, self.on).status_code, 403, path)

    def test_chat_proxy_is_closed_for_a_shop_without_it(self):
        self.assertEqual(self.chat(self.off).status_code, 403)
        with mock.patch('api.views.RagService.stream_chat', return_value=iter([b'data: {}\n\n'])):
            self.assertEqual(self.chat(self.on).status_code, 200)

    def test_dropdown_vocabularies_are_not_part_of_social_suite(self):
        self.assertEqual(self.get('/api/meta/', self.off).status_code, 200)

    def test_me_reports_both_switches_for_the_active_shop(self):
        on = self.get('/api/me/', self.on).json()['shop']
        off = self.get('/api/me/', self.off).json()['shop']
        self.assertEqual((on['social_suite_enabled'], on['chat_enabled']), (True, True))
        self.assertEqual((off['social_suite_enabled'], off['chat_enabled']), (False, False))

    def test_an_owner_cannot_switch_them_on_themselves(self):
        for field in ('social_suite_enabled', 'chat_enabled'):
            res = self.client.patch(f'/api/shops/{self.off.id}/', {field: True}, format='json',
                                    HTTP_AUTHORIZATION='Bearer tok', HTTP_X_TENANT_ID=self.off.slug)
            self.assertEqual(res.status_code, 403, field)
        self.off.refresh_from_db()
        self.assertFalse(self.off.social_suite_enabled or self.off.chat_enabled)

    def test_shop_feature_command(self):
        call_command('shop_feature', 'off-wash', 'chat', 'on', stdout=StringIO())
        self.off.refresh_from_db()
        self.assertTrue(self.off.chat_enabled)
        self.assertFalse(self.off.social_suite_enabled)  # one feature at a time
        out = StringIO()
        call_command('shop_feature', stdout=out)
        self.assertIn('off-wash', out.getvalue())
        self.assertIn('chat', out.getvalue())
        call_command('shop_feature', 'off-wash', 'chat', 'off', stdout=StringIO())
        call_command('shop_feature', 'off-wash', 'social_suite', 'on', stdout=StringIO())
        self.off.refresh_from_db()
        self.assertEqual((self.off.chat_enabled, self.off.social_suite_enabled), (False, True))
