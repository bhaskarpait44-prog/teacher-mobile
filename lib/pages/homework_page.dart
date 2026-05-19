import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../providers/auth_provider.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class HomeworkPage extends StatefulWidget {
  const HomeworkPage({super.key});

  @override
  State<HomeworkPage> createState() => _HomeworkPageState();
}

class _HomeworkPageState extends State<HomeworkPage> {
  bool _isLoading = true;
  List<dynamic> _homeworkList = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchHomework();
  }

  Future<void> _fetchHomework() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/teacher/homework'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _homeworkList = data['data']['homework'] ?? [];
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to load homework';
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

  Future<void> _deleteHomework(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Homework'),
        content: const Text('Are you sure you want to delete this homework? This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final token = authProvider.token;
        final response = await http.delete(
          Uri.parse('${ApiConstants.baseUrl}/teacher/homework/$id'),
          headers: {'Authorization': 'Bearer $token'},
        );

        if (response.statusCode == 200) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Homework deleted successfully'), backgroundColor: Colors.green),
            );
            _fetchHomework();
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting homework: $e')));
        }
      }
    }
  }

  Future<void> _sendReminder(int id) async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/teacher/homework/$id/remind'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Reminders sent to students'), backgroundColor: Colors.green),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error sending reminders: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Homework'),
        actions: [
          IconButton(onPressed: _fetchHomework, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchHomework,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? _buildErrorWidget()
                  : _buildHomeworkList(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateHomeworkPage()),
          ).then((_) => _fetchHomework());
        },
        child: const Icon(Icons.add_rounded),
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
            Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchHomework,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeworkList() {
    if (_homeworkList.isEmpty) {
      return const Center(child: Text('No homework assigned yet.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _homeworkList.length,
      itemBuilder: (context, index) {
        final item = _homeworkList[index];
        final colorScheme = Theme.of(context).colorScheme;
        final dueDate = DateTime.tryParse(item['due_date'] ?? '');
        final bool isOverdue = dueDate != null && dueDate.isBefore(DateTime.now()) && item['workflow_status'] != 'completed';

        return Card(
          child: ExpansionTile(
            title: Text(item['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${item['class_name']} ${item['section_name']} • ${item['subject_name']}'),
            leading: Icon(
              Icons.assignment_rounded,
              color: getStatusColor(item['workflow_status'], context),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item['description'] != null && item['description'].isNotEmpty) ...[
                      const Text('Description:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(item['description']),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Due Date', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            Text(formatDate(item['due_date'])),
                          ],
                        ),
                        if (isOverdue)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: colorScheme.error, borderRadius: BorderRadius.circular(4)),
                            child: const Text('OVERDUE', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Submissions: ${item['submitted_count']}/${item['student_count']}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: item['student_count'] > 0 ? item['submitted_count'] / item['student_count'] : 0,
                      backgroundColor: colorScheme.surfaceVariant,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildActionButton(Icons.edit_outlined, 'Edit', () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CreateHomeworkPage(homework: item),
                            ),
                          ).then((_) => _fetchHomework());
                        }),
                        _buildActionButton(Icons.visibility_outlined, 'Submissions', () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => HomeworkSubmissionsPage(
                                homeworkId: item['id'],
                                title: item['title'],
                              ),
                            ),
                          );
                        }),
                        _buildActionButton(Icons.notifications_outlined, 'Remind', () => _sendReminder(item['id'])),
                        _buildActionButton(Icons.delete_outline, 'Delete', () => _deleteHomework(item['id']), color: colorScheme.error),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap, {Color? color}) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, size: 20, color: color ?? Theme.of(context).colorScheme.primary),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 10, color: color ?? Theme.of(context).colorScheme.primary)),
        ],
      ),
    );
  }
}

class CreateHomeworkPage extends StatefulWidget {
  final Map<String, dynamic>? homework;
  const CreateHomeworkPage({super.key, this.homework});

  @override
  State<CreateHomeworkPage> createState() => _CreateHomeworkPageState();
}

