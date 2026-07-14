import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../providers/auth_provider.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../utils/file_helper.dart';

class CreateNoticePage extends StatefulWidget {
  const CreateNoticePage({super.key});

  @override
  State<CreateNoticePage> createState() => _CreateNoticePageState();
}

class _CreateNoticePageState extends State<CreateNoticePage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSubmitting = false;
  
  List<dynamic> _classes = [];
  List<dynamic> _allAssignments = [];
  List<dynamic> _subjects = [];
  List<dynamic> _students = [];
  
  String _selectedAudience = 'class'; // 'class', 'section', 'students', 'subject_wise'
  int? _selectedClassId;
  int? _selectedSectionId;
  int? _selectedSubjectId;
  int? _selectedStudentId;
  String _selectedPriority = 'normal'; // 'normal', 'urgent', 'info'
  
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  DateTime? _expiryDate;
  File? _selectedFile;

  @override
  void initState() {
    super.initState();
    _fetchClasses();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _fetchClasses() async {
    setState(() => _isLoading = true);
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/teacher/my-classes'),
        headers: {'Authorization': 'Bearer ${authProvider.token}'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          final myClass = data['data']['my_class'] ?? [];
          final subjectClasses = data['data']['subject_classes'] ?? [];
          final all = [...myClass, ...subjectClasses];
          
          final seen = <String>{};
          final unique = all.where((a) {
            final key = '${a['class_id']}-${a['section_id']}';
            if (seen.contains(key)) return false;
            seen.add(key);
            return true;
          }).toList();

          setState(() {
            _allAssignments = all;
            _classes = unique;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() => _isLoading = false);
      }
    }
  }

  void _onClassChanged(String? val) {
    if (val == null) return;
    final parts = val.split('-');
    setState(() {
      _selectedClassId = int.parse(parts[0]);
      _selectedSectionId = int.parse(parts[1]);
      _selectedSubjectId = null;
      _selectedStudentId = null;
      _subjects = [];
      _students = [];
    });
    
    if (_selectedAudience == 'subject_wise') _fetchSubjects();
    if (_selectedAudience == 'students') _fetchStudents();
  }

  void _fetchSubjects() {
    if (_selectedClassId == null || _selectedSectionId == null) return;
    final subs = _allAssignments
        .where((a) => a['class_id'] == _selectedClassId && a['section_id'] == _selectedSectionId && a['subject_id'] != null)
        .map((a) => {'id': a['subject_id'], 'name': a['subject_name']})
        .toList();
    
    final seen = <int>{};
    setState(() {
      _subjects = subs.where((s) {
        if (seen.contains(s['id'])) return false;
        seen.add(s['id'] as int);
        return true;
      }).toList();
    });
  }

  Future<void> _fetchStudents() async {
    if (_selectedClassId == null || _selectedSectionId == null) return;
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/teacher/students?class_id=$_selectedClassId&section_id=$_selectedSectionId'),
        headers: {'Authorization': 'Bearer ${authProvider.token}'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) setState(() => _students = data['data']['students'] ?? []);
      }
    } catch (_) {}
  }

  Future<void> _pickFile() async {
    await FileHelper.requestPermissions();
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_selectedClassId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a class')));
      return;
    }

    if (_selectedAudience == 'subject_wise' && _selectedSubjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a subject')));
      return;
    }

    if (_selectedAudience == 'students' && _selectedStudentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a student')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConstants.baseUrl}/notices/teacher'),
      );
      
      request.headers['Authorization'] = 'Bearer ${authProvider.token}';
      
      request.fields['title'] = _titleController.text.trim();
      request.fields['body'] = _bodyController.text.trim();
      request.fields['audience'] = _selectedAudience;
      request.fields['target_class_id'] = _selectedClassId.toString();
      request.fields['target_section_id'] = _selectedSectionId.toString();
      if (_selectedSubjectId != null) request.fields['target_subject_id'] = _selectedSubjectId.toString();
      if (_selectedAudience == 'students' && _selectedStudentId != null) {
        request.fields['target_student_id'] = _selectedStudentId.toString();
      }
      request.fields['priority'] = _selectedPriority;
      if (_expiryDate != null) request.fields['expires_at'] = _expiryDate!.toIso8601String();

      if (_selectedFile != null) {
        request.files.add(await http.MultipartFile.fromPath(
          'attachment',
          _selectedFile!.path,
        ));
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notice created successfully'), backgroundColor: Colors.green));
          Navigator.pop(context, true);
        }
      } else {
        final data = jsonDecode(response.body);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Failed to create notice')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Notice')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Target Audience'),
                    initialValue: _selectedAudience,
                    items: const [
                      DropdownMenuItem(value: 'class', child: Text('Whole Class')),
                      DropdownMenuItem(value: 'section', child: Text('Specific Section')),
                      DropdownMenuItem(value: 'subject_wise', child: Text('Subject Wise')),
                      DropdownMenuItem(value: 'students', child: Text('Specific Student')),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedAudience = val!;
                        _selectedSubjectId = null;
                        _selectedStudentId = null;
                      });
                      if (val == 'subject_wise') _fetchSubjects();
                      if (val == 'students') _fetchStudents();
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Class & Section'),
                    initialValue: _selectedClassId != null ? '$_selectedClassId-$_selectedSectionId' : null,
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
                  if (_selectedAudience == 'subject_wise') ...[
                    DropdownButtonFormField<int>(
                      decoration: const InputDecoration(labelText: 'Select Subject'),
                      initialValue: _selectedSubjectId,
                      items: _subjects.map((s) => DropdownMenuItem<int>(value: s['id'], child: Text(s['name']))).toList(),
                      onChanged: (val) => setState(() => _selectedSubjectId = val),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (_selectedAudience == 'students') ...[
                    DropdownButtonFormField<int>(
                      decoration: const InputDecoration(labelText: 'Select Student'),
                      initialValue: _selectedStudentId,
                      items: _students.map((s) => DropdownMenuItem<int>(value: s['student_id'], child: Text('${s['first_name']} ${s['last_name']}'))).toList(),
                      onChanged: (val) => setState(() => _selectedStudentId = val),
                      validator: (v) => v == null ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                  ],
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Priority'),
                    initialValue: _selectedPriority,
                    items: const [
                      DropdownMenuItem(value: 'normal', child: Text('Normal')),
                      DropdownMenuItem(value: 'info', child: Text('Info')),
                      DropdownMenuItem(value: 'urgent', child: Text('Urgent')),
                    ],
                    onChanged: (val) => setState(() => _selectedPriority = val!),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Title'),
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _bodyController,
                    decoration: const InputDecoration(labelText: 'Content'),
                    maxLines: 5,
                    validator: (v) => v == null || v.isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Expiry Date (Optional)', style: TextStyle(fontSize: 12)),
                    subtitle: Text(_expiryDate == null ? 'None' : formatDate(_expiryDate!.toIso8601String()), style: const TextStyle(fontSize: 16)),
                    trailing: const Icon(Icons.calendar_today_rounded),
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(const Duration(days: 7)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 365)),
                      );
                      if (picked != null) setState(() => _expiryDate = picked);
                    },
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.attach_file),
                    label: Text(_selectedFile == null ? 'Attach PDF' : 'Change PDF: ${_selectedFile!.path.split('/').last}'),
                  ),
                  if (_selectedFile != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('Selected: ${_selectedFile!.path.split('/').last}', style: const TextStyle(fontSize: 12, color: Colors.green)),
                    ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text('Post Notice'),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}
