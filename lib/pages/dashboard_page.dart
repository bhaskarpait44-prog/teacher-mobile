import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/notice_provider.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../utils/notification_service.dart';
import '../widgets/app_drawer.dart';
import 'attendance_page.dart';
import 'homework_page.dart';
import 'timetable_page.dart';
import 'marks_entry_page.dart';
import 'leave_page.dart';
import 'my_classes_page.dart';
import 'login_page.dart';
import 'profile_page.dart';
import 'notice_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const DashboardHome(),
    const AttendancePage(),
    const TimetablePage(),
    const ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    _registerPushToken();
  }

  void _registerPushToken() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.token != null) {
        NotificationService.registerToken(authProvider.token!);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard_rounded),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.how_to_reg_outlined),
              activeIcon: Icon(Icons.how_to_reg_rounded),
              label: 'Attendance',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_month_outlined),
              activeIcon: Icon(Icons.calendar_month_rounded),
              label: 'Timetable',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline_rounded),
              activeIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardHome extends StatefulWidget {
  const DashboardHome({super.key});

  @override
  State<DashboardHome> createState() => _DashboardHomeState();
}

class _DashboardHomeState extends State<DashboardHome> {
  bool _isLoading = true;
  Map<String, dynamic>? _dashboardData;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
    _fetchNotices();
  }

  void _fetchNotices() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      if (authProvider.token != null) {
        Provider.of<NoticeProvider>(context, listen: false).fetchNotices(authProvider.token!);
      }
    });
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
            _dashboardData = data['data'];
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
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('EduCore', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          Consumer<NoticeProvider>(
            builder: (context, noticeProvider, _) {
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none_rounded),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NoticePage())),
                  ),
                  if (noticeProvider.unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '${noticeProvider.unreadCount}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          IconButton(
            icon: Icon(themeProvider.mode == ThemeMode.light 
              ? Icons.dark_mode_outlined 
              : Icons.light_mode_outlined),
            onPressed: () => themeProvider.toggleTheme(),
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: const AppDrawer(currentRoute: 'Dashboard'),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? _buildErrorWidget()
                : _buildDashboardContent(),
      ),
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

  Widget _buildDashboardContent() {
    final teacher = _dashboardData?['teacher'];
    final glance = _dashboardData?['today_at_a_glance'];
    final schedule = _dashboardData?['today_schedule'] as List?;
    final myClasses = _dashboardData?['my_class'] as List?;
    final upcomingExams = _dashboardData?['upcoming_exams'] as List?;

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
            if (upcomingExams != null && upcomingExams.isNotEmpty) ...[
              const SizedBox(height: 32),
              _buildSectionHeader('Upcoming Exams', () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const TimetablePage()));
              }),
              const SizedBox(height: 12),
              _buildExamsList(upcomingExams),
            ],
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

  Widget _buildExamsList(List exams) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: exams.map((exam) {
        final isDuty = exam['duty_type'] == 'invigilator';
        final color = isDuty ? Colors.orange : colorScheme.primary;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colorScheme.outline.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4)),
            ],
          ),
          child: InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TimetablePage())),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(isDuty ? Icons.security_rounded : Icons.assignment_rounded, color: color, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${exam['exam_name']}',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${exam['subject_name']} • ${exam['class_name']}',
                          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        formatDate(exam['exam_date']).split(' ').take(2).join(' '),
                        style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                      Text(
                        formatTime12hr(exam['start_time']),
                        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
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
    final pendingData = glance?['pending_marks'];
    final pending = (pendingData is Map) ? (pendingData['pending_exams'] ?? 0) : (pendingData ?? 0);

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
                      className: item['class_name'],
                      sectionName: item['section_name'],
                      isClassTeacher: item['is_class_teacher'] ?? false,
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