class _CreateHomeworkPageState extends State<CreateHomeworkPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  List<dynamic> _classes = [];
  List<dynamic> _subjects = [];
  bool _isSubjectsLoading = false;

  int? _selectedClassId;
  int? _selectedSectionId;
  int? _selectedSubjectId;
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 1));
  String _submissionType = 'text';

  bool get _isEditing => widget.homework != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _titleController.text = widget.homework!['title'] ?? '';
      _descController.text = widget.homework!['description'] ?? '';
      _dueDate = DateTime.tryParse(widget.homework!['due_date'] ?? '') ?? _dueDate;
      _submissionType = widget.homework!['submission_type'] ?? 'text';
      _selectedClassId = widget.homework!['class_id'];
      _selectedSectionId = widget.homework!['section_id'];
      _selectedSubjectId = widget.homework!['subject_id'];
    }
    _fetchClasses();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
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
            _classes = data['data']['classes'] ?? [];
            if (_isEditing) {
               // Load subjects for the existing class
               _onClassChanged('${_selectedClassId}-${_selectedSectionId}', fetchOnly: true);
            }
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchSubjects() async {
    if (_selectedClassId == null || _selectedSectionId == null) return;

    setState(() => _isSubjectsLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;

      // Step 1: Try to fetch from marks/exams
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/teacher/marks/exams'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List exams = data['data']['exams'] ?? [];
        final List<Map<String, dynamic>> foundSubjects = [];
        final Set<int> subjectIds = {};

        for (var exam in exams) {
          final List subjects = exam['subjects'] ?? [];
          for (var s in subjects) {
            if (s['class_id'] == _selectedClassId && s['section_id'] == _selectedSectionId) {
              if (!subjectIds.contains(s['subject_id'])) {
                subjectIds.add(s['subject_id']);
                foundSubjects.add({
                  'id': s['subject_id'],
                  'name': s['subject_name'],
                });
              }
            }
          }
        }

        if (foundSubjects.isNotEmpty) {
          if (mounted) {
            setState(() {
              _subjects = foundSubjects;
              _isSubjectsLoading = false;
            });
            return;
          }
        }
      }

      // Step 2: Fallback to timetable if no exams or subjects found
      final timetableRes = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/teacher/timetable'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (timetableRes.statusCode == 200) {
        final data = jsonDecode(timetableRes.body);
        final Map<String, dynamic> timetable = data['data']['timetable'] ?? {};
        final List<Map<String, dynamic>> foundSubjects = [];
        final Set<String> subjectNames = {};

        timetable.forEach((day, periods) {
          for (var p in (periods as List)) {
            if (p['class_id'] == _selectedClassId && p['section_id'] == _selectedSectionId) {
              if (!subjectNames.contains(p['subject_name'])) {
                subjectNames.add(p['subject_name']);
                foundSubjects.add({
                  'id': p['subject_id'] ?? subjectNames.length, // use subject_id if exists
                  'name': p['subject_name'],
                });
              }
            }
          }
        });

        if (mounted) {
          setState(() {
            _subjects = foundSubjects;
            _isSubjectsLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isSubjectsLoading = false);
      }
    } catch (_) {
      if (mounted) setState(() => _isSubjectsLoading = false);
    }
  }

  void _onClassChanged(String? val, {bool fetchOnly = false}) {
    if (val == null) return;
    final parts = val.split('-');
    setState(() {
      _selectedClassId = int.parse(parts[0]);
      _selectedSectionId = int.parse(parts[1]);
      if (!fetchOnly) _selectedSubjectId = null;
      _subjects = [];
    });
    _fetchSubjects();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedSubjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      
      final url = _isEditing 
        ? '${ApiConstants.baseUrl}/teacher/homework/${widget.homework!['id']}'
        : '${ApiConstants.baseUrl}/teacher/homework';
      
      final method = _isEditing ? http.patch : http.post;

      final response = await method(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'class_id': _selectedClassId,
          'section_id': _selectedSectionId,
          'subject_id': _selectedSubjectId,
          'title': _titleController.text.trim(),
          'description': _descController.text.trim(),
          'due_date': _dueDate.toIso8601String().split('T')[0],
          'submission_type': _submissionType,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(_isEditing ? 'Homework updated successfully' : 'Homework created successfully'), backgroundColor: Colors.green),
          );
          Navigator.pop(context);
        }
      } else {
        final data = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Action failed')));
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Homework' : 'Create Homework')),
      body: SafeArea(
        child: _isLoading && _classes.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Class & Section'),
                        value: _selectedClassId != null ? '${_selectedClassId}-${_selectedSectionId}' : null,
                        items: _classes.map((c) {
                          return DropdownMenuItem(
                            value: '${c['class_id']}-${c['section_id']}',
                            child: Text('${c['class_name']} ${c['section_name']}'),
                          );
                        }).toList(),
                        onChanged: _onClassChanged,
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        decoration: InputDecoration(
                          labelText: 'Subject',
                          suffixIcon: _isSubjectsLoading 
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : null,
                        ),
                        value: _selectedSubjectId,
                        items: _subjects.map((s) {
                          return DropdownMenuItem<int>(value: s['id'], child: Text(s['name']));
                        }).toList(),
                        onChanged: _isSubjectsLoading ? null : (val) => setState(() => _selectedSubjectId = val),
                        validator: (v) => v == null ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _titleController,
                        decoration: const InputDecoration(labelText: 'Title'),
                        validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descController,
                        decoration: const InputDecoration(labelText: 'Description'),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Due Date', style: TextStyle(fontSize: 12)),
                        subtitle: Text(formatDate(_dueDate.toIso8601String()), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        trailing: const Icon(Icons.calendar_today_rounded),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _dueDate,
                            firstDate: _isEditing ? _dueDate.subtract(const Duration(days: 365)) : DateTime.now(),
                            lastDate: DateTime.now().add(const Duration(days: 365)),
                          );
                          if (picked != null) setState(() => _dueDate = picked);
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Submission Type'),
                        value: _submissionType,
                        items: const [
                          DropdownMenuItem(value: 'text', child: Text('Text Only')),
                          DropdownMenuItem(value: 'file', child: Text('File Upload')),
                          DropdownMenuItem(value: 'both', child: Text('Both')),
                        ],
                        onChanged: (val) => setState(() => _submissionType = val!),
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        child: Text(_isEditing ? 'Update Homework' : 'Create Homework'),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}

class HomeworkSubmissionsPage extends StatefulWidget {
  final int homeworkId;
  final String title;

  const HomeworkSubmissionsPage({
    super.key,
    required this.homeworkId,
    required this.title,
  });

  @override
  State<HomeworkSubmissionsPage> createState() => _HomeworkSubmissionsPageState();
}

class _HomeworkSubmissionsPageState extends State<HomeworkSubmissionsPage> {
  bool _isLoading = true;
  List<dynamic> _submissions = [];
  final Map<int, TextEditingController> _marksControllers = {};
  final Map<int, TextEditingController> _feedbackControllers = {};

  @override
  void initState() {
    super.initState();
    _fetchSubmissions();
  }

  @override
  void dispose() {
    for (var c in _marksControllers.values) {
      c.dispose();
    }
    for (var c in _feedbackControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _fetchSubmissions() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/teacher/homework/${widget.homeworkId}/submissions'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _submissions = data['data']['submissions'] ?? [];
            for (var sub in _submissions) {
              final id = sub['enrollment_id'];
              _marksControllers[id] = TextEditingController(text: sub['marks_obtained']?.toString() ?? '');
              _feedbackControllers[id] = TextEditingController(text: sub['teacher_comment'] ?? '');
            }
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveGrades() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;

      for (var sub in _submissions) {
        final id = sub['enrollment_id'];
        final marks = _marksControllers[id]?.text;
        final feedback = _feedbackControllers[id]?.text;

        if (marks != null && marks.isNotEmpty) {
          await http.post(
            Uri.parse('${ApiConstants.baseUrl}/teacher/homework/${widget.homeworkId}/grade'),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'enrollment_id': id,
              'marks': marks,
              'feedback': feedback,
            }),
          );
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Grades saved successfully'), backgroundColor: Colors.green));
        _fetchSubmissions();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving grades: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Submissions: ${widget.title}')),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  Expanded(
                    child: _submissions.isEmpty
                        ? const Center(child: Text('No submissions yet'))
                        : ListView.builder(
                            padding: const EdgeInsets.all(16),
                            itemCount: _submissions.length,
                            itemBuilder: (context, index) {
                              final sub = _submissions[index];
                              final id = sub['enrollment_id'];
                              return Card(
                                margin: const EdgeInsets.only(bottom: 16),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text('${sub['first_name']} ${sub['last_name']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                          _buildStatusBadge(sub['status']),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      if (sub['submitted_at'] != null)
                                        Text('Submitted: ${formatDate(sub['submitted_at'])}', style: const TextStyle(fontSize: 12)),
                                      const SizedBox(height: 12),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              controller: _marksControllers[id],
                                              decoration: const InputDecoration(labelText: 'Marks', border: OutlineInputBorder()),
                                              keyboardType: TextInputType.number,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            flex: 2,
                                            child: TextFormField(
                                              controller: _feedbackControllers[id],
                                              decoration: const InputDecoration(labelText: 'Feedback', border: OutlineInputBorder()),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: ElevatedButton(
                      onPressed: _submissions.isEmpty ? null : _saveGrades,
                      child: const Text('Save All Grades'),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildStatusBadge(String? status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: getStatusColor(status, context).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status?.toUpperCase() ?? 'PENDING',
        style: TextStyle(color: getStatusColor(status, context), fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
