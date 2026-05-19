import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../providers/auth_provider.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class MarksEntryPage extends StatefulWidget {
  const MarksEntryPage({super.key});

  @override
  State<MarksEntryPage> createState() => _MarksEntryPageState();
}

class _MarksEntryPageState extends State<MarksEntryPage> {
  bool _isLoading = true;
  List<dynamic> _exams = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchExams();
  }

  Future<void> _fetchExams() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/teacher/marks/exams'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _exams = data['data']['exams'] ?? [];
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to load exams';
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
      appBar: AppBar(title: const Text('Marks Entry')),
      body: RefreshIndicator(
        onRefresh: _fetchExams,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? _buildErrorWidget()
                : _buildExamList(),
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
              onPressed: _fetchExams,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExamList() {
    if (_exams.isEmpty) {
      return const Center(child: Text('No active exams found.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _exams.length,
      itemBuilder: (context, index) {
        final exam = _exams[index];
        return Card(
          child: ExpansionTile(
            title: Text(exam['exam_name'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('Term: ${exam['term_name'] ?? 'N/A'}'),
            children: (exam['subjects'] as List).map<Widget>((subject) {
              return ListTile(
                title: Text('${subject['subject_name']}'),
                subtitle: Text('${subject['class_name']} ${subject['section_name']}'),
                trailing: _buildStatusBadge(subject['entry_status']),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EnterMarksDetailPage(
                        examId: exam['exam_id'],
                        subjectId: subject['subject_id'],
                        classId: subject['class_id'],
                        sectionId: subject['section_id'],
                        subjectName: subject['subject_name'],
                        className: '${subject['class_name']} ${subject['section_name']}',
                        entryStatus: subject['entry_status'],
                      ),
                    ),
                  ).then((_) => _fetchExams());
                },
              );
            }).toList(),
          ),
        );
      },
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

class EnterMarksDetailPage extends StatefulWidget {
  final int examId;
  final int subjectId;
  final int classId;
  final int sectionId;
  final String subjectName;
  final String className;
  final String? entryStatus;

  const EnterMarksDetailPage({
    super.key,
    required this.examId,
    required this.subjectId,
    required this.classId,
    required this.sectionId,
    required this.subjectName,
    required this.className,
    this.entryStatus,
  });

  @override
  State<EnterMarksDetailPage> createState() => _EnterMarksDetailPageState();
}

class _EnterMarksDetailPageState extends State<EnterMarksDetailPage> {
  bool _isLoading = true;
  bool _isSaving = false;
  List<dynamic> _students = [];
  double _maxMarks = 100;
  final Map<int, TextEditingController> _controllers = {};
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchStudents();
  }

  @override
  void dispose() {
    for (var c in _controllers.values) {
      c.dispose();
    }
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
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/teacher/marks/entry?exam_id=${widget.examId}&subject_id=${widget.subjectId}&class_id=${widget.classId}&section_id=${widget.sectionId}'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _students = data['data']['students'] ?? [];
            _maxMarks = double.tryParse(data['data']['max_marks']?.toString() ?? '100') ?? 100;
            for (var student in _students) {
              _controllers[student['enrollment_id']] = TextEditingController(text: student['marks']?.toString() ?? '');
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

  Future<void> _saveMarks(bool isFinalSubmit) async {
    // Validate marks
    for (var student in _students) {
      final id = student['enrollment_id'];
      final val = double.tryParse(_controllers[id]!.text);
      if (val == null || val < 0 || val > _maxMarks) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid marks for ${student['first_name']}. Must be between 0 and $_maxMarks.')),
        );
        return;
      }
    }

    if (isFinalSubmit) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Confirm Submission'),
          content: const Text('This will lock marks entry for this subject. Continue?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Submit')),
          ],
        ),
      );
      if (confirmed != true) return;
    }

    setState(() => _isSaving = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      
      final marksData = _students.map((s) => {
        'enrollment_id': s['enrollment_id'],
        'marks': double.parse(_controllers[s['enrollment_id']]!.text),
      }).toList();

      final endpoint = isFinalSubmit ? '/teacher/marks/submit' : '/teacher/marks/bulk-save';
      
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'exam_id': widget.examId,
          'subject_id': widget.subjectId,
          'class_id': widget.classId,
          'section_id': widget.sectionId,
          if (!isFinalSubmit) 'marks_data': marksData,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isFinalSubmit ? 'Marks submitted successfully' : 'Marks saved as draft'), backgroundColor: Colors.green),
          );
          if (isFinalSubmit) {
            Navigator.pop(context);
          } else {
            setState(() => _isSaving = false);
          }
        }
      } else {
        final data = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Action failed')));
          setState(() => _isSaving = false);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitted = widget.entryStatus == 'submitted';
    return Scaffold(
      appBar: AppBar(title: Text('${widget.subjectName} (${_maxMarks})')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _students.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final student = _students[index];
                      final id = student['enrollment_id'];
                      return ListTile(
                        leading: CircleAvatar(child: Text(student['first_name'][0])),
                        title: Text('${student['first_name']} ${student['last_name']}'),
                        subtitle: Text('Roll: ${student['roll_number'] ?? 'N/A'}'),
                        trailing: SizedBox(
                          width: 80,
                          child: TextField(
                            controller: _controllers[id],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            enabled: !isSubmitted,
                            decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (!isSubmitted)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        ElevatedButton(
                          onPressed: _isSaving ? null : () => _saveMarks(false),
                          child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('Save All Marks (Draft)'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: _isSaving ? null : () => _saveMarks(true),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: Theme.of(context).colorScheme.primary),
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: const Text('Submit for Review'),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
