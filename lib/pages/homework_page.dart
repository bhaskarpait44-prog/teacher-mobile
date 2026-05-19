import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/constants.dart';

class HomeworkPage extends StatefulWidget {
  const HomeworkPage({super.key});

  @override
  State<HomeworkPage> createState() => _HomeworkPageState();
}

class _HomeworkPageState extends State<HomeworkPage> {
  final _storage = const FlutterSecureStorage();
  bool _isLoading = true;
  List<dynamic> _homeworkList = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchHomework();
  }

  Future<void> _fetchHomework() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await _storage.read(key: 'token');
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/teacher/homework'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _homeworkList = data['data']['homework'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load homework';
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
        title: const Text('Homework'),
        actions: [
          IconButton(
            onPressed: _fetchHomework,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchHomework,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(child: Text(_errorMessage!))
                : _buildHomeworkList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateHomeworkPage()),
          ).then((_) => _fetchHomework());
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildHomeworkList() {
    if (_homeworkList.isEmpty) {
      return const Center(child: Text('No homework created yet.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _homeworkList.length,
      itemBuilder: (context, index) {
        final item = _homeworkList[index];
        final statusColor = item['workflow_status'] == 'completed' ? Colors.green : Colors.blue;

        return Card(
          child: ExpansionTile(
            title: Text(item['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${item['class_name']} ${item['section_name']} • ${item['subject_name']}'),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                item['workflow_status'].toString().toUpperCase(),
                style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Description: ${item['description'] ?? 'No description'}'),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Due: ${item['due_date']}'),
                        Text('Submissions: ${item['submitted_count']}/${item['student_count']}'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.edit, size: 18),
                          label: const Text('Edit'),
                        ),
                        TextButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.visibility, size: 18),
                          label: const Text('Submissions'),
                        ),
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
}

class CreateHomeworkPage extends StatefulWidget {
  const CreateHomeworkPage({super.key});

  @override
  State<CreateHomeworkPage> createState() => _CreateHomeworkPageState();
}

class _CreateHomeworkPageState extends State<CreateHomeworkPage> {
  final _formKey = GlobalKey<FormState>();
  final _storage = const FlutterSecureStorage();
  
  String? _title;
  String? _description;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 1));
  int? _selectedClassId;
  int? _selectedSectionId;
  int? _selectedSubjectId;
  String _submissionType = 'text';

  List<dynamic> _assignments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAssignments();
  }

  Future<void> _fetchAssignments() async {
    try {
      final token = await _storage.read(key: 'token');
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/teacher/dashboard'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          // Combine my_class and today_schedule to get unique class/section/subject combinations
          _assignments = data['data']['today_schedule'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedSubjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields')));
      return;
    }
    _formKey.currentState!.save();

    setState(() => _isLoading = true);

    try {
      final token = await _storage.read(key: 'token');
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/teacher/homework'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'class_id': _selectedClassId,
          'section_id': _selectedSectionId,
          'subject_id': _selectedSubjectId,
          'title': _title,
          'description': _description,
          'due_date': _dueDate.toIso8601String().split('T')[0],
          'submission_type': _submissionType,
        }),
      );

      if (response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Homework created successfully')));
          Navigator.pop(context);
        }
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Failed to create homework')));
        setState(() => _isLoading = false);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Homework')),
      body: _isLoading && _assignments.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    DropdownButtonFormField<int>(
                      decoration: const InputDecoration(labelText: 'Select Class/Subject'),
                      items: _assignments.map<DropdownMenuItem<int>>((a) {
                        return DropdownMenuItem<int>(
                          value: a['subject_id'], // Using subject_id as key for simplicity in this demo
                          child: Text('${a['class_name']} ${a['section_name']} - ${a['subject_name']}'),
                        );
                      }).toList(),
                      onChanged: (val) {
                        final a = _assignments.firstWhere((element) => element['subject_id'] == val);
                        setState(() {
                          _selectedClassId = a['class_id'];
                          _selectedSectionId = a['section_id'];
                          _selectedSubjectId = a['subject_id'];
                        });
                      },
                      validator: (val) => val == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Title'),
                      onSaved: (val) => _title = val,
                      validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Description'),
                      maxLines: 3,
                      onSaved: (val) => _description = val,
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: Text('Due Date: ${_dueDate.toIso8601String().split('T')[0]}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _dueDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 90)),
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
                      child: _isLoading ? const CircularProgressIndicator() : const Text('Create Homework'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
