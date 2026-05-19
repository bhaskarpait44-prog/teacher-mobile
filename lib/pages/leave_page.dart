import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../utils/constants.dart';

class LeavePage extends StatefulWidget {
  const LeavePage({super.key});

  @override
  State<LeavePage> createState() => _LeavePageState();
}

class _LeavePageState extends State<LeavePage> {
  final _storage = const FlutterSecureStorage();
  bool _isLoading = true;
  List<dynamic> _leaves = [];
  Map<String, dynamic>? _balances;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchLeaveData();
  }

  Future<void> _fetchLeaveData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final token = await _storage.read(key: 'token');
      
      // Fetch Balance
      final balanceRes = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/teacher/leave/balance'),
        headers: {'Authorization': 'Bearer $token'},
      );
      
      // Fetch Applications
      final appsRes = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/teacher/leave/applications'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (balanceRes.statusCode == 200 && appsRes.statusCode == 200) {
        setState(() {
          _balances = jsonDecode(balanceRes.body)['data'];
          _leaves = jsonDecode(appsRes.body)['data']['applications'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Failed to load leave data';
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
      appBar: AppBar(title: const Text('Leave Management')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _fetchLeaveData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildBalanceSection(),
                    const SizedBox(height: 24),
                    const Text('My Applications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    _buildLeaveList(),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ApplyLeavePage()),
          ).then((_) => _fetchLeaveData());
        },
        label: const Text('Apply Leave'),
        icon: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBalanceSection() {
    if (_balances == null) return const SizedBox.shrink();
    final balances = _balances!['balances'] as List?;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Leave Balance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: balances?.length ?? 0,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final b = balances![index];
              return Container(
                width: 120,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).primaryColor.withOpacity(0.1)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${b['total_allowed'] - b['total_taken']}',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).primaryColor),
                    ),
                    Text(
                      b['leave_type'].toString().toUpperCase(),
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLeaveList() {
    if (_leaves.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Center(child: Text('No leave applications found.')),
        ),
      );
    }

    return Column(
      children: _leaves.map((leave) => _buildLeaveCard(leave)).toList(),
    );
  }

  Widget _buildLeaveCard(Map<String, dynamic> leave) {
    Color statusColor;
    switch (leave['status']) {
      case 'approved': statusColor = Colors.green; break;
      case 'rejected': statusColor = Colors.red; break;
      case 'pending': statusColor = Colors.orange; break;
      case 'cancelled': statusColor = Colors.grey; break;
      default: statusColor = Colors.blue;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(leave['leave_type'].toString().toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('${leave['start_date']} to ${leave['end_date']}\nReason: ${leave['reason']}'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Text(
            leave['status'].toString().toUpperCase(),
            style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
        isThreeLine: true,
      ),
    );
  }
}

class ApplyLeavePage extends StatefulWidget {
  const ApplyLeavePage({super.key});

  @override
  State<ApplyLeavePage> createState() => _ApplyLeavePageState();
}

class _ApplyLeavePageState extends State<ApplyLeavePage> {
  final _formKey = GlobalKey<FormState>();
  final _storage = const FlutterSecureStorage();
  String _leaveType = 'casual';
  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  DateTime _endDate = DateTime.now().add(const Duration(days: 1));
  String? _reason;
  bool _isSaving = false;

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _isSaving = true);

    try {
      final token = await _storage.read(key: 'token');
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/teacher/leave/apply'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'leave_type': _leaveType,
          'start_date': _startDate.toIso8601String().split('T')[0],
          'end_date': _endDate.toIso8601String().split('T')[0],
          'reason': _reason,
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Application submitted successfully')));
          Navigator.pop(context);
        }
      } else {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Failed to apply')));
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
      appBar: AppBar(title: const Text('Apply for Leave')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              DropdownButtonFormField<String>(
                value: _leaveType,
                decoration: const InputDecoration(labelText: 'Leave Type'),
                items: const [
                  DropdownMenuItem(value: 'casual', child: Text('Casual Leave')),
                  DropdownMenuItem(value: 'sick', child: Text('Sick Leave')),
                  DropdownMenuItem(value: 'earned', child: Text('Earned Leave')),
                  DropdownMenuItem(value: 'emergency', child: Text('Emergency Leave')),
                ],
                onChanged: (val) => setState(() => _leaveType = val!),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Start Date'),
                subtitle: Text(_startDate.toIso8601String().split('T')[0]),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _startDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setState(() => _startDate = picked);
                },
              ),
              ListTile(
                title: const Text('End Date'),
                subtitle: Text(_endDate.toIso8601String().split('T')[0]),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _endDate,
                    firstDate: _startDate,
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) setState(() => _endDate = picked);
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Reason', alignLabelWithHint: true),
                maxLines: 3,
                validator: (val) => val == null || val.isEmpty ? 'Please enter a reason' : null,
                onSaved: (val) => _reason = val,
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                child: _isSaving ? const CircularProgressIndicator() : const Text('Submit Application'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
