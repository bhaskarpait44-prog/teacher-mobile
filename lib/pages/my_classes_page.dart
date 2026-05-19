import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/constants.dart';

class MyClassesPage extends StatefulWidget {
  const MyClassesPage({super.key});

  @override
  State<MyClassesPage> createState() => _MyClassesPageState();
}

class _MyClassesPageState extends State<MyClassesPage> {
  final _storage = const FlutterSecureStorage();
  bool _isLoading = true;
  List<dynamic> _classes = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchClasses();
  }

  Future<void> _fetchClasses() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await _storage.read(key: 'token');
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/teacher/my-classes'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _classes = data['data']['classes'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load classes';
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
      appBar: AppBar(title: const Text('My Classes')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : _buildClassGrid(),
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
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                    backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                    child: Icon(Icons.class_, color: Theme.of(context).primaryColor),
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
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
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

class _ClassOverviewPageState extends State<ClassOverviewPage> {
  final _storage = const FlutterSecureStorage();
  bool _isLoading = true;
  List<dynamic> _students = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchStudents();
  }

  Future<void> _fetchStudents() async {
    try {
      final token = await _storage.read(key: 'token');
      // Using /teacher/students?class_id=...&section_id=...
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/teacher/students?class_id=${widget.classId}&section_id=${widget.sectionId}'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _students = data['data']['students'] ?? [];
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.className)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _students.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final student = _students[index];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(student['first_name'][0]),
                      ),
                      title: Text('${student['first_name']} ${student['last_name']}'),
                      subtitle: Text('Roll: ${student['roll_number'] ?? 'N/A'}'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        // View student profile detail
                      },
                    );
                  },
                ),
    );
  }
}
