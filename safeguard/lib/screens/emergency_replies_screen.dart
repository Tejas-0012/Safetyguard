import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/emergency_provider.dart';
import '../models/emergency_model.dart';

class EmergencyRepliesScreen extends StatefulWidget {
  final String emergencyId;
  final String emergencyTitle;

  const EmergencyRepliesScreen({
    super.key,
    required this.emergencyId,
    required this.emergencyTitle,
  });

  @override
  State<EmergencyRepliesScreen> createState() => _EmergencyRepliesScreenState();
}

class _EmergencyRepliesScreenState extends State<EmergencyRepliesScreen> {
  List<ReceiverReply> _replies = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReplies();
    // Poll every 5 seconds for new replies
    _startPolling();
  }

  void _startPolling() {
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        _loadReplies();
        _startPolling();
      }
    });
  }

  Future<void> _loadReplies() async {
    final provider = Provider.of<EmergencyProvider>(context, listen: false);
    final replies = await provider.getReplies(widget.emergencyId);

    if (mounted) {
      setState(() {
        _replies = replies;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Replies - ${widget.emergencyTitle}'),
        backgroundColor: Colors.red,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _replies.isEmpty
          ? _buildEmptyState()
          : _buildReplyList(),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No replies yet',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            'Your contacts will reply when they see your alert',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyList() {
    return RefreshIndicator(
      onRefresh: _loadReplies,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _replies.length,
        itemBuilder: (context, index) {
          final reply = _replies[index];
          return _buildReplyCard(reply);
        },
      ),
    );
  }

  Widget _buildReplyCard(ReceiverReply reply) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: Colors.blue.shade100,
              child: Text(
                (reply.contactName.isNotEmpty ? reply.contactName[0] : '?')
                    .toUpperCase(),
                style: const TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
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
                        reply.contactName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        _formatTime(reply.repliedAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(reply.message, style: const TextStyle(fontSize: 15)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime date) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
