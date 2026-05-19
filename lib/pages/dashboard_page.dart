import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import 'attendance_page.dart';
import 'homework_page.dart';
import 'timetable_page.dart';
import 'marks_entry_page.dart';
import 'leave_page.dart';
import 'my_classes_page.dart';
import 'login_page.dart';
import 'profile_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _dashboardData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      
      if (token == null) {
        _handleLogout();
        return;
      }

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/teacher/dashboard'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _dashboardData = data;
            _isLoading = false;
          });
        }
      } else if (response.statusCode == 401) {
        _handleLogout();
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to load dashboard';
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'An error occurred: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _handleLogout() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    await authProvider.logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('EduCore', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: Icon(themeProvider.mode == ThemeMode.light 
              ? Icons.dark_mode_outlined 
              : Icons.light_mode_outlined),
            onPressed: () => themeProvider.toggleTheme(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: _buildDrawer(context),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorWidget()
              : _buildDashboardContent(),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchDashboardData,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
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
                _buildDrawerItem(Icons.dashboard_rounded, 'Dashboard', true, () => Navigator.pop(context)),
                _buildDrawerItem(Icons.class_rounded, 'My Classes', false, () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => MyClassesPage())),
                }),
                _buildDrawerItem(Icons.how_to_reg_rounded, 'Attendance', false, () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => AttendancePage()));
                }),
                _buildDrawerItem(Icons.book_rounded, 'Homework', false, () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => HomeworkPage()));
                }),
                _buildDrawerItem(Icons.event_note_rounded, 'Timetable', false, () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => TimetablePage()));
                }),
                _buildDrawerItem(Icons.assignment_rounded, 'Marks Entry', false, () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => MarksEntryPage()));
                }),
                _buildDrawerItem(Icons.beach_access_rounded, 'Leaves', false, () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => LeavePage()));
                }),
                _buildDrawerItem(Icons.person_outline_rounded, 'Profile', false, () {
                   Navigator.pop(context);
                   Navigator.push(context, MaterialPageRoute(builder: (context) => ProfilePage()));
                }),
                const Divider(),
                _buildDrawerItem(Icons.logout_rounded, 'Logout', false, _handleLogout),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, bool selected, VoidCallback onTap) {
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

  Widget _buildDashboardContent() {
    final teacher = _dashboardData?['teacher'];
    final glance = _dashboardData?['today_at_a_glance'];
    final schedule = _dashboardData?['today_schedule'] as List?;
    final myClasses = _dashboardData?['my_class'] as List?;

    return RefreshIndicator(
      onRefresh: _fetchDashboardData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeHeader(teacher?['name'] ?? 'Teacher'),
            const SizedBox(height: 24),
            _buildStatGrid(glance),
            const SizedBox(height: 32),
            _buildSectionHeader('Today\'s Schedule', () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const TimetablePage()));
            }),
            const SizedBox(height: 12),
            _buildScheduleList(schedule),
            const SizedBox(height: 32),
            _buildSectionHeader('My Classes', () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const MyClassesPage()));
            }),
            const SizedBox(height: 12),
            _buildClassesList(myClasses),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader(String name) {
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hello, $name 👋',
          style: textTheme.headlineMedium?.copyWith(fontSize: 24),
        ),
        const SizedBox(height: 4),
        Text(
          'Here is your summary for today',
          style: textTheme.bodyMedium,
        ),
      ],
    );
  }

  Widget _buildStatGrid(Map<String, dynamic>? glance) {
    final classes = glance?['todays_classes'];
    final attendance = glance?['attendance_status'];
    final pending = glance?['pending_marks'] ?? 0;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.4,
      children: [
        _buildStatCard(
          'Periods',
          '${classes?['total_periods'] ?? 0}',
          Icons.calendar_today_rounded,
          Colors.blue,
          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TimetablePage())),
        ),
        _buildStatCard(
          'Marks',
          '$pending Pending',
          Icons.assignment_rounded,
          Colors.orange,
          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MarksEntryPage())),
        ),
        _buildStatCard(
          'Attendance',
          '${attendance?['marked'] ?? 0}/${attendance?['total'] ?? 0}',
          Icons.how_to_reg_rounded,
          Colors.green,
          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AttendancePage())),
        ),
        _buildStatCard(
          'Leave',
          'Balance',
          Icons.beach_access_rounded,
          Colors.purple,
          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const LeavePage())),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, VoidCallback onTap) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 20),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  Text(label, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onSeeAll) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        TextButton(
          onPressed: onSeeAll,
          child: const Text('See All', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildScheduleList(List? schedule) {
    if (schedule == null || schedule.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.event_busy_rounded, size: 48, color: Theme.of(context).colorScheme.outline),
                const SizedBox(height: 12),
                Text('No classes for today', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      );
    }

    return Column(
      children: schedule.map((item) {
        final isCurrent = item['status'] == 'current';
        final colorScheme = Theme.of(context).colorScheme;
        
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: isCurrent ? Border.all(color: colorScheme.primary, width: 2) : null,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 70,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isCurrent ? colorScheme.primary : colorScheme.surfaceVariant,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  formatTime12hr(item['start_time']).split(' ')[0],
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isCurrent ? Colors.white : colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            title: Text(
              '${item['subject_name']}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              '${item['class_name']} ${item['section_name']} • ${item['period_name']}',
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
            ),
            trailing: isCurrent
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: colorScheme.error.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text('LIVE', style: TextStyle(color: colorScheme.error, fontSize: 10, fontWeight: FontWeight.bold)),
                  )
                : Icon(Icons.chevron_right_rounded, color: colorScheme.onSurfaceVariant),
            onTap: () {
               Navigator.push(context, MaterialPageRoute(builder: (context) => const TimetablePage()));
            },
          ),
        );
      }).toList(),
    );
  }

  Widget _buildClassesList(List? myClasses) {
    if (myClasses == null || myClasses.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 140,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: myClasses.length,
        separatorBuilder: (context, index) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final item = myClasses[index];
          final colorScheme = Theme.of(context).colorScheme;
          return Container(
            width: 200,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [colorScheme.primary, colorScheme.primary.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ClassOverviewPage(
                      classId: item['class_id'],
                      sectionId: item['section_id'],
                      className: '${item['class_name']} ${item['section_name']}',
                    ),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(24),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${item['class_name']} ${item['section_name']}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 20),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${item['student_count'] ?? 0} Students',
                          style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                          child: const Text(
                            'Class Teacher',
                            style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
