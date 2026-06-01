import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/auth_provider.dart';
import '../providers/notice_provider.dart';
import '../utils/constants.dart';
import '../utils/file_helper.dart';
import 'create_notice_page.dart';

class NoticePage extends StatefulWidget {
  const NoticePage({super.key});

  @override
  State<NoticePage> createState() => _NoticePageState();
}

class _NoticePageState extends State<NoticePage> {
  String _filter = 'all'; // all, unread, read, recent

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchNotices();
    });
  }

  void _fetchNotices() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.token != null) {
      Provider.of<NoticeProvider>(context, listen: false).fetchNotices(authProvider.token!);
    }
  }

  List<dynamic> _applyFilter(List<dynamic> notices) {
    switch (_filter) {
      case 'unread':
        return notices.where((n) => n['is_read'] == false).toList();
      case 'read':
        return notices.where((n) => n['is_read'] == true).toList();
      case 'recent':
        final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
        return notices.where((n) {
          final date = DateTime.tryParse(n['created_at'] ?? '');
          return date != null && date.isAfter(sevenDaysAgo);
        }).toList();
      default:
        return notices;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notices'),
        actions: [
          Consumer<NoticeProvider>(
            builder: (context, provider, _) {
              return IconButton(
                icon: const Icon(Icons.done_all_rounded),
                tooltip: 'Mark all as read',
                onPressed: () {
                  final token = Provider.of<AuthProvider>(context, listen: false).token;
                  if (token != null) provider.markAllAsRead(token);
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchNotices,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterBar(),
          Expanded(
            child: Consumer<NoticeProvider>(
              builder: (context, noticeProvider, child) {
                if (noticeProvider.isLoading && noticeProvider.notices.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (noticeProvider.error != null && noticeProvider.notices.isEmpty) {
                  return _buildErrorView(noticeProvider.error!);
                }

                final filteredNotices = _applyFilter(noticeProvider.notices);

                if (filteredNotices.isEmpty) {
                  return _buildEmptyView();
                }

                return RefreshIndicator(
                  onRefresh: () async => _fetchNotices(),
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: filteredNotices.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final notice = filteredNotices[index];
                      return _NoticeCard(notice: notice);
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const CreateNoticePage()),
          );
          if (result == true) {
            _fetchNotices();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _filterChip('All', 'all'),
          _filterChip('Unread', 'unread'),
          _filterChip('Read', 'read'),
          _filterChip('Recent', 'recent'),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value) {
    final isSelected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) setState(() => _filter = value);
        },
      ),
    );
  }

  Widget _buildErrorView(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchNotices,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.notifications_off_outlined, size: 64, color: colorScheme.outline.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text(
            'No notices found for this filter.',
            style: TextStyle(fontSize: 16, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final dynamic notice;

  const _NoticeCard({required this.notice});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isRead = notice['is_read'] == true;
    final priority = notice['priority']?.toString().toLowerCase() ?? 'normal';
    final date = DateTime.tryParse(notice['created_at'] ?? '') ?? DateTime.now();
    final formattedDate = DateFormat('dd MMM').format(date);

    final color = _getTypeColor(priority);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showNoticeDetails(context),
        child: Container(
          decoration: BoxDecoration(
            border: !isRead 
              ? Border(left: BorderSide(color: color, width: 4))
              : null,
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      priority.toUpperCase(),
                      style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        formattedDate,
                        style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 12),
                      ),
                      if (notice['can_manage'] == true) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => _confirmDelete(context),
                          child: Icon(Icons.delete_outline, color: colorScheme.error, size: 18),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                notice['title'] ?? 'No Title',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: !isRead ? FontWeight.bold : FontWeight.w500,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                notice['body'] ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'By: ${notice['posted_by_name'] ?? 'Admin'}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type.toLowerCase()) {
      case 'academic':
      case 'normal': return Colors.green;
      case 'event':
      case 'info': return Colors.blue;
      case 'urgent':
      case 'warning': return Colors.red;
      case 'holiday': return Colors.orange;
      default: return Colors.grey;
    }
  }

  void _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Notice'),
        content: const Text('Are you sure you want to delete this notice?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final noticeProvider = Provider.of<NoticeProvider>(context, listen: false);
      if (authProvider.token != null) {
        final success = await noticeProvider.deleteNotice(authProvider.token!, notice['id'].toString());
        if (success && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Notice deleted')));
        }
      }
    }
  }

  void _showNoticeDetails(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final noticeProvider = Provider.of<NoticeProvider>(context, listen: false);
    
    if (notice['is_read'] == false && authProvider.token != null) {
      noticeProvider.markAsRead(
        authProvider.token!, 
        notice['id'].toString(),
        source: notice['source'] ?? 'unified',
      );
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                notice['title'] ?? 'No Title',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Posted on ${DateFormat('MMMM dd, yyyy').format(DateTime.tryParse(notice['created_at'] ?? '') ?? DateTime.now())}',
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                notice['body'] ?? '',
                style: const TextStyle(fontSize: 16, height: 1.5),
              ),
              const SizedBox(height: 32),
              if (notice['attachment_path'] != null)
                ElevatedButton.icon(
                  onPressed: () {
                    var url = notice['attachment_path'];
                    if (url != null) {
                      if (!url.startsWith('http')) {
                        url = '${ApiConstants.mediaUrl}/$url';
                      }
                      final fileName = url.split('/').last;
                      FileHelper.downloadAndOpenFile(context, url, fileName);
                    }
                  },
                  icon: const Icon(Icons.attach_file),
                  label: const Text('View Attachment (PDF)'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                'Posted by: ${notice['posted_by_name'] ?? 'Admin'}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openAttachment(BuildContext context, String path) async {
    final url = Uri.parse('${ApiConstants.mediaUrl}/$path');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not open attachment')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }
}
