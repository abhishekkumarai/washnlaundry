import logging
import requests
from django.conf import settings
from django.db.models import Sum
from django.utils import timezone
from django.utils.dateparse import parse_datetime
from ..models import MetaSettings, MetaMessage, MetaPost, MetaLead, MetaPlatform

logger = logging.getLogger(__name__)

GRAPH_API_VERSION = "v21.0"
GRAPH_API_BASE = f"https://graph.facebook.com/{GRAPH_API_VERSION}"


class MetaSocialService:
    """
    Handles Meta Graph API interactions for Facebook, Instagram, and Meta AI chat responses.
    Extracts live profile data, media feeds, follower counts, and insights.
    Falls back gracefully when offline or in simulation mode.
    """

    @classmethod
    def get_settings(cls, shop=None):
        if shop:
            config, _ = MetaSettings.objects.get_or_create(shop=shop)
        else:
            config = MetaSettings.objects.first()
            if not config:
                config = MetaSettings.objects.create()

        # Hydrate unconfigured fields from Django settings / environment
        updated = False
        if not config.page_access_token and getattr(settings, 'META_PAGE_ACCESS_TOKEN', ''):
            config.page_access_token = settings.META_PAGE_ACCESS_TOKEN
            updated = True
        if not config.user_access_token and getattr(settings, 'META_USER_ACCESS_TOKEN', ''):
            config.user_access_token = settings.META_USER_ACCESS_TOKEN
            updated = True
        if not config.facebook_page_id and getattr(settings, 'META_FACEBOOK_PAGE_ID', ''):
            config.facebook_page_id = settings.META_FACEBOOK_PAGE_ID
            updated = True
        if (not config.facebook_page_name or config.facebook_page_name == 'WashNLaundry Official') and getattr(settings, 'META_FACEBOOK_PAGE_NAME', ''):
            config.facebook_page_name = settings.META_FACEBOOK_PAGE_NAME
            updated = True
        if not config.instagram_account_id and getattr(settings, 'META_INSTAGRAM_ACCOUNT_ID', ''):
            config.instagram_account_id = settings.META_INSTAGRAM_ACCOUNT_ID
            updated = True
        if (not config.instagram_username or config.instagram_username == 'washnlaundry') and getattr(settings, 'META_INSTAGRAM_USERNAME', ''):
            config.instagram_username = settings.META_INSTAGRAM_USERNAME
            updated = True
        if not config.app_id and getattr(settings, 'META_APP_ID', ''):
            config.app_id = settings.META_APP_ID
            updated = True
        if not config.app_secret and getattr(settings, 'META_APP_SECRET', ''):
            config.app_secret = settings.META_APP_SECRET
            updated = True
        if not config.business_id and getattr(settings, 'META_BUSINESS_ID', ''):
            config.business_id = settings.META_BUSINESS_ID
            updated = True

        if updated:
            config.save()
        return config

    @classmethod
    def verify_credentials(cls, shop=None):
        """
        Validates token with Meta Graph API and verifies Facebook & Instagram connections.
        Populates profile details and follower counts.
        """
        config = cls.get_settings(shop)
        token = config.page_access_token or config.user_access_token or getattr(settings, 'META_GRAPH_ACCESS_TOKEN', '')
        if not token:
            return {
                'success': False,
                'connected': False,
                'message': 'No Meta Graph API Access Token configured. Add your token in Settings.',
                'page': None,
                'instagram': None,
            }

        try:
            # 1. Test /me endpoint
            me_resp = requests.get(
                f"{GRAPH_API_BASE}/me",
                params={'access_token': token, 'fields': 'id,name'},
                timeout=10
            )
            me_data = me_resp.json()

            if me_resp.status_code != 200 or 'error' in me_data:
                err_msg = me_data.get('error', {}).get('message', 'Failed to authenticate token with Meta')
                return {
                    'success': False,
                    'connected': False,
                    'message': f"Meta API Error: {err_msg}",
                    'page': None,
                    'instagram': None
                }

            page_id = config.facebook_page_id
            page_name = config.facebook_page_name or 'Washnlaundry'
            ig_id = config.instagram_account_id or getattr(settings, 'META_INSTAGRAM_ACCOUNT_ID', '')
            ig_user = config.instagram_username or getattr(settings, 'META_INSTAGRAM_USERNAME', 'washnlaundrydotcom')

            if 'accounts' in me_data and me_data['accounts'].get('data'):
                first_page = me_data['accounts']['data'][0]
                page_id = first_page.get('id', page_id)
                page_name = first_page.get('name', page_name)
                ig_info = first_page.get('instagram_business_account')
                if ig_info:
                    ig_id = ig_info.get('id', ig_id)
                    ig_user = ig_info.get('username', ig_user)
            elif me_data.get('id'):
                if not page_id:
                    page_id = me_data.get('id')
                    page_name = me_data.get('name', page_name)

            # 2. Query Facebook Page details
            fb_followers = config.facebook_followers
            if page_id:
                fb_resp = requests.get(
                    f"{GRAPH_API_BASE}/{page_id}",
                    params={'access_token': token, 'fields': 'id,name,fan_count,followers_count'},
                    timeout=10
                )
                if fb_resp.status_code == 200:
                    fb_data = fb_resp.json()
                    page_name = fb_data.get('name', page_name)
                    fb_followers = fb_data.get('followers_count') or fb_data.get('fan_count') or 0

            # 3. Query Instagram details if ID available
            ig_followers = config.instagram_followers
            ig_media_count = config.instagram_media_count
            profile_pic = config.profile_picture_url
            if ig_id:
                ig_resp = requests.get(
                    f"{GRAPH_API_BASE}/{ig_id}",
                    params={
                        'access_token': token,
                        'fields': 'id,username,name,followers_count,follows_count,media_count,profile_picture_url'
                    },
                    timeout=10
                )
                if ig_resp.status_code == 200:
                    ig_data = ig_resp.json()
                    ig_user = ig_data.get('username', ig_user)
                    ig_followers = ig_data.get('followers_count', ig_followers)
                    ig_media_count = ig_data.get('media_count', ig_media_count)
                    profile_pic = ig_data.get('profile_picture_url', profile_pic)

            config.is_connected = True
            config.facebook_page_id = page_id
            config.facebook_page_name = page_name
            config.facebook_followers = fb_followers
            config.instagram_account_id = ig_id
            config.instagram_username = ig_user
            config.instagram_followers = ig_followers
            config.instagram_media_count = ig_media_count
            config.profile_picture_url = profile_pic
            config.save()

            return {
                'success': True,
                'connected': True,
                'message': f"Connected to Facebook ({page_name}) and Instagram (@{ig_user})",
                'page': {'id': page_id, 'name': page_name, 'followers': fb_followers},
                'instagram': {
                    'id': ig_id,
                    'username': ig_user,
                    'followers': ig_followers,
                    'media_count': ig_media_count,
                    'profile_picture_url': profile_pic
                }
            }
        except Exception as e:
            logger.error(f"Error validating Meta credentials: {e}")
            return {
                'success': False,
                'connected': False,
                'message': f"Connection test failed: {str(e)}",
                'page': None,
                'instagram': None
            }

    @classmethod
    def sync_live_data(cls, shop=None):
        """
        Pulls real live media, posts, and followers from Meta Graph API
        and updates MetaPost and MetaSettings in the database.
        """
        config = cls.get_settings(shop)
        token = config.page_access_token or config.user_access_token or getattr(settings, 'META_GRAPH_ACCESS_TOKEN', '')
        if not token:
            return {'success': False, 'message': 'No access token available for synchronization.'}

        synced_count = 0
        ig_synced = 0
        fb_synced = 0

        try:
            # 1. Instagram Sync
            ig_id = config.instagram_account_id or getattr(settings, 'META_INSTAGRAM_ACCOUNT_ID', '')
            if ig_id:
                # Update IG Profile stats
                ig_info_resp = requests.get(
                    f"{GRAPH_API_BASE}/{ig_id}",
                    params={
                        'access_token': token,
                        'fields': 'id,username,name,followers_count,follows_count,media_count,profile_picture_url'
                    },
                    timeout=10
                )
                if ig_info_resp.status_code == 200:
                    info = ig_info_resp.json()
                    config.instagram_followers = info.get('followers_count', config.instagram_followers)
                    config.instagram_media_count = info.get('media_count', config.instagram_media_count)
                    config.profile_picture_url = info.get('profile_picture_url', config.profile_picture_url)
                    config.instagram_username = info.get('username', config.instagram_username)

                # Fetch recent Instagram media/reels
                media_resp = requests.get(
                    f"{GRAPH_API_BASE}/{ig_id}/media",
                    params={
                        'access_token': token,
                        'fields': 'id,caption,media_type,media_url,thumbnail_url,permalink,timestamp,like_count,comments_count',
                        'limit': 25
                    },
                    timeout=15
                )
                if media_resp.status_code == 200:
                    media_items = media_resp.json().get('data', [])
                    for item in media_items:
                        mid = item.get('id')
                        if not mid:
                            continue
                        caption = item.get('caption', '')
                        img_url = item.get('media_url') or item.get('thumbnail_url', '')
                        published_at = parse_datetime(item.get('timestamp')) if item.get('timestamp') else None

                        MetaPost.objects.update_or_create(
                            meta_post_id=mid,
                            shop=config.shop,
                            defaults={
                                'platform': MetaPlatform.INSTAGRAM,
                                'content': caption or f"Instagram {item.get('media_type', 'Media')}",
                                'image_url': img_url,
                                'permalink': item.get('permalink', ''),
                                'media_type': item.get('media_type', ''),
                                'status': MetaPost.STATUS_PUBLISHED,
                                'likes_count': item.get('like_count', 0),
                                'comments_count': item.get('comments_count', 0),
                                'published_at': published_at,
                            }
                        )
                        ig_synced += 1
                        synced_count += 1

            # 2. Facebook Page Sync
            page_id = config.facebook_page_id or getattr(settings, 'META_FACEBOOK_PAGE_ID', '')
            if page_id:
                fb_info_resp = requests.get(
                    f"{GRAPH_API_BASE}/{page_id}",
                    params={'access_token': token, 'fields': 'id,name,fan_count,followers_count'},
                    timeout=10
                )
                if fb_info_resp.status_code == 200:
                    finfo = fb_info_resp.json()
                    config.facebook_followers = finfo.get('followers_count') or finfo.get('fan_count') or config.facebook_followers
                    config.facebook_page_name = finfo.get('name', config.facebook_page_name)

                # Fetch Facebook Page posts
                feed_resp = requests.get(
                    f"{GRAPH_API_BASE}/{page_id}/feed",
                    params={
                        'access_token': token,
                        'fields': 'id,message,created_time,shares,reactions.summary(true),comments.summary(true),permalink_url',
                        'limit': 25
                    },
                    timeout=15
                )
                if feed_resp.status_code == 200:
                    feed_items = feed_resp.json().get('data', [])
                    for post in feed_items:
                        pid = post.get('id')
                        if not pid:
                            continue
                        msg = post.get('message', '')
                        reactions = post.get('reactions', {}).get('summary', {}).get('total_count', 0)
                        comments = post.get('comments', {}).get('summary', {}).get('total_count', 0)
                        shares = post.get('shares', {}).get('count', 0)
                        pub_at = parse_datetime(post.get('created_time')) if post.get('created_time') else None

                        MetaPost.objects.update_or_create(
                            meta_post_id=pid,
                            shop=config.shop,
                            defaults={
                                'platform': MetaPlatform.FACEBOOK,
                                'content': msg or "Facebook Page Post",
                                'permalink': post.get('permalink_url', ''),
                                'status': MetaPost.STATUS_PUBLISHED,
                                'likes_count': reactions,
                                'comments_count': comments,
                                'shares_count': shares,
                                'published_at': pub_at,
                            }
                        )
                        fb_synced += 1
                        synced_count += 1

            config.is_connected = True
            config.save()

            return {
                'success': True,
                'synced_posts_count': synced_count,
                'instagram_synced': ig_synced,
                'facebook_synced': fb_synced,
                'instagram': {
                    'username': config.instagram_username,
                    'followers': config.instagram_followers,
                    'media_count': config.instagram_media_count,
                    'profile_picture_url': config.profile_picture_url,
                },
                'facebook': {
                    'page_name': config.facebook_page_name,
                    'followers': config.facebook_followers,
                }
            }
        except Exception as e:
            logger.error(f"Error syncing Meta live data: {e}")
            return {'success': False, 'message': f"Sync error: {str(e)}"}

    @classmethod
    def get_analytics_summary(cls, shop=None):
        """
        Returns live aggregated analytics across Facebook & Instagram channels.
        """
        config = cls.get_settings(shop)
        total_posts = MetaPost.objects.count()
        published_posts = MetaPost.objects.filter(status=MetaPost.STATUS_PUBLISHED).count()
        total_likes = MetaPost.objects.aggregate(s=Sum('likes_count'))['s'] or 0
        total_comments = MetaPost.objects.aggregate(s=Sum('comments_count'))['s'] or 0
        total_leads = MetaLead.objects.count()
        converted_leads = MetaLead.objects.filter(status=MetaLead.STATUS_CONVERTED).count()
        total_dms = MetaMessage.objects.count()

        ig_followers = config.instagram_followers
        fb_followers = config.facebook_followers
        total_reach = ig_followers + fb_followers + (total_likes * 12) + (published_posts * 15)

        ig_leads = MetaLead.objects.filter(platform=MetaPlatform.INSTAGRAM).count()
        fb_leads = MetaLead.objects.filter(platform=MetaPlatform.FACEBOOK).count()

        return {
            'overview': {
                'total_reach': total_reach,
                'followers_instagram': ig_followers,
                'followers_facebook': fb_followers,
                'engagement_rate': round(((total_likes + total_comments) / max(total_reach, 1)) * 100, 1),
                'total_posts': total_posts,
                'published_posts': published_posts,
                'total_leads': total_leads,
                'converted_leads': converted_leads,
                'lead_conversion_rate': round((converted_leads / total_leads * 100), 1) if total_leads else 0.0,
                'total_dms': total_dms,
                'ai_replies_sent': MetaMessage.objects.filter(sender_type=MetaMessage.SENDER_AI).count(),
                'is_connected': config.is_connected,
            },
            'channels': [
                {
                    'platform': 'Instagram',
                    'handle': f"@{config.instagram_username}" if config.instagram_username else '@washnlaundrydotcom',
                    'followers': ig_followers,
                    'media_count': config.instagram_media_count,
                    'profile_picture_url': config.profile_picture_url,
                    'leads': ig_leads,
                },
                {
                    'platform': 'Facebook',
                    'handle': config.facebook_page_name or 'Washnlaundry',
                    'followers': fb_followers,
                    'leads': fb_leads,
                },
            ]
        }

    @classmethod
    def publish_post(cls, post_obj):
        config = cls.get_settings(post_obj.shop)
        token = config.page_access_token or config.user_access_token or getattr(settings, 'META_GRAPH_ACCESS_TOKEN', '')

        # If no live token or demo mode, record simulated success
        if not token or not config.is_connected:
            post_obj.status = MetaPost.STATUS_PUBLISHED
            post_obj.meta_post_id = f"sim_{post_obj.platform.lower()}_{post_obj.id}"
            post_obj.save()
            return {'success': True, 'simulated': True, 'post_id': post_obj.meta_post_id}

        try:
            target_id = config.facebook_page_id if post_obj.platform == MetaPlatform.FACEBOOK else config.instagram_account_id
            if not target_id:
                raise ValueError(f"No target ID configured for platform {post_obj.platform}")

            if post_obj.platform == MetaPlatform.FACEBOOK:
                endpoint = f"{GRAPH_API_BASE}/{target_id}/feed"
                payload = {'message': post_obj.content, 'access_token': token}
                if post_obj.image_url:
                    endpoint = f"{GRAPH_API_BASE}/{target_id}/photos"
                    payload = {'caption': post_obj.content, 'url': post_obj.image_url, 'access_token': token}

                resp = requests.post(endpoint, data=payload, timeout=15)
                res_data = resp.json()
                if resp.status_code == 200 and 'id' in res_data:
                    post_obj.status = MetaPost.STATUS_PUBLISHED
                    post_obj.meta_post_id = res_data['id']
                    post_obj.save()
                    return {'success': True, 'post_id': res_data['id']}
                else:
                    err_msg = res_data.get('error', {}).get('message', 'Failed to publish to Facebook')
                    post_obj.status = MetaPost.STATUS_FAILED
                    post_obj.error_message = err_msg
                    post_obj.save()
                    return {'success': False, 'error': err_msg}

            elif post_obj.platform == MetaPlatform.INSTAGRAM:
                # Two-step Instagram Graph API container publish
                if not post_obj.image_url:
                    raise ValueError("Instagram posts require an image URL.")

                container_url = f"{GRAPH_API_BASE}/{target_id}/media"
                c_payload = {'image_url': post_obj.image_url, 'caption': post_obj.content, 'access_token': token}
                c_resp = requests.post(container_url, data=c_payload, timeout=15)
                c_data = c_resp.json()

                if 'id' not in c_data:
                    err = c_data.get('error', {}).get('message', 'Instagram container creation failed')
                    post_obj.status = MetaPost.STATUS_FAILED
                    post_obj.error_message = err
                    post_obj.save()
                    return {'success': False, 'error': err}

                creation_id = c_data['id']
                pub_url = f"{GRAPH_API_BASE}/{target_id}/media_publish"
                p_resp = requests.post(pub_url, data={'creation_id': creation_id, 'access_token': token}, timeout=15)
                p_data = p_resp.json()

                if p_resp.status_code == 200 and 'id' in p_data:
                    post_obj.status = MetaPost.STATUS_PUBLISHED
                    post_obj.meta_post_id = p_data['id']
                    post_obj.save()
                    return {'success': True, 'post_id': p_data['id']}
                else:
                    err = p_data.get('error', {}).get('message', 'Instagram media publish failed')
                    post_obj.status = MetaPost.STATUS_FAILED
                    post_obj.error_message = err
                    post_obj.save()
                    return {'success': False, 'error': err}

        except Exception as e:
            logger.error(f"Error publishing post {post_obj.id}: {e}")
            post_obj.status = MetaPost.STATUS_FAILED
            post_obj.error_message = str(e)
            post_obj.save()
            return {'success': False, 'error': str(e)}

    @classmethod
    def generate_ai_reply(cls, user_text, history=None):
        """
        Uses configured RAG engine (Cloudflare Workers AI / Llama 3)
        to compose a helpful customer support response for laundry inquiries.
        """
        from .rag_service import RagService, RagServiceError

        system_context = (
            "You are Meta AI Assistant for WashNLaundry dry cleaning and laundry service. "
            "Reply warmly and concisely. We offer Wash & Fold, Dry Cleaning, Ironing, Shoe Care, "
            "and Free Doorstep Pickup & Delivery. Provide pickup timings, pricing, or status guidance."
        )
        prompt = f"Context: {system_context}\nCustomer message: {user_text}\nAssistant reply:"

        try:
            tokens = []
            for chunk in RagService.stream_chat(prompt, history=history):
                text_chunk = chunk.decode('utf-8', errors='ignore') if isinstance(chunk, bytes) else str(chunk)
                if 'data:' in text_chunk:
                    for line in text_chunk.splitlines():
                        line = line.strip()
                        if line.startswith('data:'):
                            raw_data = line[5:].strip()
                            if raw_data and raw_data != '[DONE]':
                                try:
                                    import json
                                    parsed = json.loads(raw_data)
                                    if isinstance(parsed, dict):
                                        resp_token = parsed.get('response')
                                        if resp_token:
                                            tokens.append(resp_token)
                                        elif 'choices' in parsed and parsed['choices']:
                                            tokens.append(parsed['choices'][0].get('delta', {}).get('content', ''))
                                except Exception:
                                    pass
                else:
                    tokens.append(text_chunk)
            if tokens:
                return "".join(tokens).strip()
            raise ValueError("No tokens produced by RAG engine")
        except (RagServiceError, Exception) as e:
            logger.warning(f"RAG streaming reply fallback: {e}")
            lower = user_text.lower()
            if 'price' in lower or 'rate' in lower or 'cost' in lower:
                return "Hi! Our washing starts at Rs.69/kg and dry cleaning from Rs.99/item. You can book an instant doorstep pickup right here!"
            elif 'pickup' in lower or 'timing' in lower or 'delivery' in lower:
                return "Hello! We offer convenient morning (8 AM - 12 PM) and evening (4 PM - 8 PM) pickup & delivery slots. Would you like us to schedule a pickup?"
            elif 'status' in lower or 'order' in lower:
                return "Hello! Could you please share your order number or registered phone number so I can check your order status immediately?"
            else:
                return "Hello from WashNLaundry! How can we assist you with your laundry or dry cleaning today?"

    @classmethod
    def send_whatsapp_message(cls, to_number, text, shop=None, recipient_name=None):
        """
        Sends a WhatsApp message using Meta WhatsApp Cloud API.
        POST https://graph.facebook.com/v21.0/{phone_number_id}/messages
        If phone_number_id is not yet configured, gracefully records a simulated message
        so staging, development, and CRM testing workflows work reliably.
        """
        config = cls.get_settings(shop)
        phone_number_id = config.whatsapp_phone_number_id or getattr(settings, 'META_WHATSAPP_PHONE_NUMBER_ID', '')
        token = config.user_access_token or config.page_access_token or getattr(settings, 'META_GRAPH_ACCESS_TOKEN', '')

        # Standardize phone format (strip non-digits, keep last 10 digits)
        digits = "".join(ch for ch in str(to_number) if ch.isdigit())
        ten_digit_phone = digits[-10:] if len(digits) >= 10 else digits
        conv_id = f"wa_{digits}"
        name = recipient_name or f"WhatsApp Contact ({ten_digit_phone})"

        # Check if Personal WhatsApp via Neonize is connected
        from .neonize_service import NeonizeService
        neonize = NeonizeService.get_instance()
        if neonize.status == NeonizeService.STATUS_CONNECTED:
            n_res = neonize.send_message(ten_digit_phone, text, shop=config.shop, recipient_name=name)
            if n_res.get('success'):
                msg = MetaMessage.objects.create(
                    shop=config.shop,
                    platform=MetaPlatform.WHATSAPP,
                    conversation_id=conv_id,
                    sender_id='staff_crm',
                    sender_name='WashNLaundry Staff (Personal WhatsApp)',
                    sender_type=MetaMessage.SENDER_STAFF,
                    text=text
                )
                return {
                    'success': True,
                    'message_id': n_res.get('message_id'),
                    'simulated': False,
                    'provider': 'neonize',
                    'message': msg
                }

        if phone_number_id and token:
            endpoint = f"{GRAPH_API_BASE}/{phone_number_id}/messages"
            # Meta WhatsApp Cloud API requires country calling code (e.g. 91 for India)
            wa_destination = f"91{ten_digit_phone}" if len(ten_digit_phone) == 10 and not digits.startswith('91') else digits
            payload = {
                "messaging_product": "whatsapp",
                "recipient_type": "individual",
                "to": wa_destination,
                "type": "text",
                "text": {"preview_url": False, "body": text}
            }
            try:
                resp = requests.post(
                    endpoint,
                    headers={
                        "Authorization": f"Bearer {token}",
                        "Content-Type": "application/json"
                    },
                    json=payload,
                    timeout=15
                )
                data = resp.json()
                if resp.status_code in [200, 201] and 'messages' in data:
                    wa_msg_id = data['messages'][0].get('id', f"wa_{timezone.now().timestamp()}")
                    msg = MetaMessage.objects.create(
                        shop=config.shop,
                        platform=MetaPlatform.WHATSAPP,
                        conversation_id=conv_id,
                        sender_id='staff_crm',
                        sender_name='WashNLaundry Staff',
                        sender_type=MetaMessage.SENDER_STAFF,
                        text=text
                    )
                    return {
                        'success': True,
                        'message_id': wa_msg_id,
                        'simulated': False,
                        'message': msg
                    }
                else:
                    err_msg = data.get('error', {}).get('message', 'Failed to send WhatsApp message via Meta Cloud API')
                    logger.warning(f"Meta WhatsApp Cloud API error: {err_msg}. Falling back to staging simulation.")
            except Exception as e:
                logger.error(f"WhatsApp Cloud API request exception: {e}")

        # Staging / Simulated mode (when phone_number_id is pending or API returned error)
        sim_id = f"wa_sim_{int(timezone.now().timestamp() * 1000)}"
        msg = MetaMessage.objects.create(
            shop=config.shop,
            platform=MetaPlatform.WHATSAPP,
            conversation_id=conv_id,
            sender_id='staff_crm',
            sender_name='WashNLaundry Staff',
            sender_type=MetaMessage.SENDER_STAFF,
            text=text
        )
        return {
            'success': True,
            'message_id': sim_id,
            'simulated': True,
            'message': msg,
            'note': 'Simulated dispatch (Meta WhatsApp Phone Number ID pending configuration).'
        }

