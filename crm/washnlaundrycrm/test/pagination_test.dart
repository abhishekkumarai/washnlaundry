import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:washnlaundrycrm/services/api_service.dart';

void main() {
  group('ApiService Pagination Tests', () {
    test('PaginatedResult container holds metadata and computes navigation', () {
      final paged = PaginatedResult<String>(
        count: 50,
        totalPages: 5,
        currentPage: 2,
        pageSize: 10,
        next: '/api/orders/?page=3',
        previous: '/api/orders/?page=1',
        results: ['a', 'b', 'c'],
      );

      expect(paged.count, 50);
      expect(paged.totalPages, 5);
      expect(paged.currentPage, 2);
      expect(paged.pageSize, 10);
      expect(paged.hasNext, isTrue);
      expect(paged.hasPrevious, isTrue);
      expect(paged.results.length, 3);
    });

    test('PaginatedResult boundary conditions', () {
      final firstPage = PaginatedResult<int>(
        count: 10,
        totalPages: 1,
        currentPage: 1,
        pageSize: 10,
        results: [1, 2],
      );

      expect(firstPage.hasNext, isFalse);
      expect(firstPage.hasPrevious, isFalse);
    });
  });
}
