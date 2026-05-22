import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../providers/auth_provider.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  bool _isLoading = true;
  List<dynamic> _classes = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchAttendanceStatus();
  }

  Future<void> _fetchAttendanceStatus() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/teacher/attendance/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _classes = data['data']['classes'] ?? [];
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to load attendance status';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AttendanceReportsPage()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchAttendanceStatus,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? _buildErrorWidget()
                  : _buildClassList(),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: colorScheme.error),
          const SizedBox(height: 16),
          Text(_errorMessage!),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _fetchAttendanceStatus, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildClassList() {
    if (_classes.isEmpty) {
      return const Center(child: Text('No classes assigned to you.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _classes.length,
      itemBuilder: (context, index) {
        final item = _classes[index];
        final total = int.tryParse(item['total_students']?.toString() ?? '0') ?? 0;
        final marked = int.tryParse(item['marked_students']?.toString() ?? '0') ?? 0;
        final bool isFullyMarked = marked >= total && total > 0;
        final colorScheme = Theme.of(context).colorScheme;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (isFullyMarked ? Colors.green : Colors.orange).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.groups_rounded,
                color: isFullyMarked ? Colors.green : Colors.orange,
                size: 28,
              ),
            ),
            title: Text(
              '${item['class_name']} ${item['section_name']}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Marked: $marked/$total students'),
                const SizedBox(height: 4),
                LinearProgressIndicator(
                  value: total > 0 ? marked / total : 0,
                  backgroundColor: colorScheme.surfaceVariant,
                  color: isFullyMarked ? Colors.green : Colors.orange,
                ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MarkAttendancePage(
                    classId: item['class_id'],
                    sectionId: item['section_id'],
                    className: item['class_name'],
                    sectionName: item['section_name'],
                    isClassTeacher: item['is_class_teacher'] ?? false,
                  ),
                ),
              ).then((_) => _fetchAttendanceStatus());
            },
          ),
        );
      },
    );
  }
}

class MarkAttendancePage extends StatefulWidget {
  final int classId;
  final int sectionId;
  final String className;
  final String sectionName;
  final bool isClassTeacher;

  const MarkAttendancePage({
    super.key,
    required this.classId,
    required this.sectionId,
    required this.className,
    required this.sectionName,
    required this.isClassTeacher,
  });

  @override
  State<MarkAttendancePage> createState() => _MarkAttendancePageState();
}

class _MarkAttendancePageState extends State<MarkAttendancePage> {
  bool _isLoading = true;
  bool _isSaving = false;
  List<dynamic> _students = [];
  Map<int, String> _attendance = {};
  DateTime _selectedDate = DateTime.now();
  String? _errorMessage;
  bool _requiresReason = false;
  bool _isHoliday = false;
  String? _holidayName;
  final _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchStudents();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _fetchStudents() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      final dateStr = _selectedDate.toIso8601String().split('T')[0];
      
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/teacher/attendance/students?class_id=${widget.classId}&section_id=${widget.sectionId}&date=$dateStr'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _students = data['data']['students'] ?? [];
            _requiresReason = data['data']['requires_reason'] ?? false;
            _isHoliday = data['data']['is_holiday'] ?? false;
            _holidayName = data['data']['holiday']?['name'];

            for (var student in _students) {
              _attendance[student['enrollment_id']] = student['status'] ?? 'present';
            }
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            if (response.statusCode == 403) {
              _errorMessage = 'Only the assigned class teacher is eligible to mark or edit attendance.';
            } else {
              _errorMessage = 'Failed to load students';
            }
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

