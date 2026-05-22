import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../providers/auth_provider.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import 'attendance_page.dart';

class MyClassesPage extends StatefulWidget {
  const MyClassesPage({super.key});

  @override
  State<MyClassesPage> createState() => _MyClassesPageState();
}

class _MyClassesPageState extends State<MyClassesPage> {
  bool _isLoading = true;
  List<dynamic> _classes = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchClasses();
  }

  Future<void> _fetchClasses() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/teacher/my-classes'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (!mounted) return;
        setState(() {
          final myClass = data['data']['my_class'] ?? [];
          final subjectClasses = data['data']['subject_classes'] ?? [];
          _classes = [...myClass, ...subjectClasses];
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Failed to load classes';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'An error occurred: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Classes')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchClasses,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? _buildErrorWidget()
                  : _buildClassGrid(),
        ),
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
            Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(_errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _fetchClasses, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }

  Widget _buildClassGrid() {
    if (_classes.isEmpty) {
      return const Center(child: Text('No classes assigned to you.'));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.1,
      ),
      itemCount: _classes.length,
      itemBuilder: (context, index) {
        final item = _classes[index];
        final colorScheme = Theme.of(context).colorScheme;
        return Card(
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
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    backgroundColor: colorScheme.primary.withOpacity(0.1),
                    child: Icon(Icons.class_rounded, color: colorScheme.primary),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${item['class_name']} ${item['section_name']}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${item['student_count'] ?? 0} Students',
                    style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class ClassOverviewPage extends StatefulWidget {
  final int classId;
  final int sectionId;
  final String className;
  final String sectionName;
  final bool isClassTeacher;

  const ClassOverviewPage({
    super.key,
    required this.classId,
    required this.sectionId,
    required this.className,
    required this.sectionName,
    required this.isClassTeacher,
  });

  @override
  State<ClassOverviewPage> createState() => _ClassOverviewPageState();
}

class _ClassOverviewPageState extends State<ClassOverviewPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<dynamic> _students = [];
  Map<String, dynamic>? _attendanceSummary;
  List<dynamic> _subjects = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      final headers = {'Authorization': 'Bearer $token'};
      final baseUrl = ApiConstants.baseUrl;

      // Run all 3 in parallel
      final results = await Future.wait([
        http.get(Uri.parse('$baseUrl/teacher/students?class_id=${widget.classId}&section_id=${widget.sectionId}'), headers: headers),
        http.get(Uri.parse('$baseUrl/teacher/attendance/status'), headers: headers),
        http.get(Uri.parse('$baseUrl/classes/${widget.classId}/subjects'), headers: headers),
      ]);

      if (!mounted) return;

      final studentsRes = results[0];
      final attendanceRes = results[1];
      final subjectsRes = results[2];

      if (studentsRes.statusCode == 200) {
        final studentsData = jsonDecode(studentsRes.body);
        
        // Attendance Data
        Map<String, dynamic>? myAtt;
        if (attendanceRes.statusCode == 200) {
          final attendanceData = jsonDecode(attendanceRes.body);
          final List classes = attendanceData['data']['classes'] ?? [];
          myAtt = classes.firstWhere(
            (c) => c['class_id'] == widget.classId && c['section_id'] == widget.sectionId,
            orElse: () => null,
          );
        }

        // Subjects Data
        List<dynamic> subjects = [];
        if (subjectsRes.statusCode == 200) {
          final subjectsData = jsonDecode(subjectsRes.body);
          subjects = subjectsData['data'] ?? [];
        }

        setState(() {
          _students = studentsData['data']['students'] ?? [];
          _attendanceSummary = myAtt;
          _subjects = subjects;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load class students. (Status: ${studentsRes.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'An error occurred: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.className} ${widget.sectionName}'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Students'),
            Tab(text: 'Attendance'),
            Tab(text: 'Subjects'),
          ],
        ),
      ),
      body: SafeArea(
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildStudentsTab(),
            _buildAttendanceTab(),
            _buildSubjectsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentsTab() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_errorMessage != null) return Center(child: Text(_errorMessage!));
    if (_students.isEmpty) return const Center(child: Text('No students found'));

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _students.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final student = _students[index];
        final firstName = student['first_name'] ?? '';
        final name = '${student['first_name']} ${student['last_name']}';
        return ListTile(
          leading: CircleAvatar(
            child: Text(firstName.isNotEmpty ? firstName[0] : 'S'),
          ),
          title: Text(name),
          subtitle: Text('Roll: ${student['roll_number'] ?? 'N/A'}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StudentDetailPage(
                  studentId: student['id'],
                  studentName: name,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAttendanceTab() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_attendanceSummary == null) return const Center(child: Text('No attendance data for today'));

    final total = int.tryParse(_attendanceSummary!['total_students']?.toString() ?? '0') ?? 0;
    final marked = int.tryParse(_attendanceSummary!['marked_students']?.toString() ?? '0') ?? 0;
    final isComplete = marked >= total && total > 0;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const Text('Today\'s Attendance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 24),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        height: 120,
                        width: 120,
                        child: CircularProgressIndicator(
                          value: total > 0 ? marked / total : 0,
                          strokeWidth: 10,
                          backgroundColor: Colors.grey[200],
                          color: isComplete ? Colors.green : Colors.orange,
                        ),
                      ),
                      Column(
                        children: [
                          Text('$marked/$total', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                          const Text('Marked', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    isComplete ? 'All students marked' : 'Attendance in progress',
                    style: TextStyle(color: isComplete ? Colors.green : Colors.orange, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MarkAttendancePage(
                    classId: widget.classId,
                    sectionId: widget.sectionId,
                    className: widget.className,
                    sectionName: widget.sectionName,
                    isClassTeacher: widget.isClassTeacher,
                  ),
                ),
              ).then((_) => _fetchData());
            },
            icon: const Icon(Icons.how_to_reg_rounded),
            label: const Text('Update Attendance'),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectsTab() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_subjects.isEmpty) return const Center(child: Text('No subjects found for this class'));

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _subjects.length,
      itemBuilder: (context, index) {
        final s = _subjects[index];
        final code = s['code'] != null ? ' (${s['code']})' : '';
        return Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.book_outlined)),
            title: Text('${s['name']}$code', style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(s['is_core'] == true ? 'Core Subject' : 'Elective Subject'),
          ),
        );
      },
    );
  }
}

class StudentDetailPage extends StatefulWidget {
  final int studentId;
  final String studentName;

  const StudentDetailPage({
    super.key,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<StudentDetailPage> createState() => _StudentDetailPageState();
}

class _StudentDetailPageState extends State<StudentDetailPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  Map<String, dynamic>? _studentProfile;
  List<dynamic> _attendanceRecords = [];
  List<dynamic> _examResults = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchStudentDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchStudentDetails() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      final headers = {'Authorization': 'Bearer $token'};
      final baseUrl = ApiConstants.baseUrl;

      final results = await Future.wait([
        http.get(Uri.parse('$baseUrl/teacher/students/${widget.studentId}'), headers: headers),
        http.get(Uri.parse('$baseUrl/teacher/students/${widget.studentId}/attendance'), headers: headers),
        http.get(Uri.parse('$baseUrl/teacher/students/${widget.studentId}/results'), headers: headers),
      ]);

      if (!mounted) return;

      final profileRes = results[0];
      final attendanceRes = results[1];
      final resultsRes = results[2];

      if (profileRes.statusCode == 200) {
        final profileData = jsonDecode(profileRes.body);
        
        List<dynamic> attendanceList = [];
        if (attendanceRes.statusCode == 200) {
          final attendanceData = jsonDecode(attendanceRes.body);
          attendanceList = attendanceData['data']?['attendance'] ?? [];
        }

        List<dynamic> examResultsList = [];
        if (resultsRes.statusCode == 200) {
          final resultsData = jsonDecode(resultsRes.body);
          examResultsList = resultsData['data']?['results'] ?? [];
        }

        setState(() {
          _studentProfile = profileData['data'];
          _attendanceRecords = attendanceList;
          _examResults = examResultsList;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load student details (Status: ${profileRes.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'An error occurred: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.studentName),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Attendance'),
            Tab(text: 'Results'),
          ],
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(child: Text(_errorMessage!))
                : Column(
                    children: [
                      _buildProfileCard(),
                      Expanded(
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildAttendanceList(),
                            _buildResultsList(),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildProfileCard() {
    if (_studentProfile == null) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 30,
                child: Text(_studentProfile!['first_name'][0], style: const TextStyle(fontSize: 24)),
              ),
              title: Text(
                '${_studentProfile!['first_name']} ${_studentProfile!['last_name']}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              subtitle: Text('Roll Number: ${_studentProfile!['roll_number'] ?? 'N/A'}'),
            ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildInfoItem(Icons.person_outline, 'Gender', _studentProfile!['gender'] ?? 'N/A'),
                _buildInfoItem(Icons.phone_outlined, 'Phone', _studentProfile!['phone'] ?? 'N/A'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildAttendanceList() {
    if (_attendanceRecords.isEmpty) return const Center(child: Text('No attendance records found'));

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _attendanceRecords.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final record = _attendanceRecords[index];
        final status = record['status']?.toString().toLowerCase();
        return ListTile(
          title: Text(formatDate(record['date'])),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: getStatusColor(status, context).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status?.toUpperCase() ?? 'N/A',
              style: TextStyle(
                color: getStatusColor(status, context),
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildResultsList() {
    if (_examResults.isEmpty) return const Center(child: Text('No exam results found'));

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _examResults.length,
      separatorBuilder: (context, index) => const Divider(),
      itemBuilder: (context, index) {
        final result = _examResults[index];
        final marks = double.tryParse(result['marks_obtained']?.toString() ?? '0') ?? 0;
        final maxMarks = double.tryParse(result['max_marks']?.toString() ?? '100') ?? 100;
        final percentage = maxMarks > 0 ? (marks / maxMarks) * 100 : 0.0;

        return ListTile(
          title: Text(result['subject_name'] ?? 'Subject'),
          subtitle: Text(result['exam_name'] ?? 'Exam'),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$marks / $maxMarks', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text('${percentage.toStringAsFixed(1)}%', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 12)),
            ],
          ),
        );
      },
    );
  }
}
