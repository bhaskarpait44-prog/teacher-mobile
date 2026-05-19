import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/constants.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final _storage = const FlutterSecureStorage();
  bool _isLoading = true;
  List<dynamic> _classes = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchAttendanceStatus();
  }

  Future<void> _fetchAttendanceStatus() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await _storage.read(key: 'token');
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/teacher/attendance/status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _classes = data['data']['classes'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load attendance status';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: RefreshIndicator(
        onRefresh: _fetchAttendanceStatus,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(child: Text(_errorMessage!))
                : _buildClassList(),
      ),
    );
  }

  Widget _buildClassList() {
    if (_classes.isEmpty) {
      return const Center(child: Text('No classes assigned to you for attendance.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _classes.length,
      itemBuilder: (context, index) {
        final item = _classes[index];
        final bool isMarked = item['marked_students'] >= item['total_students'] && item['total_students'] > 0;

        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isMarked ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1),
              child: Icon(
                isMarked ? Icons.check_circle : Icons.pending,
                color: isMarked ? Colors.green : Colors.orange,
              ),
            ),
            title: Text('${item['class_name']} ${item['section_name']}'),
            subtitle: Text('Marked: ${item['marked_students']}/${item['total_students']} students'),
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

  const MarkAttendancePage({
    super.key,
    required this.classId,
    required this.sectionId,
    required this.className,
    required this.sectionName,
  });

  @override
  State<MarkAttendancePage> createState() => _MarkAttendancePageState();
}

class _MarkAttendancePageState extends State<MarkAttendancePage> {
  final _storage = const FlutterSecureStorage();
  bool _isLoading = true;
  List<dynamic> _students = [];
  Map<int, String> _attendance = {}; 
  String? _errorMessage;
  DateTime _selectedDate = DateTime.now();
  String? _reason;

  @override
  void initState() {
    super.initState();
    _fetchStudents();
  }

  Future<void> _fetchStudents() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await _storage.read(key: 'token');
      final dateStr = _selectedDate.toIso8601String().split('T')[0];
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/teacher/attendance/students?class_id=${widget.classId}&section_id=${widget.sectionId}&date=$dateStr'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _students = data['data']['students'] ?? [];
          for (var student in _students) {
            _attendance[student['enrollment_id']] = student['status'] ?? 'present';
          }
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load students';
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

  Future<void> _submitAttendance() async {
    if (_selectedDate.isBefore(DateTime.now().subtract(const Duration(days: 1))) && (_reason == null || _reason!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a reason for past attendance marking')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final token = await _storage.read(key: 'token');
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
          'reason': _reason,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Attendance marked successfully')),
          );
          Navigator.pop(context);
        }
      } else {
        final data = jsonDecode(response.body);
        setState(() {
          _errorMessage = data['message'] ?? 'Failed to submit attendance';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.className} - ${widget.sectionName}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
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
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).primaryColor.withOpacity(0.05),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Date: ${_selectedDate.toIso8601String().split('T')[0]}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    Text('${_students.length} Students Total'),
                  ],
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      for (var student in _students) {
                        _attendance[student['enrollment_id']] = 'present';
                      }
                    });
                  },
                  icon: const Icon(Icons.done_all),
                  label: const Text('All Present'),
                ),
              ],
            ),
          ),
          if (_selectedDate.isBefore(DateTime.now().subtract(const Duration(days: 0)))) // If not today
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Reason for marking/editing (required for past dates)',
                  isDense: true,
                ),
                onChanged: (val) => _reason = val,
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(child: Text(_errorMessage!))
                    : ListView.builder(
                        itemCount: _students.length,
                        itemBuilder: (context, index) {
                          final student = _students[index];
                          final enrollmentId = student['enrollment_id'];
                          final status = _attendance[enrollmentId];

                          return ListTile(
                            leading: CircleAvatar(
                              child: Text(student['first_name'][0]),
                            ),
                            title: Text('${student['first_name']} ${student['last_name']}'),
                            subtitle: Text('Roll: ${student['roll_number'] ?? 'N/A'}'),
                            trailing: SegmentedButton<String>(
                              segments: const [
                                ButtonSegment(value: 'present', label: Text('P')),
                                ButtonSegment(value: 'absent', label: Text('A')),
                                ButtonSegment(value: 'late', label: Text('L')),
                              ],
                              selected: {status!},
                              onSelectionChanged: (val) {
                                setState(() {
                                  _attendance[enrollmentId] = val.first;
                                });
                              },
                              showSelectedIcon: false,
                              style: const ButtonStyle(
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          );
                        },
                      ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitAttendance,
              child: const Text('Save Attendance'),
            ),
          ),
        ],
      ),
    );
  }
}
