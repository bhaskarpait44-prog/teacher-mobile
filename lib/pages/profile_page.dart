import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../providers/auth_provider.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _isLoading = true;
  Map<String, dynamic>? _profile;
  String? _errorMessage;

  // Contact Info Editing
  bool _isEditingContact = false;
  final _phoneController = TextEditingController();
  final _emergencyController = TextEditingController();
  final _addressController = TextEditingController();

  // Password Changing
  final _currentPassController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();
  bool _showCurrentPass = false;
  bool _showNewPass = false;
  bool _showConfirmPass = false;

  // Correction Request
  String? _correctionField;
  final _requestedValueController = TextEditingController();
  final _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emergencyController.dispose();
    _addressController.dispose();
    _currentPassController.dispose();
    _newPassController.dispose();
    _confirmPassController.dispose();
    _requestedValueController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _fetchProfile() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/teacher/profile'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _profile = data['data'];
            _phoneController.text = _profile?['phone'] ?? '';
            _emergencyController.text = _profile?['emergency_contact'] ?? '';
            _addressController.text = _profile?['address'] ?? '';
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to load profile';
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

  Future<void> _updateContact() async {
    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      final response = await http.patch(
        Uri.parse('${ApiConstants.baseUrl}/teacher/profile/contact'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'phone': _phoneController.text.trim(),
          'emergency_contact': _emergencyController.text.trim(),
          'address': _addressController.text.trim(),
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Contact info updated'), backgroundColor: Colors.green));
          setState(() => _isEditingContact = false);
          _fetchProfile();
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _changePassword() async {
    if (_currentPassController.text.isEmpty || _newPassController.text.isEmpty || _confirmPassController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all password fields')));
      return;
    }
    if (_newPassController.text == _currentPassController.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('New password must be different from current password')));
      return;
    }
    if (_newPassController.text != _confirmPassController.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }
    if (_newPassController.text.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('New password must be at least 8 characters')));
      return;
    }

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/teacher/profile/change-password'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'current_password': _currentPassController.text,
          'new_password': _newPassController.text,
          'confirm_password': _confirmPassController.text,
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password changed successfully'), backgroundColor: Colors.green));
          _currentPassController.clear();
          _newPassController.clear();
          _confirmPassController.clear();
        }
      } else {
        final data = jsonDecode(response.body);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Failed to change password')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _submitCorrection() async {
    if (_correctionField == null || _requestedValueController.text.isEmpty || _reasonController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final token = authProvider.token;
      
      String currentValue = 'N/A';
      if (_correctionField == 'name') currentValue = _profile?['name'] ?? 'N/A';
      else if (_correctionField == 'employee_id') currentValue = _profile?['employee_id'] ?? 'N/A';
      else if (_correctionField == 'dob') currentValue = _profile?['dob'] ?? 'N/A';
      else if (_correctionField == 'gender') currentValue = _profile?['gender'] ?? 'N/A';

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/teacher/profile/correction-request'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'field': _correctionField,
          'current_value': currentValue,
          'requested_value': _requestedValueController.text.trim(),
          'reason': _reasonController.text.trim(),
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Correction request submitted'), backgroundColor: Colors.green));
          _requestedValueController.clear();
          _reasonController.clear();
          setState(() => _correctionField = null);
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorWidget()
              : RefreshIndicator(
                  onRefresh: _fetchProfile,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        _buildProfileHeader(),
                        const SizedBox(height: 32),
                        _buildContactInfo(),
                        const SizedBox(height: 32),
                        _buildAccountInfo(),
                        const SizedBox(height: 32),
                        _buildChangePassword(),
                        const SizedBox(height: 32),
                        _buildCorrectionRequest(),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
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
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchProfile,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final name = _profile?['name'] ?? 'Teacher';
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: colorScheme.primary,
              child: Text(name.isNotEmpty ? name[0] : 'T', style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 16),
            Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(_profile?['designation'] ?? 'Designation', style: TextStyle(color: colorScheme.onSurfaceVariant)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildHeaderBadge(Icons.badge_outlined, _profile?['employee_id'] ?? 'ID'),
                const SizedBox(width: 16),
                _buildHeaderBadge(Icons.business_outlined, _profile?['department'] ?? 'Dept'),
              ],
            ),
            const SizedBox(height: 8),
            Text('Joined on ${formatDate(_profile?['joining_date'])}', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBadge(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildContactInfo() {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Contact Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            IconButton(
              icon: Icon(_isEditingContact ? Icons.close : Icons.edit_outlined, color: colorScheme.primary),
              onPressed: () => setState(() => _isEditingContact = !_isEditingContact),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (_isEditingContact) ...[
          _buildEditField(_phoneController, 'Phone Number', Icons.phone_outlined),
          const SizedBox(height: 12),
          _buildEditField(_emergencyController, 'Emergency Contact', Icons.contact_emergency_outlined),
          const SizedBox(height: 12),
          _buildEditField(_addressController, 'Address', Icons.location_on_outlined, maxLines: 2),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _updateContact,
            style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            child: const Text('Save Contact Info'),
          ),
        ] else ...[
          _buildInfoRow(Icons.phone_outlined, 'Phone', _profile?['phone']),
          _buildInfoRow(Icons.contact_emergency_outlined, 'Emergency', _profile?['emergency_contact']),
          _buildInfoRow(Icons.location_on_outlined, 'Address', _profile?['address']),
        ],
      ],
    );
  }

  Widget _buildEditField(TextEditingController controller, String label, IconData icon, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String? value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 20, color: colorScheme.primary),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
              Text(value ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccountInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Account Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _buildInfoRow(Icons.email_outlined, 'Email', _profile?['email']),
        _buildInfoRow(Icons.admin_panel_settings_outlined, 'Role', 'Teacher'),
      ],
    );
  }

  Widget _buildChangePassword() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Change Password', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        _buildPasswordField(_currentPassController, 'Current Password', _showCurrentPass, (v) => setState(() => _showCurrentPass = v)),
        const SizedBox(height: 12),
        _buildPasswordField(_newPassController, 'New Password', _showNewPass, (v) => setState(() => _showNewPass = v)),
        const SizedBox(height: 12),
        _buildPasswordField(_confirmPassController, 'Confirm New Password', _showConfirmPass, (v) => setState(() => _showConfirmPass = v)),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _changePassword,
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
          child: const Text('Update Password'),
        ),
      ],
    );
  }

  Widget _buildPasswordField(TextEditingController controller, String label, bool show, Function(bool) onToggle) {
    return TextField(
      controller: controller,
      obscureText: !show,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_outline),
        suffixIcon: IconButton(
          icon: Icon(show ? Icons.visibility_off : Icons.visibility),
          onPressed: () => onToggle(!show),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildCorrectionRequest() {
    final colorScheme = Theme.of(context).colorScheme;
    
    String currentValue = 'Select a field to see current value';
    if (_correctionField == 'name') currentValue = _profile?['name'] ?? 'N/A';
    else if (_correctionField == 'employee_id') currentValue = _profile?['employee_id'] ?? 'N/A';
    else if (_correctionField == 'dob') currentValue = _profile?['dob'] ?? 'N/A';
    else if (_correctionField == 'gender') currentValue = _profile?['gender'] ?? 'N/A';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Identity Correction Request', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('For non-editable fields (Name, Employee ID, etc.)', style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _correctionField,
          decoration: InputDecoration(
            labelText: 'Select Field',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: const [
            DropdownMenuItem(value: 'name', child: Text('Full Name')),
            DropdownMenuItem(value: 'employee_id', child: Text('Employee ID')),
            DropdownMenuItem(value: 'dob', child: Text('Date of Birth')),
            DropdownMenuItem(value: 'gender', child: Text('Gender')),
          ],
          onChanged: (val) => setState(() => _correctionField = val),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: TextEditingController(text: currentValue),
          readOnly: true,
          decoration: InputDecoration(
            labelText: 'Current Value',
            filled: true,
            fillColor: colorScheme.surfaceVariant.withOpacity(0.3),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _requestedValueController,
          decoration: InputDecoration(
            labelText: 'Requested Value',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _reasonController,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: 'Reason for correction',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: _submitCorrection,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            side: BorderSide(color: colorScheme.primary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('Submit Request'),
        ),
      ],
    );
  }
}
