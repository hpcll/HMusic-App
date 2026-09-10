import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hmusic/core/models/server_info.dart';
import 'package:hmusic/core/network/api_failure.dart';
import 'package:hmusic/core/providers/infrastructure_providers.dart';
import 'package:hmusic/core/storage/key_value_store.dart';
import 'package:hmusic/features/auth/views/auth_page.dart';
import 'package:hmusic/features/connection/data/api_connection_repository.dart';
import 'package:hmusic/features/connection/data/connection_repository.dart';
import 'package:hmusic/features/connection/data/lan_server_scanner.dart';
import 'package:hmusic/features/connection/models/connection_result.dart';
import 'package:hmusic/features/connection/views/connection_page.dart';
import 'package:hmusic/features/connection/widgets/server_address_form.dart';
import 'package:hmusic/shared/widgets/brand_mark.dart';

part 'support/connection_page_fixture.dart';
part 'connection_page_cases_1.dart';
part 'connection_page_cases_2.dart';
part 'connection_page_cases_3.dart';
part 'connection_page_cases_4.dart';

void main() {
  _connectionPageCases1();
  _connectionPageCases2();
  _connectionPageCases3();
  _connectionPageCases4();
}
