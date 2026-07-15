import '../models/search_result.dart';

abstract interface class SearchRepository {
  Future<SearchResult> search(String query);
}
