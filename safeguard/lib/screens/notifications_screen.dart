import 'package:flutter/material.dart';

import '../utils/app_colors.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Dummy data (replace with real data from MongoDB)
  final List<Map<String, dynamic>> _replies = [
    {
      'name': 'Tejas',
      'message': "I'm coming! Stay safe!",
      'time': DateTime.now().subtract(const Duration(minutes: 2)),
      'emergency': 'Your SOS on 12 Sep',
    },
    {
      'name': 'Venky',
      'message': "On my way. Call me if needed.",
      'time': DateTime.now().subtract(const Duration(minutes: 15)),
      'emergency': 'Your SOS on 12 Sep',
    },
  ];

  final List<Map<String, dynamic>> _history = [
    {
      'type': 'started',
      'time': DateTime.now().subtract(const Duration(minutes: 30)),
      'person': 'You',
      'duration': '2 min 15 sec',
    },
    {
      'type': 'ended',
      'time': DateTime.now().subtract(const Duration(minutes: 28)),
      'person': 'You',
      'duration': '2 min 15 sec',
    },
    {
      'type': 'started',
      'time': DateTime.now().subtract(const Duration(days: 1, hours: 3)),
      'person': 'Venky (your contact)',
      'duration': '5 min 42 sec',
    },
    {
      'type': 'ended',
      'time': DateTime.now().subtract(const Duration(days: 1, hours: 3)),
      'person': 'Venky (your contact)',
      'duration': '5 min 42 sec',
    },
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.card,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textLight,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          tabs: const [
            Tab(
              text: 'Replies',
              icon: Icon(Icons.chat_bubble_outline, size: 20),
            ),
            Tab(text: 'History', icon: Icon(Icons.history, size: 20)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildRepliesTab(), _buildHistoryTab()],
      ),
    );
  }

  // ============ REPLIES TAB ============
  Widget _buildRepliesTab() {
    if (_replies.isEmpty) {
      return _buildEmptyState(
        Icons.chat_bubble_outline,
        'No replies yet',
        'Your contacts will reply when they see your alert',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _replies.length,
      itemBuilder: (context, index) {
        final reply = _replies[index];
        return _buildReplyCard(reply);
      },
    );
  }

  Widget _buildReplyCard(Map<String, dynamic> reply) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppColors.radiusLarge),
        boxShadow: AppColors.softShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: AppColors.tealGradient,
              borderRadius: BorderRadius.circular(AppColors.radiusMedium),
            ),
            child: Center(
              child: Text(
                (reply['name'] as String)[0].toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      reply['name'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.textDark,
                      ),
                    ),
                    Text(
                      _formatTime(reply['time']),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  reply['emergency'],
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textLight,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(AppColors.radiusMedium),
                  ),
                  child: Text(
                    reply['message'],
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textDark,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============ HISTORY TAB ============
  Widget _buildHistoryTab() {
    if (_history.isEmpty) {
      return _buildEmptyState(
        Icons.history,
        'No history yet',
        'Your emergency history will appear here',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _history.length,
      itemBuilder: (context, index) {
        final item = _history[index];
        return _buildHistoryCard(item);
      },
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> item) {
    final isStart = item['type'] == 'started';
    final color = isStart ? AppColors.danger : AppColors.success;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(AppColors.radiusLarge),
        boxShadow: AppColors.softShadow,
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppColors.radiusMedium),
            ),
            child: Icon(
              isStart ? Icons.warning_amber_rounded : Icons.check_circle,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isStart ? 'Emergency Started' : 'Emergency Ended',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: color,
                      ),
                    ),
                    Text(
                      _formatFullTime(item['time']),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  item['person'],
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textMedium,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (item['duration'] != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.timer_outlined,
                        size: 14,
                        color: AppColors.textLight,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Duration: ${item['duration']}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============ HELPERS ============
  Widget _buildEmptyState(IconData icon, String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 50, color: AppColors.primary),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.textLight),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  String _formatFullTime(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }
}
