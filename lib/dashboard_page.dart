import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'login_page.dart';

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

  final String _baseUrl = 'http://10.137.4.32:5000/api';

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
  }

  Future<void> _fetchDashboardData() async {
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
        Uri.parse('$_baseUrl/teacher/dashboard'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _dashboardData = data['data'];
          _isLoading = false;
        });
      } else if (response.statusCode == 401) {
        _handleLogout();
      } else {
        setState(() {
          _errorMessage = 'Failed to load dashboard: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred: $e';
        _isLoading = false;
      });
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
      appBar: AppBar(
        title: const Text('Teacher Dashboard'),
        actions: [
          IconButton(
            onPressed: _fetchDashboardData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchDashboardData,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _buildDashboardContent(),
    );
  }

  Widget _buildDrawer() {
    final name = _dashboardData?['teacher']?['name'] ?? 'Teacher';
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(name),
            accountEmail: const Text('Teacher Portal'),
            currentAccountPicture: const CircleAvatar(
              backgroundColor: Colors.white,
              child: Icon(Icons.person, size: 40, color: Colors.blue),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Dashboard'),
            onTap: () => Navigator.pop(context),
            selected: true,
          ),
          ListTile(
            leading: const Icon(Icons.check_circle),
            title: const Text('Attendance'),
            onTap: () {
              Navigator.pop(context);
              // Navigate to Attendance
            },
          ),
          ListTile(
            leading: const Icon(Icons.assignment),
            title: const Text('Marks Entry'),
            onTap: () {
              Navigator.pop(context);
              // Navigate to Marks Entry
            },
          ),
          ListTile(
            leading: const Icon(Icons.book),
            title: const Text('Homework'),
            onTap: () {
              Navigator.pop(context);
              // Navigate to Homework
            },
          ),
          ListTile(
            leading: const Icon(Icons.time_to_leave),
            title: const Text('Leave Application'),
            onTap: () {
              Navigator.pop(context);
              // Navigate to Leave
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Profile'),
            onTap: () {
              Navigator.pop(context);
              // Navigate to Profile
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: _handleLogout,
          ),
        ],
      ),
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
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWelcomeHeader(),
            const SizedBox(height: 24),
            _buildStatGrid(glance),
            const SizedBox(height: 24),
            _buildSectionTitle('Today\'s Schedule'),
            const SizedBox(height: 12),
            _buildScheduleList(schedule),
            const SizedBox(height: 24),
            _buildSectionTitle('My Classes'),
            const SizedBox(height: 12),
            _buildClassesList(myClasses),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeHeader() {
    final name = _dashboardData?['teacher']?['name'] ?? 'Teacher';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hello, $name',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        Text(
          'Here is what\'s happening today',
          style: TextStyle(fontSize: 16, color: Colors.grey[600]),
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
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildStatCard(
          'Total Periods',
          '${classes?['total_periods'] ?? 0}',
          Icons.calendar_today,
          Colors.blue,
        ),
        _buildStatCard(
          'Pending Marks',
          '$pending',
          Icons.pending_actions,
          Colors.orange,
        ),
        _buildStatCard(
          'Attendance',
          '${attendance?['marked'] ?? 0}/${attendance?['total'] ?? 0}',
          Icons.check_circle_outline,
          Colors.green,
        ),
        _buildStatCard(
          'My Students',
          '${glance['my_students_today']?['percentage'] ?? 0}%',
          Icons.people,
          Colors.purple,
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 24),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildScheduleList(List? schedule) {
    if (schedule == null || schedule.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No periods scheduled for today.'),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: schedule.length,
      separatorBuilder: (context, index) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = schedule[index];
        final isCurrent = item['status'] == 'current';
        
        return Card(
          elevation: isCurrent ? 4 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: isCurrent ? const BorderSide(color: Colors.blue, width: 2) : BorderSide.none,
          ),
          child: ListTile(
            leading: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item['start_time'] ?? '',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  item['end_time'] ?? '',
                  style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                ),
              ],
            ),
            title: Text('${item['subject_name']} - ${item['class_name']} ${item['section_name']}'),
            subtitle: Text('Period: ${item['period_name']}'),
            trailing: isCurrent 
                ? Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'NOW',
                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _buildClassesList(List? myClasses) {
    if (myClasses == null || myClasses.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No classes assigned.'),
        ),
      );
    }

    return SizedBox(
      height: 120,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: myClasses.length,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final item = myClasses[index];
          return Container(
            width: 160,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${item['class_name']} ${item['section_name']}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 4),
                Text(
                  '${item['student_count'] ?? 0} Students',
                  style: TextStyle(color: Colors.grey[700]),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Class Teacher',
                  style: TextStyle(fontSize: 10, color: Colors.blue, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
