import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';
import '../providers/notice_provider.dart';

class NoticePage extends StatefulWidget {
  const NoticePage({super.key});

  @override
  State<NoticePage> createState() => _NoticePageState();
}

class _NoticePageState extends State<NoticePage> {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchNotices,
          ),
        ],
      ),
      body: Consumer<NoticeProvider>(
        builder: (context, noticeProvider, child) {
          if (noticeProvider.isLoading && noticeProvider.notices.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (noticeProvider.notices.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No notices found',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _fetchNotices(),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: noticeProvider.notices.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final notice = noticeProvider.notices[index];
                return _NoticeCard(notice: notice);
              },
            ),
          );
        },
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final dynamic notice;

  const _NoticeCard({required this.notice});

  @override
  Widget build(BuildContext context) {
    final isRead = notice['is_read'] == true;
    final priority = notice['priority']?.toString().toLowerCase() ?? 'normal';
    final date = DateTime.tryParse(notice['created_at'] ?? '') ?? DateTime.now();
    final formattedDate = DateFormat('MMM dd, yyyy • hh:mm a').format(date);

    Color priorityColor;
    switch (priority) {
      case 'urgent':
        priorityColor = Colors.red;
        break;
      case 'info':
        priorityColor = Colors.blue;
        break;
      default:
        priorityColor = Colors.green;
    }

    return Card(
      elevation: isRead ? 0 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isRead ? Colors.grey[300]! : Colors.transparent,
          width: 1,
        ),
      ),
      color: isRead ? Colors.grey[50] : Colors.white,
      child: InkWell(
        onTap: () => _showNoticeDetails(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: priorityColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      priority.toUpperCase(),
                      style: TextStyle(
                        color: priorityColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (!isRead)
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.blue,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                notice['title'] ?? 'No Title',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                  color: isRead ? Colors.grey[700] : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                notice['body'] ?? '',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'By: ${notice['posted_by_name'] ?? 'Admin'}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                  Text(
                    formattedDate,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNoticeDetails(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final noticeProvider = Provider.of<NoticeProvider>(context, listen: false);
    
    if (notice['is_read'] == false && authProvider.token != null) {
      noticeProvider.markAsRead(authProvider.token!, notice['id'].toString());
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
                    color: Colors.grey[300],
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
                style: TextStyle(color: Colors.grey[600]),
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
                    // Logic to open/download attachment
                  },
                  icon: const Icon(Icons.attach_file),
                  label: const Text('View Attachment'),
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
}