  Future<void> _showSuccessAnimation() async {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.5),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: ScaleTransition(
            scale: CurvedAnimation(parent: anim1, curve: Curves.elasticOut),
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  )
                ],
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Colors.green,
                size: 80,
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _submitAttendance() async {
    if (!widget.isClassTeacher) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Only the class teacher is eligible to mark attendance.'), backgroundColor: Colors.red),
      );
      return;
    }

    if (_requiresReason && _reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a reason for marking/editing attendance')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;

      final records = _attendance.entries.map((e) => {
        'enrollment_id': e.key,
        'status': e.value,
      }).toList();

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/teacher/attendance/bulk-mark'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'class_id': widget.classId,
          'section_id': widget.sectionId,
          'date': _selectedDate.toIso8601String().split('T')[0],
          'records': records,
          'reason': _reasonController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          // Show success animation
          _showSuccessAnimation();

          // Wait for animation and close
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) {
            Navigator.of(context, rootNavigator: true).pop(); // Close dialog
            Navigator.pop(context); // Go back to attendance status
          }
        }
      } else {
        final data = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(data['message'] ?? 'Failed to submit attendance'), backgroundColor: Colors.red),
          );
          setState(() => _isSaving = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.className} - ${widget.sectionName}'),
        actions: [
          if (widget.isClassTeacher)
            IconButton(
              icon: const Icon(Icons.calendar_month_rounded),
              onPressed: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  setState(() => _selectedDate = picked);
                  _fetchStudents();
                }
              },
            ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : !widget.isClassTeacher
                ? _buildUnauthorizedView()
                : _errorMessage != null
                    ? _buildErrorView()
                    : Column(
                        children: [
                          _buildHeader(),
                          if (_isHoliday)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              color: colorScheme.surfaceVariant,
                              child: Row(
                                children: [
                                  const Icon(Icons.info_outline, color: Colors.blue),
                                  const SizedBox(width: 8),
                                  Text('Holiday: $_holidayName', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                                ],
                              ),
                            ),
                          if (_requiresReason)
                            Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: TextField(
                                controller: _reasonController,
                                decoration: const InputDecoration(
                                  labelText: 'Reason for marking/editing',
                                  prefixIcon: Icon(Icons.comment_rounded),
                                ),
                              ),
                            ),
                          Expanded(
                            child: ListView.separated(
                              padding: const EdgeInsets.only(bottom: 100),
                              itemCount: _students.length,
                              separatorBuilder: (context, index) => const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final student = _students[index];
                                final firstName = student['first_name'] ?? '';
                                final enrollmentId = student['enrollment_id'];
                                final status = _attendance[enrollmentId];

                                return ListTile(
                                  leading: CircleAvatar(
                                    child: Text(firstName.isNotEmpty ? firstName[0] : 'S'),
                                  ),
                                  title: Text('${student['first_name']} ${student['last_name']}'),
                                  subtitle: Text('Roll: ${student['roll_number'] ?? 'N/A'}'),
                                  trailing: _buildStatusChip(enrollmentId, status),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
      ),
      bottomNavigationBar: _isLoading || _errorMessage != null || !widget.isClassTeacher ? null : _buildBottomBar(),
    );
  }

  Widget _buildUnauthorizedView() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline_rounded, size: 64, color: colorScheme.primary),
            const SizedBox(height: 16),
            const Text(
              'Only the assigned class teacher is eligible to mark or edit attendance.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text(_errorMessage!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _fetchStudents, child: const Text('Retry')),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).cardColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                formatDate(_selectedDate.toIso8601String()),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('${_students.length} Students', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
          if (widget.isClassTeacher)
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      for (var student in _students) {
                        _attendance[student['enrollment_id']] = 'present';
                      }
                    });
                  },
                  child: const Text('All P', style: TextStyle(color: Colors.green)),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      for (var student in _students) {
                        _attendance[student['enrollment_id']] = 'absent';
                      }
                    });
                  },
                  child: const Text('All A', style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(int enrollmentId, String? status) {
    return PopupMenuButton<String>(
      enabled: widget.isClassTeacher,
      onSelected: (val) {
        setState(() => _attendance[enrollmentId] = val);
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'present', child: Text('Present')),
        const PopupMenuItem(value: 'absent', child: Text('Absent')),
        const PopupMenuItem(value: 'late', child: Text('Late')),
        const PopupMenuItem(value: 'half_day', child: Text('Half Day')),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: getStatusColor(status, context).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: getStatusColor(status, context).withOpacity(0.5)),
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
  }

  Widget _buildBottomBar() {
    if (!widget.isClassTeacher) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: ElevatedButton(
          onPressed: _isSaving ? null : _submitAttendance,
          child: _isSaving
              ? const CircularProgressIndicator(color: Colors.white)
              : const Text('Save Attendance'),
        ),
      ),
    );
  }
}

