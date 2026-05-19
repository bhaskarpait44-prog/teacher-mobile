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
    if (!mounted) return;
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
              // Navigation to attendance reports/history
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchAttendanceStatus,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? _buildErrorWidget()
                : _buildClassList(),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: _fetchAttendanceStatus, child: const Text('Retry')),
        ],
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: (isMarked ? Colors.green : Colors.orange).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isMarked ? Icons.check_circle_rounded : Icons.pending_rounded,
                color: isMarked ? Colors.green : Colors.orange,
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
                Text('Marked: ${item['marked_students']}/${item['total_students']} students'),
                LinearProgressIndicator(
                  value: item['total_students'] > 0 ? item['marked_students'] / item['total_students'] : 0,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(isMarked ? Colors.green : Colors.orange),
                ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
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
  bool _isSaving = false;
  List<dynamic> _students = [];
  Map<dynamic, String> _attendance = {}; 
  String? _errorMessage;
  DateTime _selectedDate = DateTime.now();
  String? _reason;
  bool _requiresReason = false;
  bool _isHoliday = false;
  String? _holidayName;

  @override
  void initState() {
    super.initState();
    _fetchStudents();
  }

  Future<void> _fetchStudents() async {
    if (!mounted) return;
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
            _errorMessage = 'Failed to load students';
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

  Future<void> _submitAttendance() async {
    if (_requiresReason && (_reason == null || _reason!.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a reason for marking/editing attendance')),
      );
      return;
    }

    setState(() => _isSaving = true);

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
            const SnackBar(content: Text('Attendance saved successfully'), backgroundColor: Colors.green),
          );
          Navigator.pop(context);
        }
      } else {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _errorMessage = data['message'] ?? 'Failed to submit attendance';
            _isSaving = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'An error occurred: $e';
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.className} - ${widget.sectionName}'),
        actions: [
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildHeader(),
                if (_isHoliday)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    color: Colors.blue[50],
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
                      decoration: const InputDecoration(
                        labelText: 'Reason for marking/editing',
                        hintText: 'e.g., Internet issues, system down, etc.',
                        prefixIcon: Icon(Icons.comment_rounded),
                      ),
                      onChanged: (val) => _reason = val,
                    ),
                  ),
                Expanded(
                  child: _errorMessage != null
                      ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
                      : ListView.separated(
                          padding: const EdgeInsets.only(bottom: 80),
                          itemCount: _students.length,
                          separatorBuilder: (context, index) => const Divider(height: 1, indent: 70),
                          itemBuilder: (context, index) {
                            final student = _students[index];
                            final enrollmentId = student['enrollment_id'];
                            final status = _attendance[enrollmentId];

                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              leading: CircleAvatar(
                                radius: 25,
                                backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                                child: Text(
                                  student['first_name'][0],
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                                ),
                              ),
                              title: Text(
                                '${student['first_name']} ${student['last_name']}',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text('Roll No: ${student['roll_number'] ?? 'N/A'}'),
                              trailing: _buildStatusPicker(enrollmentId, status),
                            );
                          },
                        ),
                ),
              ],
            ),
      bottomSheet: _isLoading || _errorMessage != null ? null : _buildBottomBar(),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))],
      ),
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
              Text('${_students.length} Students Total', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            ],
          ),
          Row(
            children: [
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    for (var student in _students) {
                      _attendance[student['enrollment_id']] = 'present';
                    }
                  });
                },
                icon: const Icon(Icons.done_all_rounded, size: 20),
                label: const Text('All P'),
                style: TextButton.styleFrom(foregroundColor: Colors.green),
              ),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    for (var student in _students) {
                      _attendance[student['enrollment_id']] = 'absent';
                    }
                  });
                },
                icon: const Icon(Icons.close_rounded, size: 20),
                label: const Text('All A'),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusPicker(dynamic enrollmentId, String? currentStatus) {
    return PopupMenuButton<String>(
      initialValue: currentStatus,
      onSelected: (String value) {
        setState(() {
          _attendance[enrollmentId] = value;
        });
      },
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        _buildPopupItem('present', 'Present', Colors.green),
        _buildPopupItem('absent', 'Absent', Colors.red),
        _buildPopupItem('late', 'Late', Colors.orange),
        _buildPopupItem('half_day', 'Half Day', Colors.blue),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _getStatusColor(currentStatus).withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _getStatusColor(currentStatus).withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              currentStatus?.toUpperCase() ?? 'NONE',
              style: TextStyle(color: _getStatusColor(currentStatus), fontWeight: FontWeight.bold, fontSize: 12),
            ),
            const SizedBox(width: 4),
            Icon(Icons.arrow_drop_down, color: _getStatusColor(currentStatus), size: 16),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildPopupItem(String value, String label, Color color) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Text(label),
        ],
      ),
    );
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'present': return Colors.green;
      case 'absent': return Colors.red;
      case 'late': return Colors.orange;
      case 'half_day': return Colors.blue;
      case 'holiday': return Colors.purple;
      default: return Colors.grey;
    }
  }

  Widget _buildBottomBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -2))],
      ),
      child: ElevatedButton(
        onPressed: _isSaving ? null : _submitAttendance,
        child: _isSaving
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Text('Save Attendance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }
}
