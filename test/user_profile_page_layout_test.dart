import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:hr_management/models/app_user.dart';
import 'package:hr_management/models/work_models.dart';
import 'package:hr_management/screens/user_profile_page.dart';
import 'package:hr_management/services/auth_flow_service.dart';

class _ProfileService extends AuthFlowService {
  _ProfileService() : super(dio: Dio(BaseOptions(baseUrl: 'http://localhost')));

  @override
  Future<List<LeaveBalanceRecord>> getLeaveBalances(int year) async => [
    const LeaveBalanceRecord(
      leaveType: 'ลาป่วย',
      quota: 30,
      used: 2,
      remaining: 28,
    ),
  ];
}

const _user = AppUser(
  id: 'user-id',
  authId: 'auth-id',
  email: 'bewrock45.4@gmail.com',
  firstName: 'Nattamon',
  lastName: 'Chotikul',
  nickname: 'Bew',
  department: 'Product Development',
  position: 'Senior Application Developer',
  role: 'admin',
  status: 'active',
  avatarUrl: null,
  hasFaceEmbedding: true,
);

Widget _profilePage() => UserProfilePage(
  user: _user,
  service: _ProfileService(),
  onMenu: () {},
  onSignOut: () async {},
  isActive: true,
  onProfileUpdated: () {},
);

void main() {
  testWidgets('profile page does not overflow across web viewports', (
    tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final size in const [Size(320, 800), Size(1280, 800)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: _profilePage())),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull, reason: 'viewport: $size');
    }
  });

  testWidgets('profile edit action provides its own Material ancestor', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(430, 932));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      WidgetsApp(
        color: Colors.white,
        home: _profilePage(),
        localizationsDelegates: const [DefaultMaterialLocalizations.delegate],
        supportedLocales: const [Locale('en')],
        pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });
}
