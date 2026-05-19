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
          _classes = data['data']['classes'] ?? [];
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
      body: RefreshIndicator(
        onRefresh: _fetchClasses,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? _buildErrorWidget()
                : _buildClassGrid(),
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
                    className: '${item['class_name']} ${item['section_name']}',
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

  const ClassOverviewPage({
    super.key,
    required this.classId,
    required this.sectionId,
    required this.className,
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

      // Fetch students
      final studentsRes = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/teacher/students?class_id=${widget.classId}&section_id=${widget.sectionId}'),
        headers: {'Authorization': 'Bearer $token'},
      );

      // Fetch attendance summary
      final attendanceRes = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/teacher/attendance/status'),
        headers: {'Authorization': 'Bearer $token'},
      );

      // Fetch subjects (from exams endpoint)
      final subjectsRes = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/teacher/marks/exams'),
        headers: {'Authorization': 'Bearer $token'},
      );
      
      if (studentsRes.statusCode == 200) {
        final studentsData = jsonDecode(studentsRes.body);
        final attendanceData = jsonDecode(attendanceRes.body);
        final subjectsData = jsonDecode(subjectsRes.body);

        if (!mounted) return;

        // Find attendance for this class
        final List classes = attendanceData['data']['classes'] ?? [];
        final myAtt = classes.firstWhere(
          (c) => c['class_id'] == widget.classId && c['section_id'] == widget.sectionId,
          orElse: () => null,
        );

        // Extract subjects for this class
        final List exams = subjectsData['data']['exams'] ?? [];
        final Set<String> uniqueSubjects = {};
        final List<Map<String, dynamic>> classSubjects = [];
        
        for (var exam in exams) {
          final List subjects = exam['subjects'] ?? [];
          for (var s in subjects) {
            if (s['class_id'] == widget.classId && s['section_id'] == widget.sectionId) {
              if (!uniqueSubjects.contains(s['subject_name'])) {
                uniqueSubjects.add(s['subject_name']);
                classSubjects.add(s);
              }
            }
          }
        }

        setState(() {
          _students = studentsData['data']['students'] ?? [];
          _attendanceSummary = myAtt;
          _subjects = classSubjects;
          _isLoading = false;
        });
      } else {
        if (!mounted) return;
        setState(() {
          _errorMessage = 'Failed to load class data';
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
        title: Text(widget.className),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Students'),
            Tab(text: 'Attendance'),
            Tab(text: 'Subjects'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStudentsTab(),
          _buildAttendanceTab(),
          _buildSubjectsTab(),
        ],
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
        final name = '${student['first_name']} ${student['last_name']}';
        return ListTile(
          leading: CircleAvatar(
            child: Text(student['first_name'][0]),
          ),
          title: Text(name),
          subtitle: Text('Roll: ${student['roll_number'] ?? 'N/A'}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StudentDetailPage(
                  studentId: student['enrollment_id'],
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

    final total = _attendanceSummary!['total_students'] ?? 0;
    final marked = _attendanceSummary!['marked_students'] ?? 0;
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
                    className: widget.className.split(' ')[0],
                    sectionName: widget.className.split(' ').length > 1 ? widget.className.split(' ')[1] : '',
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
        return Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.book_outlined)),
            title: Text(s['subject_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('Regular Subject'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
               // Detail view for subject?
            },
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

      // Fetch profile
      final profileRes = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/teacher/students/${widget.studentId}'),
        headers: {'Authorization': 'Bearer $token'},
      );

      // Fetch attendance
      final attendanceRes = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/teacher/students/${widget.studentId}/attendance'),
        headers: {'Authorization': 'Bearer $token'},
      );

      // Fetch results
      final resultsRes = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/teacher/students/${widget.studentId}/results'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (!mounted) return;

      if (profileRes.statusCode == 200) {
        final profileData = jsonDecode(profileRes.body);
        final attendanceData = jsonDecode(attendanceRes.body);
        final resultsData = jsonDecode(resultsRes.body);

        setState(() {
          _studentProfile = profileData['data'];
          _attendanceRecords = attendanceData['data'] ?? [];
          _examResults = resultsData['data'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load student details';
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
      body: _isLoading
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
        final marks = double.tryParse(result['marks']?.toString() ?? '0') ?? 0;
        final maxMarks = double.tryParse(result['max_marks']?.toString() ?? '100') ?? 100;
        final percentage = (marks / maxMarks) * 100;

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
