def client_ip(request):
    """Best-effort caller IP for rate limiting (KAN-193).

    Traffic reaches Django through Cloudflare, which sets CF-Connecting-IP to the
    real client. The left-most X-Forwarded-For entry is caller-controlled, so it is
    never used; the right-most is the one appended by the nearest proxy.
    """
    meta = request.META
    ip = (meta.get('HTTP_CF_CONNECTING_IP') or '').strip()
    if not ip:
        fwd = meta.get('HTTP_X_FORWARDED_FOR', '')
        ip = fwd.split(',')[-1].strip() if fwd else ''
    return ip or meta.get('REMOTE_ADDR', '') or 'unknown'
