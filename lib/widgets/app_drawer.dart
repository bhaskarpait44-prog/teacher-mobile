import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../pages/my_classes_page.dart';
import '../pages/attendance_page.dart';
import '../pages/notice_page.dart';
import '../pages/homework_page.dart';
import '../pages/timetable_page.dart';
import '../pages/marks_entry_page.dart';
import '../pages/leave_page.dart';
import '../pages/profile_page.dart';
import '../pages/login_page.dart';

class AppDrawer extends StatelessWidget {
  final String currentRoute;
  const AppDrawer({super.key, this.currentRoute = 'Dashboard'});

  void _handleLogout(BuildContext context) async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;
    final name = user?['name'] ?? 'Teacher';
    final colorScheme = Theme.of(context).colorScheme;

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: colorScheme.primary),
            accountName: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            accountEmail: const Text('Teacher Portal', style: TextStyle(color: Colors.white70)),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                name.isNotEmpty ? name[0] : 'T',
                style: TextStyle(fontSize: 32, color: colorScheme.primary, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(context, Icons.dashboard_rounded, 'Dashboard', currentRoute == 'Dashboard', () {
                  Navigator.pop(context);
                  // Navigation handled by DashboardPage state if needed, 
                  // but here we just ensure we are on the right page.
                }),
                _buildDrawerItem(context, Icons.class_rounded, 'My Classes', currentRoute == 'My Classes', () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const MyClassesPage()));
                }),
                _buildDrawerItem(context, Icons.how_to_reg_rounded, 'Attendance', currentRoute == 'Attendance', () {
                  Navigator.pop(context);
                  // Now in BottomNav, but keeping for direct access
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const AttendancePage()));
                }),
                _buildDrawerItem(context, Icons.notifications_none_rounded, 'Notices', currentRoute == 'Notices', () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const NoticePage()));
                }),
                _buildDrawerItem(context, Icons.book_rounded, 'Homework', currentRoute == 'Homework', () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const HomeworkPage()));
                }),
                _buildDrawerItem(context, Icons.event_note_rounded, 'Timetable', currentRoute == 'Timetable', () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const TimetablePage()));
                }),
                _buildDrawerItem(context, Icons.assignment_rounded, 'Marks Entry', currentRoute == 'Marks Entry', () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const MarksEntryPage()));
                }),
                _buildDrawerItem(context, Icons.beach_access_rounded, 'Leaves', currentRoute == 'Leaves', () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const LeavePage()));
                }),
                _buildDrawerItem(context, Icons.person_outline_rounded, 'Profile', currentRoute == 'Profile', () {
                   Navigator.pop(context);
                   Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfilePage()));
                }),
                const Divider(),
                _buildDrawerItem(context, Icons.logout_rounded, 'Logout', false, () => _handleLogout(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(BuildContext context, IconData icon, String title, bool selected, VoidCallback onTap) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          color: selected ? colorScheme.primary : colorScheme.onSurface,
        ),
      ),
      onTap: onTap,
      selected: selected,
    );
  }
}
