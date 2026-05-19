import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'login_page.dart';
import '../utils/constants.dart';
import 'attendance_page.dart';
import 'homework_page.dart';
import 'timetable_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  final _storage = const FlutterSecureStorage();
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
      final token = await _storage.read(key: 'token');
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
            _errorMessage = 'Failed to load dashboard: ${response.statusCode}';
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
    await _storage.deleteAll();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('EduHard'),
        actions: [
          IconButton(
            onPressed: _fetchDashboardData,
            icon: const Icon(Icons.notifications_none_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: _buildDrawer(),
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
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
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

  Widget _buildDrawer() {
    final name = _dashboardData?['teacher']?['name'] ?? 'Teacher';
    return Drawer(
      backgroundColor: Colors.white,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(color: Theme.of(context).primaryColor),
            accountName: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
            accountEmail: const Text('Teacher Portal'),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                name.isNotEmpty ? name[0] : 'T',
                style: TextStyle(fontSize: 32, color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(Icons.dashboard_rounded, 'Dashboard', true, () => Navigator.pop(context)),
                _buildDrawerItem(Icons.how_to_reg_rounded, 'Attendance', false, () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const AttendancePage()));
                }),
                _buildDrawerItem(Icons.book_rounded, 'Homework', false, () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const HomeworkPage()));
                }),
                _buildDrawerItem(Icons.event_note_rounded, 'Timetable', false, () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const TimetablePage()));
                }),
                _buildDrawerItem(Icons.assignment_rounded, 'Marks Entry', false, () {}),
                _buildDrawerItem(Icons.beach_access_rounded, 'Leaves', false, () {}),
                const Divider(indent: 20, endIndent: 20),
                _buildDrawerItem(Icons.person_outline_rounded, 'Profile', false, () {}),
                _buildDrawerItem(Icons.logout_rounded, 'Logout', false, _handleLogout),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, bool selected, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: selected ? Theme.of(context).primaryColor : Colors.grey[600]),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          color: selected ? Theme.of(context).primaryColor : Colors.black87,
        ),
      ),
      onTap: onTap,
      selected: selected,
      selectedTileColor: Theme.of(context).primaryColor.withOpacity(0.05),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
    );
  }

  Widget _buildDashboardContent() {
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
            _buildWelcomeHeader(),
            const SizedBox(height: 24),
            _buildStatGrid(glance),
            const SizedBox(height: 32),
            _buildSectionHeader('Today\'s Schedule', () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const TimetablePage()));
            }),
            const SizedBox(height: 12),
            _buildScheduleList(schedule),
            const SizedBox(height: 32),
            _buildSectionHeader('My Classes', () {}),
            const SizedBox(height: 12),
            _buildClassesList(myClasses),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    final name = _dashboardData?['teacher']?['name'] ?? 'Teacher';
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hello, $name 👋',
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              const SizedBox(height: 4),
              Text(
                'Here is your summary for today',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatGrid(Map<String, dynamic>? glance) {
    if (glance == null) return const SizedBox.shrink();

    final classes = glance['todays_classes'];
    final attendance = glance['attendance_status'];
    final pending = glance['pending_marks'];

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
          'Homework',
          'Pending',
          Icons.book_rounded,
          Colors.orange,
          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const HomeworkPage())),
        ),
        _buildStatCard(
          'Attendance',
          '${attendance?['marked'] ?? 0}/${attendance?['total'] ?? 0}',
          Icons.how_to_reg_rounded,
          Colors.green,
          () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AttendancePage())),
        ),
        _buildStatCard(
          'Students',
          '${glance['my_students_today']?['percentage'] ?? 0}%',
          Icons.people_alt_rounded,
          Colors.purple,
          () {},
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
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
                Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onSeeAll) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
        TextButton(
          onPressed: onSeeAll,
          child: Text('See All', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildScheduleList(List? schedule) {
    if (schedule == null || schedule.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        width: double.infinity,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
        child: Column(
          children: [
            Icon(Icons.event_busy_rounded, size: 48, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text('No classes for today', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    return Column(
      children: schedule.map((item) {
        final isCurrent = item['status'] == 'current';
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: isCurrent ? Border.all(color: Theme.of(context).primaryColor, width: 2) : null,
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: Container(
              width: 60,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isCurrent ? Theme.of(context).primaryColor : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    item['start_time']?.split(':')[0] ?? '',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isCurrent ? Colors.white : Colors.black87,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    'AM',
                    style: TextStyle(
                      fontSize: 10,
                      color: isCurrent ? Colors.white.withOpacity(0.8) : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            title: Text(
              '${item['subject_name']}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              '${item['class_name']} ${item['section_name']} • Period ${item['period_name']}',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            trailing: isCurrent
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
                    child: const Text('LIVE', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                  )
                : Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
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
          return Container(
            width: 200,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Theme.of(context).primaryColor, Theme.of(context).primaryColor.withOpacity(0.8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).primaryColor.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${item['class_name']} ${item['section_name']}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const Icon(Icons.more_vert_rounded, color: Colors.white, size: 20),
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
          );
        },
      ),
    );
  }
}
