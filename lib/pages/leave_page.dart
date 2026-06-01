import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../providers/auth_provider.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class LeavePage extends StatefulWidget {
  const LeavePage({super.key});

  @override
  State<LeavePage> createState() => _LeavePageState();
}

class _LeavePageState extends State<LeavePage> {
  bool _isLoading = true;
  List<dynamic> _applications = [];
  List<dynamic> _balances = [];
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchLeaveData();
  }

  Future<void> _fetchLeaveData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      
      final balanceRes = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/teacher/leave/balance'),
        headers: {'Authorization': 'Bearer $token'},
      );
      
      final appsRes = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/teacher/leave/applications'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (balanceRes.statusCode == 200 && appsRes.statusCode == 200) {
        if (mounted) {
          setState(() {
            _balances = jsonDecode(balanceRes.body)['data']['balances'] ?? [];
            _applications = jsonDecode(appsRes.body)['data']['applications'] ?? [];
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to load leave data';
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

  Future<void> _cancelApplication(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Application'),
        content: const Text('Are you sure you want to cancel this leave application?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Yes, Cancel')),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final token = authProvider.token;
        final response = await http.patch(
          Uri.parse('${ApiConstants.baseUrl}/teacher/leave/$id/cancel'),
          headers: {'Authorization': 'Bearer $token'},
        );

        if (response.statusCode == 200) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Application cancelled'), backgroundColor: Colors.green));
            _fetchLeaveData();
          }
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Leave Management')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _fetchLeaveData,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _errorMessage != null
                  ? _buildErrorWidget()
                  : SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildBalanceSection(),
                          const SizedBox(height: 32),
                          const Text('My Applications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          _buildLeaveList(),
                        ],
                      ),
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
        icon: const Icon(Icons.add_rounded),
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
              onPressed: _fetchLeaveData,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceSection() {
    if (_balances.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Leave Balance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _balances.length,
            separatorBuilder: (context, index) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final b = _balances[index];
              final allowed = b['total_allowed'] ?? 0;
              final taken = b['total_taken'] ?? 0;
              final remaining = allowed - taken;
              
              Color borderColor = Colors.green;
              if (remaining == 0) borderColor = Colors.red;
              else if (remaining <= 5) borderColor = Colors.orange;

              return Container(
                width: 140,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: borderColor, width: 2),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$remaining',
                      style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                    ),
                    Text(
                      b['leave_type'].toString().toUpperCase(),
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text('$taken of $allowed used', style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
    if (_applications.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            children: [
              Icon(Icons.beach_access_outlined, size: 48, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 12),
              const Text('No applications found'),
            ],
          ),
        ),
      );
    }

    return Column(
      children: _applications.map((leave) => _buildLeaveCard(leave)).toList(),
    );
  }

  Widget _buildLeaveCard(Map<String, dynamic> leave) {
    final status = leave['status']?.toString().toLowerCase();
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(leave['leave_type'].toString().toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: getStatusColor(status, context).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status?.toUpperCase() ?? 'N/A',
                    style: TextStyle(color: getStatusColor(status, context), fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${formatDate(leave['from_date'])} to ${formatDate(leave['to_date'])}',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 4),
            Text('Reason: ${leave['reason']}', style: TextStyle(color: colorScheme.onSurfaceVariant)),
            if (status == 'rejected' && leave['remarks'] != null) ...[
              const SizedBox(height: 8),
              Text('Remarks: ${leave['remarks']}', style: TextStyle(color: colorScheme.error, fontSize: 12)),
            ],
            if (status == 'pending') ...[
              const Divider(),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _cancelApplication(leave['id']),
                  style: TextButton.styleFrom(foregroundColor: colorScheme.error),
                  child: const Text('Cancel Application'),
                ),
              ),
            ],
          ],
        ),
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
  String _leaveType = 'casual';
  DateTime _startDate = DateTime.now().add(const Duration(days: 1));
  DateTime _endDate = DateTime.now().add(const Duration(days: 1));
  final _reasonController = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  int get _daysCount {
    return _endDate.difference(_startDate).inDays + 1;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/teacher/leave/apply'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'leave_type': _leaveType,
          'from_date': _startDate.toIso8601String().split('T')[0],
          'to_date': _endDate.toIso8601String().split('T')[0],
          'reason': _reasonController.text.trim(),
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Application submitted successfully'), backgroundColor: Colors.green),
          );
          Navigator.pop(context);
        }
      } else {
        final data = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Failed to apply')));
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
    return Scaffold(
      appBar: AppBar(title: const Text('Apply for Leave')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  value: _leaveType,
                  decoration: const InputDecoration(labelText: 'Leave Type'),
                  items: const [
                    DropdownMenuItem(value: 'casual', child: Text('Casual Leave')),
                    DropdownMenuItem(value: 'sick', child: Text('Sick Leave')),
                    DropdownMenuItem(value: 'earned', child: Text('Earned Leave')),
                    DropdownMenuItem(value: 'emergency', child: Text('Emergency Leave')),
                    DropdownMenuItem(value: 'without_pay', child: Text('Leave Without Pay')),
                  ],
                  onChanged: (val) => setState(() => _leaveType = val!),
                ),
                const SizedBox(height: 24),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Start Date', style: TextStyle(fontSize: 12)),
                  subtitle: Text(formatDate(_startDate.toIso8601String()), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.calendar_today_rounded),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _startDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() {
                        _startDate = picked;
                        if (_endDate.isBefore(_startDate)) _endDate = _startDate;
                      });
                    }
                  },
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('End Date', style: TextStyle(fontSize: 12)),
                  subtitle: Text(formatDate(_endDate.toIso8601String()), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.calendar_today_rounded),
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
                const Divider(),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    'Total Days: $_daysCount',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  controller: _reasonController,
                  decoration: const InputDecoration(labelText: 'Reason', alignLabelWithHint: true),
                  maxLines: 3,
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Please enter a reason';
                    if (val.length < 10) return 'Reason must be at least 10 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('Submit Application'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
