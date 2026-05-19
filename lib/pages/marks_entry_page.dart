import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/constants.dart';

class MarksEntryPage extends StatefulWidget {
  const MarksEntryPage({super.key});

  @override
  State<MarksEntryPage> createState() => _MarksEntryPageState();
}

class _MarksEntryPageState extends State<MarksEntryPage> {
  final _storage = const FlutterSecureStorage();
  bool _isLoading = true;
  List<dynamic> _exams = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchExams();
  }

  Future<void> _fetchExams() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await _storage.read(key: 'token');
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/teacher/marks/exams'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _exams = data['data']['exams'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load exams';
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
      appBar: AppBar(title: const Text('Marks Entry')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : _buildExamList(),
    );
  }

  Widget _buildExamList() {
    if (_exams.isEmpty) {
      return const Center(child: Text('No active exams found for marks entry.'));
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
                trailing: const Icon(Icons.chevron_right),
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
                      ),
                    ),
                  );
                },
              );
            }).toList(),
          ),
        );
      },
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

  const EnterMarksDetailPage({
    super.key,
    required this.examId,
    required this.subjectId,
    required this.classId,
    required this.sectionId,
    required this.subjectName,
    required this.className,
  });

  @override
  State<EnterMarksDetailPage> createState() => _EnterMarksDetailPageState();
}

class _EnterMarksDetailPageState extends State<EnterMarksDetailPage> {
  final _storage = const FlutterSecureStorage();
  bool _isLoading = true;
  bool _isSaving = false;
  List<dynamic> _students = [];
  Map<int, TextEditingController> _controllers = {};
  String? _errorMessage;

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
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/teacher/marks/entry?exam_id=${widget.examId}&subject_id=${widget.subjectId}&class_id=${widget.classId}&section_id=${widget.sectionId}'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _students = data['data']['students'] ?? [];
          for (var student in _students) {
            _controllers[student['enrollment_id']] = TextEditingController(text: student['marks']?.toString() ?? '');
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

  Future<void> _saveMarks() async {
    setState(() => _isSaving = true);

    try {
      final token = await _storage.read(key: 'token');
      final records = _students.map((student) {
        final enrollmentId = student['enrollment_id'];
        return {
          'enrollment_id': enrollmentId,
          'marks': double.tryParse(_controllers[enrollmentId]!.text) ?? 0.0,
        };
      }).toList();

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/teacher/marks/bulk-save'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'exam_id': widget.examId,
          'subject_id': widget.subjectId,
          'class_id': widget.classId,
          'section_id': widget.sectionId,
          'marks_data': records,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marks saved successfully')));
          Navigator.pop(context);
        }
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Failed to save marks')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('${widget.subjectName} - ${widget.className}')),
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
                      return ListTile(
                        leading: CircleAvatar(child: Text(student['first_name'][0])),
                        title: Text('${student['first_name']} ${student['last_name']}'),
                        subtitle: Text('Roll: ${student['roll_number'] ?? 'N/A'}'),
                        trailing: SizedBox(
                          width: 80,
                          child: TextField(
                            controller: _controllers[student['enrollment_id']],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(
                              hintText: 'Marks',
                              isDense: true,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveMarks,
                    child: _isSaving ? const CircularProgressIndicator() : const Text('Save All Marks'),
                  ),
                ),
              ],
            ),
    );
  }
}
