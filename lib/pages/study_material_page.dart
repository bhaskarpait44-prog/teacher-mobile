import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../providers/auth_provider.dart';
import '../utils/constants.dart';
import '../utils/file_helper.dart';

class StudyMaterialPage extends StatefulWidget {
  const StudyMaterialPage({super.key});

  @override
  State<StudyMaterialPage> createState() => _StudyMaterialPageState();
}

class _StudyMaterialPageState extends State<StudyMaterialPage> {
  bool _isLoading = true;
  List<dynamic> _materialsList = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchMaterials();
  }

  Future<void> _fetchMaterials() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/teacher/study-materials'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _materialsList = data['data']['materials'] ?? [];
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to load study materials';
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

  Future<void> _deleteMaterial(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Material'),
        content: const Text('Are you sure you want to delete this study material?'),
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
          Uri.parse('${ApiConstants.baseUrl}/teacher/study-materials/$id'),
          headers: {'Authorization': 'Bearer $token'},
        );

        if (response.statusCode == 200) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Material deleted successfully'), backgroundColor: Colors.green),
            );
            _fetchMaterials();
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting material: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Study Materials'),
        actions: [
          IconButton(onPressed: _fetchMaterials, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchMaterials,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? _buildErrorWidget()
                  : _buildMaterialsList(),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateStudyMaterialPage()),
          ).then((_) => _fetchMaterials());
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
              onPressed: _fetchMaterials,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialsList() {
    if (_materialsList.isEmpty) {
      return const Center(child: Text('No study materials uploaded yet.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _materialsList.length,
      itemBuilder: (context, index) {
        final item = _materialsList[index];
        final colorScheme = Theme.of(context).colorScheme;

        return Card(
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.redAccent,
              child: Icon(Icons.picture_as_pdf, color: Colors.white, size: 20),
            ),
            title: Text(item['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${item['class_name']} • ${item['subject_name']}'),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _deleteMaterial(item['id']),
            ),
            onTap: () {
              final fileName = item['file_path']?.split('/').last ?? 'material_${item['id']}.pdf';
              final url = item['file_path'].startsWith('http') 
                  ? item['file_path'] 
                  : '${ApiConstants.mediaUrl}/${item['file_path']}';
              FileHelper.downloadAndOpenFile(context, url, fileName);
            },
          ),
        );
      },
    );
  }
}

class CreateStudyMaterialPage extends StatefulWidget {
  const CreateStudyMaterialPage({super.key});

  @override
  State<CreateStudyMaterialPage> createState() => _CreateStudyMaterialPageState();
}

class _CreateStudyMaterialPageState extends State<CreateStudyMaterialPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = true;
  bool _isSubmitting = false;
  
  List<dynamic> _classes = [];
  List<dynamic> _allAssignments = [];
  List<dynamic> _subjects = [];
  
  int? _selectedClassId;
  int? _selectedSectionId;
  int? _selectedSubjectId;
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  File? _selectedFile;

  @override
  void initState() {
    super.initState();
    _fetchClasses();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
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
            _allAssignments = subjectClasses;
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
      _subjects = [];
    });
    _fetchSubjects();
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

  Future<void> _pickFile() async {
    await FileHelper.requestPermissions();
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'ppt', 'pptx', 'xls', 'xlsx', 'jpg', 'jpeg', 'png', 'webp', 'txt'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _selectedFile = File(result.files.single.path!);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedSubjectId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please attach a PDF file')));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConstants.baseUrl}/teacher/study-materials'),
      );
      
      request.headers['Authorization'] = 'Bearer ${authProvider.token}';
      
      request.fields['title'] = _titleController.text.trim();
      request.fields['description'] = _descController.text.trim();
      request.fields['class_id'] = _selectedClassId.toString();
      request.fields['subject_id'] = _selectedSubjectId.toString();

      request.files.add(await http.MultipartFile.fromPath(
        'file',
        _selectedFile!.path,
      ));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Material uploaded successfully'), backgroundColor: Colors.green));
          Navigator.pop(context, true);
        }
      } else {
        final data = jsonDecode(response.body);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Failed to upload material')));
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
      appBar: AppBar(title: const Text('Upload Material')),
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
                    decoration: const InputDecoration(labelText: 'Class & Section'),
                    value: _selectedClassId != null ? '$_selectedClassId-$_selectedSectionId' : null,
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
                    decoration: const InputDecoration(labelText: 'Select Subject'),
                    value: _selectedSubjectId,
                    items: _subjects.map((s) => DropdownMenuItem<int>(value: s['id'], child: Text(s['name']))).toList(),
                    onChanged: (val) => setState(() => _selectedSubjectId = val),
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
                    decoration: const InputDecoration(labelText: 'Description (Optional)'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    onPressed: _pickFile,
                    icon: const Icon(Icons.attach_file),
                    label: Text(_selectedFile == null ? 'Select PDF' : 'Change PDF: ${_selectedFile!.path.split('/').last}'),
                  ),
                  if (_selectedFile != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('Selected: ${_selectedFile!.path.split('/').last}', style: const TextStyle(fontSize: 12, color: Colors.green)),
                    ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting ? const CircularProgressIndicator(color: Colors.white) : const Text('Upload Material'),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}