class AttendanceReportsPage extends StatefulWidget {
  const AttendanceReportsPage({super.key});

  @override
  State<AttendanceReportsPage> createState() => _AttendanceReportsPageState();
}

class _AttendanceReportsPageState extends State<AttendanceReportsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int? _selectedClassId;
  int? _selectedSectionId;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  List<dynamic> _classes = [];
  bool _isLoadingClasses = true;
  bool _isLoadingData = false;
  
  List<dynamic> _registerData = [];
  List<dynamic> _summaryData = [];
  List<dynamic> _thresholdData = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _fetchActiveTabData();
      }
    });
    _fetchClasses();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchClasses() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/teacher/my-classes'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            final myClass = data['data']['my_class'] ?? [];
            final subjectClasses = data['data']['subject_classes'] ?? [];
            _classes = [...myClass, ...subjectClasses];
            
            if (_classes.isNotEmpty) {
              _selectedClassId = _classes[0]['class_id'];
              _selectedSectionId = _classes[0]['section_id'];
              _fetchActiveTabData();
            }
            _isLoadingClasses = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load classes: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isLoadingClasses = false);
      }
    }
  }

  void _fetchActiveTabData() {
    switch (_tabController.index) {
      case 0: _fetchRegister(); break;
      case 1: _fetchSummary(); break;
      case 2: _fetchThreshold(); break;
    }
  }

  Future<void> _fetchRegister() async {
    if (_selectedClassId == null) return;
    setState(() => _isLoadingData = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/teacher/attendance/register?class_id=$_selectedClassId&section_id=$_selectedSectionId&month=$_selectedMonth&year=$_selectedYear'),
        headers: {'Authorization': 'Bearer ${authProvider.token}'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) setState(() => _registerData = data['data'] ?? []);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load register: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _isLoadingData = false);
  }

  Future<void> _fetchSummary() async {
    if (_selectedClassId == null) return;
    setState(() => _isLoadingData = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/teacher/attendance/reports/summary?class_id=$_selectedClassId&section_id=$_selectedSectionId'),
        headers: {'Authorization': 'Bearer ${authProvider.token}'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) setState(() => _summaryData = data['data'] ?? []);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load summary: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _isLoadingData = false);
  }

  Future<void> _fetchThreshold() async {
    setState(() => _isLoadingData = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/teacher/attendance/reports/below-threshold'),
        headers: {'Authorization': 'Bearer ${authProvider.token}'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) setState(() => _thresholdData = data['data'] ?? []);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load threshold data: $e'), backgroundColor: Colors.red),
        );
      }
    }
    if (mounted) setState(() => _isLoadingData = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Reports'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Register'),
            Tab(text: 'Summary'),
            Tab(text: 'Below 75%'),
          ],
        ),
      ),
      body: SafeArea(
        child: _isLoadingClasses 
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRegisterTab(),
                _buildSummaryTab(),
                _buildThresholdTab(),
              ],
            ),
      ),
    );
  }

  Widget _buildClassSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: DropdownButtonFormField<String>(
        value: _selectedClassId != null ? '$_selectedClassId-$_selectedSectionId' : null,
        decoration: const InputDecoration(labelText: 'Select Class', isDense: true),
        items: _classes.map((c) {
          return DropdownMenuItem(
            value: '${c['class_id']}-${c['section_id']}',
            child: Text('${c['class_name']} ${c['section_name']}'),
          );
        }).toList(),
        onChanged: (val) {
          if (val != null) {
            final parts = val.split('-');
            setState(() {
              _selectedClassId = int.parse(parts[0]);
              _selectedSectionId = int.parse(parts[1]);
              _fetchActiveTabData();
            });
          }
        },
      ),
    );
  }

  Widget _buildRegisterTab() {
    return Column(
      children: [
        _buildClassSelector(),
        _buildMonthYearPicker(),
        Expanded(
          child: _isLoadingData 
            ? const Center(child: CircularProgressIndicator())
            : _registerData.isEmpty 
              ? const Center(child: Text('No register data available'))
              : _buildRegisterGrid(),
        ),
      ],
    );
  }

  Widget _buildMonthYearPicker() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              value: _selectedMonth,
              decoration: const InputDecoration(labelText: 'Month', isDense: true),
              items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(getMonthName(i + 1)))),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedMonth = val);
                  _fetchRegister();
                }
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonFormField<int>(
              value: _selectedYear,
              decoration: const InputDecoration(labelText: 'Year', isDense: true),
              items: List.generate(3, (i) => DropdownMenuItem(value: 2024 + i, child: Text('${2024 + i}'))),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedYear = val);
                  _fetchRegister();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  String getMonthName(int m) {
    return ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][m-1];
  }

  Widget _buildRegisterGrid() {
    // Simplified Register Grid: Student Name | Status per day
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: SingleChildScrollView(
        child: DataTable(
          columnSpacing: 20,
          columns: [
            const DataColumn(label: Text('Student')),
            ...List.generate(31, (i) => DataColumn(label: Text('${i + 1}', style: const TextStyle(fontSize: 10)))),
          ],
          rows: _registerData.map<DataRow>((student) {
            final attendance = student['attendance'] as Map<String, dynamic>;
            return DataRow(
              cells: [
                DataCell(Text(student['name'], style: const TextStyle(fontWeight: FontWeight.bold))),
                ...List.generate(31, (i) {
                  final status = attendance['${i + 1}'];
                  return DataCell(
                    Center(
                      child: Text(
                        status == 'present' ? 'P' : (status == 'absent' ? 'A' : (status == 'late' ? 'L' : '-')),
                        style: TextStyle(
                          color: status == 'present' ? Colors.green : (status == 'absent' ? Colors.red : Colors.orange),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                }),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildSummaryTab() {
    return Column(
      children: [
        _buildClassSelector(),
        Expanded(
          child: _isLoadingData 
            ? const Center(child: CircularProgressIndicator())
            : _summaryData.isEmpty 
              ? const Center(child: Text('No summary data available'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _summaryData.length,
                  itemBuilder: (context, index) {
                    final s = _summaryData[index];
                    final perc = (s['percentage'] as num?)?.toDouble() ?? 0.0;
                    return Card(
                      child: ListTile(
                        title: Text(s['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('P: ${s['present']} | A: ${s['absent']} | L: ${s['late']}'),
                        trailing: SizedBox(
                          width: 60,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('${perc.toStringAsFixed(1)}%', style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: perc < 75 ? Colors.red : Colors.green,
                              )),
                              LinearProgressIndicator(
                                value: perc / 100,
                                backgroundColor: Colors.grey[200],
                                color: perc < 75 ? Colors.red : Colors.green,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildThresholdTab() {
    return _isLoadingData 
      ? const Center(child: CircularProgressIndicator())
      : _thresholdData.isEmpty 
        ? const Center(child: Text('All students are above 75%! 🎉'))
        : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _thresholdData.length,
            itemBuilder: (context, index) {
              final t = _thresholdData[index];
              final perc = (t['percentage'] as num?)?.toDouble() ?? 0.0;
              return Card(
                color: Colors.red[50],
                child: ListTile(
                  leading: const Icon(Icons.warning_amber_rounded, color: Colors.red),
                  title: Text(t['name'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                  subtitle: Text('${t['class_name']} ${t['section_name']}'),
                  trailing: Text(
                    '${perc.toStringAsFixed(1)}%',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 16),
                  ),
                ),
              );
            },
          );
  }
}
