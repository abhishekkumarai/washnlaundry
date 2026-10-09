import logging
import requests
from django.conf import settings
from ..models import MetaSettings, MetaMessage, MetaPost, MetaLead

logger = logging.getLogger(__name__)

GRAPH_API_VERSION = "v19.0"
GRAPH_API_BASE = f"https://graph.facebook.com/{GRAPH_API_VERSION}"

class MetaSocialService:
    """
    Handles Meta Graph API interactions for Facebook, Instagram, and Meta AI chat responses.
    Gracefully falls back to local simulation mode when no valid Meta API token is set,
    allowing full CRM workflow development and testing.
    """

    @classmethod
    def get_settings(cls, shop=None):
        if shop:
            config, _ = MetaSettings.objects.get_or_create(shop=shop)
            return config
        config = MetaSettings.objects.first()
        if not config:
            config = MetaSettings.objects.create()
        return config

    @classmethod
    def verify_credentials(cls, shop=None):
        config = cls.get_settings(shop)
        token = config.page_access_token or getattr(settings, 'META_GRAPH_ACCESS_TOKEN', '')
        if not token:
            return {
                'success': False,
                'connected': False,
                'message': 'No Meta Graph API Access Token configured. Add your token in Settings.',
                'page': None,
                'instagram': None,
            }
        
        try:
            url = f"{GRAPH_API_BASE}/me"
            params = {
                'fields': 'id,name,accounts{id,name,access_token,instagram_business_account{id,username,name,profile_picture_url}}',
                'access_token': token
            }
            resp = requests.get(url, params=params, timeout=10)
            data = resp.json()

            if resp.status_code != 200 or 'error' in data:
                err_msg = data.get('error', {}).get('message', 'Failed to authenticate token with Meta')
                return {
                    'success': False,
                    'connected': False,
                    'message': f"Meta API Error: {err_msg}",
                    'page': None,
                    'instagram': None
                }

            page_id = config.facebook_page_id
            page_name = config.facebook_page_name or data.get('name', 'Connected Page')
            ig_id = config.instagram_account_id
            ig_user = config.instagram_username

            if 'accounts' in data and data['accounts'].get('data'):
                first_page = data['accounts']['data'][0]
                page_id = first_page.get('id', page_id)
                page_name = first_page.get('name', page_name)
                ig_info = first_page.get('instagram_business_account')
                if ig_info:
                    ig_id = ig_info.get('id', ig_id)
                    ig_user = ig_info.get('username', ig_user)

            config.is_connected = True
            config.facebook_page_id = page_id
            config.facebook_page_name = page_name
            config.instagram_account_id = ig_id
            config.instagram_username = ig_user
            config.save()

            return {
                'success': True,
                'connected': True,
                'message': f"Successfully verified connection to {page_name}",
                'page': {'id': page_id, 'name': page_name},
                'instagram': {'id': ig_id, 'username': ig_user}
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
    def publish_post(cls, post_obj):
        config = cls.get_settings(post_obj.shop)
        token = config.page_access_token
        
        # If no live token or demo mode, record simulated success
        if not token or not config.is_connected:
            post_obj.status = 'PUBLISHED'
            post_obj.meta_post_id = f"sim_{post_obj.platform.lower()}_{post_obj.id}"
            post_obj.save()
            return {'success': True, 'simulated': True, 'post_id': post_obj.meta_post_id}

        try:
            target_id = config.facebook_page_id if post_obj.platform == 'FACEBOOK' else config.instagram_account_id
            if not target_id:
                raise ValueError(f"No target ID configured for platform {post_obj.platform}")

            if post_obj.platform == 'FACEBOOK':
                endpoint = f"{GRAPH_API_BASE}/{target_id}/feed"
                payload = {'message': post_obj.content, 'access_token': token}
                if post_obj.image_url:
                    endpoint = f"{GRAPH_API_BASE}/{target_id}/photos"
                    payload = {'caption': post_obj.content, 'url': post_obj.image_url, 'access_token': token}
                
                resp = requests.post(endpoint, data=payload, timeout=15)
                res_data = resp.json()
                if resp.status_code == 200 and 'id' in res_data:
                    post_obj.status = 'PUBLISHED'
                    post_obj.meta_post_id = res_data['id']
                    post_obj.save()
                    return {'success': True, 'post_id': res_data['id']}
                else:
                    err_msg = res_data.get('error', {}).get('message', 'Failed to publish to Facebook')
                    post_obj.status = 'FAILED'
                    post_obj.error_message = err_msg
                    post_obj.save()
                    return {'success': False, 'error': err_msg}

            elif post_obj.platform == 'INSTAGRAM':
                # Two-step Instagram Graph API container publish
                if not post_obj.image_url:
                    raise ValueError("Instagram posts require an image URL.")

                container_url = f"{GRAPH_API_BASE}/{target_id}/media"
                c_payload = {'image_url': post_obj.image_url, 'caption': post_obj.content, 'access_token': token}
                c_resp = requests.post(container_url, data=c_payload, timeout=15)
                c_data = c_resp.json()
                
                if 'id' not in c_data:
                    err = c_data.get('error', {}).get('message', 'Instagram container creation failed')
                    post_obj.status = 'FAILED'
                    post_obj.error_message = err
                    post_obj.save()
                    return {'success': False, 'error': err}

                creation_id = c_data['id']
                pub_url = f"{GRAPH_API_BASE}/{target_id}/media_publish"
                p_resp = requests.post(pub_url, data={'creation_id': creation_id, 'access_token': token}, timeout=15)
                p_data = p_resp.json()

                if p_resp.status_code == 200 and 'id' in p_data:
                    post_obj.status = 'PUBLISHED'
                    post_obj.meta_post_id = p_data['id']
                    post_obj.save()
                    return {'success': True, 'post_id': p_data['id']}
                else:
                    err = p_data.get('error', {}).get('message', 'Instagram media publish failed')
                    post_obj.status = 'FAILED'
                    post_obj.error_message = err
                    post_obj.save()
                    return {'success': False, 'error': err}

        except Exception as e:
            logger.error(f"Error publishing post {post_obj.id}: {e}")
            post_obj.status = 'FAILED'
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
                tokens.append(chunk)
            return "".join(tokens).strip()
        except (RagServiceError, Exception) as e:
            logger.warning(f"RAG streaming reply fallback: {e}")
            # Intelligent fallback reply
            lower = user_text.lower()
            if 'price' in lower or 'rate' in lower or 'cost' in lower:
                return "Hi! Our washing starts at ₹69/kg and dry cleaning from ₹99/item. You can book an instant doorstep pickup right here!"
            elif 'pickup' in lower or 'timing' in lower or 'delivery' in lower:
                return "Hello! We offer convenient morning (8 AM - 12 PM) and evening (4 PM - 8 PM) pickup & delivery slots. Would you like us to schedule a pickup?"
            elif 'status' in lower or 'order' in lower:
                return "Hello! Could you please share your order number or registered phone number so I can check your order status immediately?"
            else:
                return "Hello from WashNLaundry! How can we assist you with your laundry or dry cleaning today?"
