from rest_framework.pagination import PageNumberPagination
from rest_framework.response import Response


class StandardPagination(PageNumberPagination):
    """Standard page-number pagination for list views.

    Features:
    - Default page size: 20
    - Client-customizable page size via `page_size` parameter (up to 100)
    - Full metadata envelope with `count`, `total_pages`, `current_page`, `page_size`, `next`, `previous`, `results`
    - Backwards compatible: returns unpaginated raw list if neither `page`, `page_size`,
      nor `paginate=true` is requested.
    """
    page_size = 20
    page_size_query_param = 'page_size'
    max_page_size = 100

    def paginate_queryset(self, queryset, request, view=None):
        if 'page' in request.query_params or 'page_size' in request.query_params:
            return super().paginate_queryset(queryset, request, view=view)
        if request.query_params.get('paginate', '').lower() in ('true', '1', 'yes'):
            return super().paginate_queryset(queryset, request, view=view)
        return None

    def get_paginated_response(self, data):
        return Response({
            'count': self.page.paginator.count,
            'total_pages': self.page.paginator.num_pages,
            'current_page': self.page.number,
            'page_size': self.get_page_size(self.request),
            'next': self.get_next_link(),
            'previous': self.get_previous_link(),
            'results': data,
        })
