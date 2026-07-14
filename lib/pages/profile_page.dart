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
  final _currentValueController = TextEditingController();
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
    _currentValueController.dispose();
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
            final profileData = _profile?['profile'];
            _phoneController.text = profileData?['phone'] ?? '';
            _emergencyController.text = profileData?['emergency_contact'] ?? '';
            _addressController.text = profileData?['address'] ?? '';
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
      if (_correctionField == 'name') {
        currentValue = _profile?['name'] ?? 'N/A';
      } else if (_correctionField == 'employee_id') {
        currentValue = _profile?['employee_id'] ?? 'N/A';
      } else if (_correctionField == 'dob') {
        currentValue = _profile?['dob'] ?? 'N/A';
      } else if (_correctionField == 'gender') {
        currentValue = _profile?['gender'] ?? 'N/A';
      }

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/teacher/profile/correction-request'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'field_name': _correctionField,
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

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Provider.of<AuthProvider>(context, listen: false).logout(context);
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorWidget()
              : CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    _buildSliverAppBar(),
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                        child: Column(
                          children: [
                            _buildStatsSection(),
                            const SizedBox(height: 24),
                            _buildSectionContainer(
                              title: 'Personal Details',
                              icon: Icons.person_outline_rounded,
                              child: Column(
                                children: [
                                  _buildInfoItem('Full Name', _profile?['profile']?['name']),
                                  _buildInfoItem('Employee ID', _profile?['profile']?['employee_id']),
                                  _buildInfoItem('Gender', _profile?['profile']?['gender']),
                                  _buildInfoItem('Date of Birth', formatDate(_profile?['profile']?['dob'])),
                                  _buildInfoItem('Joining Date', formatDate(_profile?['profile']?['joining_date'])),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildSectionContainer(
                              title: 'Contact Information',
                              icon: Icons.contact_page_outlined,
                              action: IconButton(
                                icon: Icon(_isEditingContact ? Icons.close : Icons.edit_outlined, 
                                  size: 20, color: colorScheme.primary),
                                onPressed: () => setState(() => _isEditingContact = !_isEditingContact),
                              ),
                              child: _isEditingContact ? _buildEditContactForm() : Column(
                                children: [
                                  _buildInfoItem('Email Address', _profile?['profile']?['email']),
                                  _buildInfoItem('Phone Number', _profile?['profile']?['phone']),
                                  _buildInfoItem('Emergency Contact', _profile?['profile']?['emergency_contact']),
                                  _buildInfoItem('Address', _profile?['profile']?['address']),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildSectionContainer(
                              title: 'Academic Background',
                              icon: Icons.school_outlined,
                              child: Column(
                                children: [
                                  _buildInfoItem('Qualification', _profile?['profile']?['highest_qualification']),
                                  _buildInfoItem('Specialization', _profile?['profile']?['specialization']),
                                  _buildInfoItem('University', _profile?['profile']?['university_name']),
                                  _buildInfoItem('Experience', '${_profile?['profile']?['years_of_experience'] ?? 0} Years'),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            _buildSectionContainer(
                              title: 'Security',
                              icon: Icons.security_rounded,
                              child: _buildChangePassword(),
                            ),
                            const SizedBox(height: 20),
                            _buildSectionContainer(
                              title: 'Correction Requests',
                              icon: Icons.history_edu_rounded,
                              child: Column(
                                children: [
                                  _buildCorrectionRequest(),
                                  const SizedBox(height: 16),
                                  _buildCorrectionHistory(),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),
                            SizedBox(
                              width: double.infinity,
                              child: TextButton.icon(
                                onPressed: _showLogoutConfirmation,
                                icon: const Icon(Icons.logout_rounded, color: Colors.red),
                                label: const Text('Sign Out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  backgroundColor: Colors.red.withValues(alpha: 0.1),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                              ),
                            ),
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildSliverAppBar() {
    final profileData = _profile?['profile'];
    final name = profileData?['name'] ?? 'Teacher';
    final colorScheme = Theme.of(context).colorScheme;

    return SliverAppBar(
      expandedHeight: 280,
      pinned: true,
      stretch: true,
      elevation: 0,
      backgroundColor: colorScheme.primary,
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                colorScheme.primary,
                colorScheme.primaryContainer,
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: colorScheme.secondaryContainer,
                  child: Text(
                    getInitials(name),
                    style: TextStyle(
                      fontSize: 36, 
                      color: colorScheme.onSecondaryContainer, 
                      fontWeight: FontWeight.w800
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 24, 
                  fontWeight: FontWeight.bold, 
                  color: Colors.white
                ),
              ),
              const SizedBox(height: 4),
              Text(
                profileData?['designation'] ?? 'Department Teacher',
                style: TextStyle(
                  fontSize: 16, 
                  color: Colors.white.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w500
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  profileData?['department'] ?? 'General',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionContainer({required String title, required IconData icon, required Widget child, Widget? action}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 20, color: colorScheme.primary),
                    const SizedBox(width: 12),
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
                if (action != null) action,
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(String label, String? value) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13, 
                color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                fontWeight: FontWeight.w500
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value ?? 'N/A',
              style: const TextStyle(
                fontSize: 14, 
                fontWeight: FontWeight.w600
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    final stats = _profile?['performance_summary'];
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Attendance', 
            '${stats?['attendance_marking_rate']?['on_time_rate'] ?? 0}%', 
            Icons.speed_rounded, 
            Colors.blue
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Marks Entry', 
            '${stats?['marks_entry_completion_rate']?['total'] ?? 0}', 
            Icons.task_alt_rounded, 
            Colors.green
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.8), fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildEditContactForm() {
    return Column(
      children: [
        _buildModernTextField(_phoneController, 'Phone Number', Icons.phone_rounded),
        const SizedBox(height: 12),
        _buildModernTextField(_emergencyController, 'Emergency Contact', Icons.emergency_rounded),
        const SizedBox(height: 12),
        _buildModernTextField(_addressController, 'Residential Address', Icons.location_on_rounded, maxLines: 2),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _updateContact,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: const Text('Update Contact Info', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildModernTextField(TextEditingController controller, String label, IconData icon, {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }

  Widget _buildChangePassword() {
    return Column(
      children: [
        _buildModernPasswordField(_currentPassController, 'Current Password', _showCurrentPass, (v) => setState(() => _showCurrentPass = v)),
        const SizedBox(height: 12),
        _buildModernPasswordField(_newPassController, 'New Password', _showNewPass, (v) => setState(() => _showNewPass = v)),
        const SizedBox(height: 12),
        _buildModernPasswordField(_confirmPassController, 'Confirm New Password', _showConfirmPass, (v) => setState(() => _showConfirmPass = v)),
        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: _changePassword,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: const Text('Update Password', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildModernPasswordField(TextEditingController controller, String label, bool show, Function(bool) onToggle) {
    return TextField(
      controller: controller,
      obscureText: !show,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(Icons.lock_rounded, size: 20),
        suffixIcon: IconButton(
          icon: Icon(show ? Icons.visibility_off : Icons.visibility, size: 20),
          onPressed: () => onToggle(!show),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      ),
    );
  }

  Widget _buildCorrectionRequest() {
    final colorScheme = Theme.of(context).colorScheme;
    final profileData = _profile?['profile'];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'For locked fields like Name or DOB, please submit a correction request to the administrator.',
          style: TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _correctionField,
          decoration: InputDecoration(
            labelText: 'Select Field to Correct',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
          ),
          items: const [
            DropdownMenuItem(value: 'name', child: Text('Full Name')),
            DropdownMenuItem(value: 'employee_id', child: Text('Employee ID')),
            DropdownMenuItem(value: 'dob', child: Text('Date of Birth')),
            DropdownMenuItem(value: 'gender', child: Text('Gender')),
          ],
          onChanged: (val) => setState(() {
            _correctionField = val;
            if (val == 'name') {
              _currentValueController.text = profileData?['name'] ?? 'N/A';
            } else if (val == 'employee_id') {
              _currentValueController.text = profileData?['employee_id'] ?? 'N/A';
            } else if (val == 'dob') {
              final dob = formatDate(profileData?['dob']);
              _currentValueController.text = dob.isEmpty ? 'N/A' : dob;
            } else if (val == 'gender') {
              _currentValueController.text = profileData?['gender'] ?? 'N/A';
            }
          }),
        ),
        if (_correctionField != null) ...[
          const SizedBox(height: 12),
          _buildModernTextField(_currentValueController, 'Current Value', Icons.info_outline_rounded),
          const SizedBox(height: 12),
          _buildModernTextField(_requestedValueController, 'Correct Value', Icons.edit_note_rounded),
          const SizedBox(height: 12),
          _buildModernTextField(_reasonController, 'Reason for Correction', Icons.chat_bubble_outline_rounded, maxLines: 2),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: _submitCorrection,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: colorScheme.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Submit Correction Request', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCorrectionHistory() {
    final requests = _profile?['correction_requests'] as List?;
    if (requests == null || requests.isEmpty) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Divider(height: 32),
        const Text('Recent Requests', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...requests.take(3).map((req) {
          final status = req['status']?.toString().toLowerCase();
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        req['field_name'].toString().replaceAll('_', ' ').toUpperCase(),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'To: ${req['requested_value']}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(status),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStatusChip(String? status) {
    final color = getStatusColor(status, context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status?.toUpperCase() ?? 'PENDING',
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline_rounded, size: 64, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 16),
          Text(_errorMessage!, style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: _fetchProfile, child: const Text('Retry')),
        ],
      ),
    );
  }
}
