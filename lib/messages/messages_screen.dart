import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;

  static const Color purple = Color(0xFF6C3CE9);
  static const Color lightPurple = Color(0xFFF0EAFF);
  static const Color background = Color(0xFFF9F7FC);
  static const Color darkText = Color(0xFF29263A);
  static const Color greyText = Color(0xFF777383);
  static const Color borderColor = Color(0xFFEAE5F5);
  static const Color green = Color(0xFF22A06B);

  final TextEditingController _searchController = TextEditingController();

  List<MessageContact> _contacts = [];
  List<MessageContact> _filteredContacts = [];

  String _selectedCategory = 'All';
  bool _isLoading = true;
  String? _errorMessage;

  String? _supportProviderId;
  String? _supportProviderName;
  String? _supportProviderRole;

  RealtimeChannel? _messagesChannel;

  @override
  void initState() {
    super.initState();

    _searchController.addListener(_filterContacts);

    _loadMessages();

    _subscribeToMessages();
  }

  @override
  void dispose() {
    _searchController.dispose();

    if (_messagesChannel != null) {
      _supabase.removeChannel(_messagesChannel!);
    }

    super.dispose();
  }

  // ============================================================
  // CURRENT USER
  // ============================================================

  User? get _currentUser => _supabase.auth.currentUser;

  // ============================================================
  // LOAD SUPPORT PROVIDER
  // ============================================================

  Future<void> _loadSupportProvider() async {
    try {
      final response = await _supabase
          .from('healthcare_providers')
          .select()
          .eq('role', 'Customer Support')
          .eq('is_available', true)
          .limit(1);

      if (response.isNotEmpty) {
        final provider = response.first;

        _supportProviderId = provider['id']?.toString();
        _supportProviderName =
            provider['full_name']?.toString() ?? 'MedNova Support';
        _supportProviderRole =
            provider['role']?.toString() ?? 'Customer Support';
      } else {
        _supportProviderId = null;
        _supportProviderName = 'MedNova Support';
        _supportProviderRole = 'Customer Support';
      }
    } catch (e) {
      debugPrint('Error loading support provider: $e');

      _supportProviderName = 'MedNova Support';
      _supportProviderRole = 'Customer Support';
    }
  }

  // ============================================================
  // CHECK IF CURRENT USER IS A HEALTHCARE PROVIDER
  // ============================================================

  Future<bool> _isCurrentUserProvider() async {
    final user = _currentUser;

    if (user == null) return false;

    try {
      final response = await _supabase
          .from('healthcare_providers')
          .select('id, full_name, role')
          .eq('id', user.id)
          .maybeSingle();

      return response != null;
    } catch (e) {
      debugPrint('Provider check error: $e');
      return false;
    }
  }

  // ============================================================
  // LOAD ALL MESSAGES
  // ============================================================

  Future<void> _loadMessages() async {
    final user = _currentUser;

    if (user == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Please log in to view your messages.';
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      await _loadSupportProvider();

      final isProvider = await _isCurrentUserProvider();

      final response = await _supabase
          .from('messages')
          .select()
          .or('sender_id.eq.${user.id},recipient_id.eq.${user.id}')
          .order('created_at', ascending: false);

      final List<dynamic> messages = response;

      final Map<String, Map<String, dynamic>> conversations = {};

      for (final rawMessage in messages) {
        final message = Map<String, dynamic>.from(rawMessage);

        final String senderId = message['sender_id'].toString();

        final String? recipientId =
        message['recipient_id']?.toString();

        String? otherUserId;

        if (senderId == user.id) {
          otherUserId = recipientId;
        } else {
          otherUserId = senderId;
        }

        if (otherUserId == null || otherUserId.isEmpty) {
          continue;
        }

        if (!conversations.containsKey(otherUserId)) {
          conversations[otherUserId] = message;
        }
      }

      final List<MessageContact> loadedContacts = [];

      // ==========================================================
      // PROVIDER SIDE
      // ==========================================================

      if (isProvider) {
        for (final entry in conversations.entries) {
          final String patientId = entry.key;
          final Map<String, dynamic> message = entry.value;

          String patientName = 'MedNova Patient';

          try {
            final profile = await _supabase
                .from('profiles')
                .select('full_name')
                .eq('id', patientId)
                .maybeSingle();

            if (profile != null) {
              final name = profile['full_name']?.toString().trim();

              if (name != null && name.isNotEmpty) {
                patientName = name;
              }
            }
          } catch (e) {
            debugPrint(
              'Could not load patient profile $patientId: $e',
            );
          }

          final unreadCount = messages.where((m) {
            final senderId = m['sender_id']?.toString();
            final recipientId = m['recipient_id']?.toString();
            final isRead = m['is_read'] == true;

            return senderId == patientId &&
                recipientId == user.id &&
                !isRead;
          }).length;

          loadedContacts.add(
            MessageContact(
              conversationUserId: patientId,
              providerId: null,
              name: patientName,
              role: 'Patient',
              message: message['message']?.toString() ?? '',
              time: _formatMessageTime(message['created_at']),
              unread: unreadCount,
              icon: Icons.person_outline,
              avatarColor: purple,
              online: false,
            ),
          );
        }
      }

      // ==========================================================
      // PATIENT SIDE
      // ==========================================================

      else {
        if (_supportProviderId != null) {
          final supportMessages = messages.where((message) {
            final senderId = message['sender_id']?.toString();
            final recipientId = message['recipient_id']?.toString();

            return senderId == _supportProviderId ||
                recipientId == _supportProviderId;
          }).toList();

          if (supportMessages.isNotEmpty) {
            final latestMessage =
            Map<String, dynamic>.from(supportMessages.first);

            final unreadCount = supportMessages.where((message) {
              final senderId = message['sender_id']?.toString();
              final recipientId = message['recipient_id']?.toString();
              final isRead = message['is_read'] == true;

              return senderId == _supportProviderId &&
                  recipientId == user.id &&
                  !isRead;
            }).length;

            loadedContacts.add(
              MessageContact(
                conversationUserId: _supportProviderId!,
                providerId: _supportProviderId,
                name: _supportProviderName ?? 'MedNova Support',
                role: _supportProviderRole ?? 'Customer Support',
                message: latestMessage['message']?.toString() ?? '',
                time: _formatMessageTime(
                  latestMessage['created_at'],
                ),
                unread: unreadCount,
                icon: Icons.support_agent_outlined,
                avatarColor: purple,
                online: true,
              ),
            );
          } else {
            loadedContacts.add(
              MessageContact(
                conversationUserId: _supportProviderId!,
                providerId: _supportProviderId,
                name: _supportProviderName ?? 'MedNova Support',
                role: _supportProviderRole ?? 'Customer Support',
                message: 'Start a conversation with MedNova Support',
                time: '',
                unread: 0,
                icon: Icons.support_agent_outlined,
                avatarColor: purple,
                online: true,
              ),
            );
          }
        }
      }

      loadedContacts.sort((a, b) {
        if (a.unread > 0 && b.unread == 0) {
          return -1;
        }

        if (a.unread == 0 && b.unread > 0) {
          return 1;
        }

        return 0;
      });

      if (!mounted) return;

      setState(() {
        _contacts = loadedContacts;
        _filteredContacts = List.from(loadedContacts);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading messages: $e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage = 'Unable to load messages. Please try again.';
      });
    }
  }

  // ============================================================
  // REALTIME
  // ============================================================

  void _subscribeToMessages() {
    final user = _currentUser;

    if (user == null) return;

    _messagesChannel = _supabase
        .channel('mednova_messages_${user.id}')
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      callback: (payload) {
        final record = payload.newRecord;

        final senderId = record['sender_id']?.toString();
        final recipientId = record['recipient_id']?.toString();

        if (senderId == user.id || recipientId == user.id) {
          _loadMessages();
        }
      },
    )
        .subscribe();
  }

  // ============================================================
  // SEARCH
  // ============================================================

  void _filterContacts() {
    final query = _searchController.text.trim().toLowerCase();

    List<MessageContact> filtered = List.from(_contacts);

    if (_selectedCategory != 'All') {
      filtered = filtered.where((contact) {
        final role = contact.role.toLowerCase();

        if (_selectedCategory == 'Doctors') {
          return role.contains('doctor');
        }

        if (_selectedCategory == 'Pharmacists') {
          return role.contains('pharmac');
        }

        if (_selectedCategory == 'Support') {
          return role.contains('support');
        }

        if (_selectedCategory == 'System') {
          return role.contains('system');
        }

        return true;
      }).toList();
    }

    if (query.isNotEmpty) {
      filtered = filtered.where((contact) {
        return contact.name.toLowerCase().contains(query) ||
            contact.role.toLowerCase().contains(query) ||
            contact.message.toLowerCase().contains(query);
      }).toList();
    }

    if (!mounted) return;

    setState(() {
      _filteredContacts = filtered;
    });
  }

  // ============================================================
  // TIME FORMAT
  // ============================================================

  String _formatMessageTime(dynamic value) {
    if (value == null) return '';

    try {
      final dateTime = DateTime.parse(value.toString()).toLocal();
      final now = DateTime.now();

      final difference = now.difference(dateTime);

      if (difference.inMinutes < 1) {
        return 'Now';
      }

      if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m';
      }

      if (difference.inHours < 24) {
        return '${difference.inHours}h';
      }

      if (difference.inDays == 1) {
        return 'Yesterday';
      }

      if (difference.inDays < 7) {
        return '${difference.inDays}d';
      }

      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } catch (_) {
      return '';
    }
  }

  // ============================================================
  // CATEGORY
  // ============================================================

  void _selectCategory(String category) {
    setState(() {
      _selectedCategory = category;
    });

    _filterContacts();
  }

  // ============================================================
  // OPEN CONVERSATION
  // ============================================================

  Future<void> _openConversation(MessageContact contact) async {
    final user = _currentUser;

    if (user == null) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      useSafeArea: true,
      builder: (context) {
        return MessageConversationSheet(
          currentUserId: user.id,
          contact: contact,
        );
      },
    );

    await _loadMessages();
  }

  // ============================================================
  // START NEW CONVERSATION
  // ============================================================

  Future<void> _startNewConversation() async {
    if (_supportProviderId == null) {
      await _loadSupportProvider();
    }

    if (_supportProviderId == null) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'MedNova Support is currently unavailable.',
          ),
        ),
      );

      return;
    }

    final contact = MessageContact(
      conversationUserId: _supportProviderId!,
      providerId: _supportProviderId,
      name: _supportProviderName ?? 'MedNova Support',
      role: _supportProviderRole ?? 'Customer Support',
      message: 'Start a conversation with MedNova Support',
      time: '',
      unread: 0,
      icon: Icons.support_agent_outlined,
      avatarColor: purple,
      online: true,
    );

    await _openConversation(contact);
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadMessages,
                child: _buildBody(),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Messages',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: darkText,
                  ),
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: borderColor,
                  ),
                ),
                child: const Icon(
                  Icons.notifications_none_rounded,
                  color: darkText,
                  size: 23,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          const Text(
            'Stay connected with your healthcare team and get the support you need.',
            style: TextStyle(
              fontSize: 14,
              height: 1.45,
              color: greyText,
            ),
          ),
          const SizedBox(height: 18),
          _buildSearchBar(),
          const SizedBox(height: 14),
          _buildCategoryFilters(),
        ],
      ),
    );
  }

  // ============================================================
  // SEARCH BAR
  // ============================================================

  Widget _buildSearchBar() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: borderColor,
        ),
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(
          color: darkText,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: 'Search messages...',
          hintStyle: const TextStyle(
            color: greyText,
            fontSize: 14,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: greyText,
            size: 21,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
            onPressed: () {
              _searchController.clear();
            },
            icon: const Icon(
              Icons.close_rounded,
              size: 19,
              color: greyText,
            ),
          )
              : null,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            vertical: 14,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CATEGORY FILTERS
  // ============================================================

  Widget _buildCategoryFilters() {
    const categories = [
      'All',
      'Doctors',
      'Pharmacists',
      'Support',
      'System',
    ];

    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, __) =>
        const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          final selected = category == _selectedCategory;

          return GestureDetector(
            onTap: () => _selectCategory(category),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 15,
              ),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? purple : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: selected ? purple : borderColor,
                ),
              ),
              child: Text(
                category,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight:
                  selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? Colors.white : greyText,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: purple,
        ),
      );
    }

    if (_errorMessage != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.45,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: greyText,
                      size: 46,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: greyText,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadMessages,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: purple,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }

    if (_filteredContacts.isEmpty) {
      return _buildEmptyState();
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 110),
      children: [
        ..._filteredContacts.map(
              (contact) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildMessageCard(contact),
          ),
        ),
        const SizedBox(height: 8),
        _buildNewConversationButton(),
      ],
    );
  }

  // ============================================================
  // MESSAGE CARD
  // ============================================================

  Widget _buildMessageCard(MessageContact contact) {
    return GestureDetector(
      onTap: () => _openConversation(contact),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: borderColor,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAvatar(contact),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          contact.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: darkText,
                          ),
                        ),
                      ),
                      if (contact.time.isNotEmpty)
                        Text(
                          contact.time,
                          style: const TextStyle(
                            fontSize: 11,
                            color: greyText,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          contact.role,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: purple,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      if (contact.online) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: green,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Online',
                          style: TextStyle(
                            fontSize: 10,
                            color: green,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          contact.message,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.35,
                            color: contact.unread > 0
                                ? darkText
                                : greyText,
                            fontWeight: contact.unread > 0
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (contact.unread > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 22,
                          height: 22,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: purple,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            contact.unread > 9
                                ? '9+'
                                : contact.unread.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // AVATAR
  // ============================================================

  Widget _buildAvatar(MessageContact contact) {
    return Stack(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: lightPurple,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            contact.icon,
            color: contact.avatarColor,
            size: 25,
          ),
        ),
        if (contact.online)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 13,
              height: 13,
              decoration: BoxDecoration(
                color: green,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ============================================================
  // NEW CONVERSATION
  // ============================================================

  Widget _buildNewConversationButton() {
    return GestureDetector(
      onTap: _startNewConversation,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        decoration: BoxDecoration(
          color: lightPurple,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: const Color(0xFFE0D5FF),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: purple,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.add_comment_outlined,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Start New Conversation',
                    style: TextStyle(
                      color: darkText,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Chat with MedNova Support',
                    style: TextStyle(
                      color: greyText,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: purple,
              size: 15,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY STATE
  // ============================================================

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 35, 20, 110),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.30,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: lightPurple,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Icon(
                  Icons.chat_bubble_outline_rounded,
                  color: purple,
                  size: 34,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'No messages yet',
                style: TextStyle(
                  color: darkText,
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 7),
              const Text(
                'Start a conversation with MedNova Support\nwhen you need assistance.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: greyText,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _startNewConversation,
                icon: const Icon(
                  Icons.chat_outlined,
                  size: 18,
                ),
                label: const Text('Message Support'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: purple,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BOTTOM NAVIGATION
  // ============================================================

  Widget _buildBottomNavigation() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: borderColor,
            width: 0.8,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 70,
          child: Row(
            children: [
              Expanded(
                child: _buildNavItem(
                  icon: Icons.home_outlined,
                  label: 'Home',
                  onTap: () => context.go('/home'),
                ),
              ),
              Expanded(
                child: _buildNavItem(
                  icon: Icons.calendar_today_outlined,
                  label: 'Schedule',
                  onTap: () => context.go('/calendar'),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => context.go('/medications/add'),
                  child: Center(
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: purple,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: Colors.white,
                        size: 27,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _buildNavItem(
                  icon: Icons.chat_bubble_rounded,
                  label: 'Messages',
                  selected: true,
                  onTap: () {},
                ),
              ),
              Expanded(
                child: _buildNavItem(
                  icon: Icons.person_outline_rounded,
                  label: 'Profile',
                  onTap: () => context.go('/profile'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool selected = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 22,
            color: selected ? purple : greyText,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight:
              selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? purple : greyText,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// MESSAGE CONTACT MODEL
// ============================================================================

class MessageContact {
  final String conversationUserId;
  final String? providerId;
  final String name;
  final String role;
  final String message;
  final String time;
  final int unread;
  final IconData icon;
  final Color avatarColor;
  final bool online;

  const MessageContact({
    required this.conversationUserId,
    required this.providerId,
    required this.name,
    required this.role,
    required this.message,
    required this.time,
    required this.unread,
    required this.icon,
    required this.avatarColor,
    required this.online,
  });
}

// ============================================================================
// CONVERSATION SHEET
// ============================================================================

class MessageConversationSheet extends StatefulWidget {
  final String currentUserId;
  final MessageContact contact;

  const MessageConversationSheet({
    super.key,
    required this.currentUserId,
    required this.contact,
  });

  @override
  State<MessageConversationSheet> createState() =>
      _MessageConversationSheetState();
}

class _MessageConversationSheetState
    extends State<MessageConversationSheet> {
  final SupabaseClient _supabase = Supabase.instance.client;

  static const Color purple = Color(0xFF6C3CE9);
  static const Color lightPurple = Color(0xFFF0EAFF);
  static const Color background = Color(0xFFF9F7FC);
  static const Color darkText = Color(0xFF29263A);
  static const Color greyText = Color(0xFF777383);
  static const Color borderColor = Color(0xFFEAE5F5);

  final TextEditingController _messageController =
  TextEditingController();

  final ScrollController _scrollController =
  ScrollController();

  List<Map<String, dynamic>> _messages = [];

  bool _isLoading = true;
  bool _isSending = false;

  RealtimeChannel? _conversationChannel;

  @override
  void initState() {
    super.initState();

    _loadConversation();
    _subscribeToConversation();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();

    if (_conversationChannel != null) {
      _supabase.removeChannel(_conversationChannel!);
    }

    super.dispose();
  }

  // ============================================================
  // LOAD CONVERSATION
  // ============================================================

  Future<void> _loadConversation() async {
    try {
      final response = await _supabase
          .from('messages')
          .select()
          .or(
        'and(sender_id.eq.${widget.currentUserId},recipient_id.eq.${widget.contact.conversationUserId}),'
            'and(sender_id.eq.${widget.contact.conversationUserId},recipient_id.eq.${widget.currentUserId})',
      )
          .order('created_at', ascending: true);

      final loadedMessages = <Map<String, dynamic>>[];

      for (final item in response) {
        loadedMessages.add(
          Map<String, dynamic>.from(item),
        );
      }

      if (!mounted) return;

      setState(() {
        _messages = loadedMessages;
        _isLoading = false;
      });

      await _markMessagesAsRead();

      _scrollToBottom();
    } catch (e) {
      debugPrint('Error loading conversation: $e');

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  // ============================================================
  // MARK AS READ
  // ============================================================

  Future<void> _markMessagesAsRead() async {
    try {
      await _supabase
          .from('messages')
          .update({'is_read': true})
          .eq('sender_id', widget.contact.conversationUserId)
          .eq('recipient_id', widget.currentUserId)
          .eq('is_read', false);
    } catch (e) {
      debugPrint('Could not mark messages as read: $e');
    }
  }

  // ============================================================
  // REALTIME
  // ============================================================

  void _subscribeToConversation() {
    _conversationChannel = _supabase
        .channel(
      'conversation_${widget.currentUserId}_${widget.contact.conversationUserId}',
    )
        .onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'messages',
      callback: (payload) {
        final record = payload.newRecord;

        final senderId = record['sender_id']?.toString();
        final recipientId = record['recipient_id']?.toString();

        final isThisConversation =
            (senderId == widget.currentUserId &&
                recipientId ==
                    widget.contact.conversationUserId) ||
                (senderId ==
                    widget.contact.conversationUserId &&
                    recipientId == widget.currentUserId);

        if (isThisConversation) {
          _loadConversation();
        }
      },
    )
        .subscribe();
  }

  // ============================================================
  // SEND MESSAGE
  // ============================================================

  Future<void> _sendMessage() async {
    final user = _supabase.auth.currentUser;

    if (user == null) return;

    final message = _messageController.text.trim();

    if (message.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      await _supabase.from('messages').insert({
        'sender_id': user.id,
        'recipient_id': widget.contact.conversationUserId,
        'contact_name': widget.contact.name,
        'contact_role': widget.contact.role,
        'message': message,
        'is_read': false,
      });

      _messageController.clear();

      await _loadConversation();
    } catch (e) {
      debugPrint('Error sending message: $e');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not send message. Please try again.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  // ============================================================
  // SCROLL
  // ============================================================

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  // ============================================================
  // MESSAGE TIME
  // ============================================================

  String _formatTime(dynamic value) {
    if (value == null) return '';

    try {
      final dateTime = DateTime.parse(value.toString()).toLocal();

      final hour = dateTime.hour == 0
          ? 12
          : dateTime.hour > 12
          ? dateTime.hour - 12
          : dateTime.hour;

      final minute = dateTime.minute.toString().padLeft(2, '0');

      final period = dateTime.hour >= 12 ? 'PM' : 'AM';

      return '$hour:$minute $period';
    } catch (_) {
      return '';
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    /*
      IMPORTANT:
      isScrollControlled + viewInsets + Flexible are used here
      specifically to prevent the "Bottom overflowed by 3.x pixels"
      error when the keyboard appears.
    */

    final keyboardHeight =
        MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      padding: EdgeInsets.only(
        bottom: keyboardHeight,
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: MediaQuery.of(context).size.height *
              0.88,
          decoration: const BoxDecoration(
            color: background,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: Column(
            children: [
              _buildConversationHeader(),
              Expanded(
                child: _buildMessagesList(),
              ),
              _buildMessageInput(),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // CONVERSATION HEADER
  // ============================================================

  Widget _buildConversationHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        20,
        12,
        16,
        14,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(28),
        ),
        border: Border(
          bottom: BorderSide(
            color: borderColor,
          ),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: borderColor,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 13),
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: darkText,
                    size: 17,
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: lightPurple,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  widget.contact.icon,
                  color: purple,
                  size: 22,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                  CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.contact.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: darkText,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          widget.contact.role,
                          style: const TextStyle(
                            color: greyText,
                            fontSize: 11.5,
                          ),
                        ),
                        if (widget.contact.online) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 6,
                            height: 6,
                            decoration:
                            const BoxDecoration(
                              color: Color(0xFF22A06B),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Text(
                            'Online',
                            style: TextStyle(
                              color: Color(0xFF22A06B),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.more_vert_rounded,
                color: greyText,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MESSAGES LIST
  // ============================================================

  Widget _buildMessagesList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          color: purple,
        ),
      );
    }

    if (_messages.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                color: purple,
                size: 40,
              ),
              SizedBox(height: 12),
              Text(
                'Start your conversation',
                style: TextStyle(
                  color: darkText,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Send a message to get started.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: greyText,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      keyboardDismissBehavior:
      ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.fromLTRB(
        18,
        20,
        18,
        12,
      ),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];

        final senderId =
        message['sender_id']?.toString();

        final isMine =
            senderId == widget.currentUserId;

        return _buildMessageBubble(
          message,
          isMine,
        );
      },
    );
  }

  // ============================================================
  // MESSAGE BUBBLE
  // ============================================================

  Widget _buildMessageBubble(
      Map<String, dynamic> message,
      bool isMine,
      ) {
    final text = message['message']?.toString() ?? '';

    final time = _formatTime(
      message['created_at'],
    );

    return Align(
      alignment:
      isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.76,
        ),
        margin: const EdgeInsets.only(
          bottom: 10,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 11,
        ),
        decoration: BoxDecoration(
          color: isMine ? purple : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(17),
            topRight: const Radius.circular(17),
            bottomLeft: Radius.circular(
              isMine ? 17 : 4,
            ),
            bottomRight: Radius.circular(
              isMine ? 4 : 17,
            ),
          ),
          border: isMine
              ? null
              : Border.all(
            color: borderColor,
          ),
        ),
        child: Column(
          crossAxisAlignment: isMine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: TextStyle(
                color: isMine ? Colors.white : darkText,
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              time,
              style: TextStyle(
                color: isMine
                    ? Colors.white70
                    : greyText,
                fontSize: 9.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // MESSAGE INPUT
  // ============================================================

  Widget _buildMessageInput() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        14,
        9,
        14,
        9 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: borderColor,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Container(
              constraints: const BoxConstraints(
                minHeight: 46,
                maxHeight: 110,
              ),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(17),
                border: Border.all(
                  color: borderColor,
                ),
              ),
              child: TextField(
                controller: _messageController,
                minLines: 1,
                maxLines: 4,
                textCapitalization:
                TextCapitalization.sentences,
                keyboardType: TextInputType.multiline,
                style: const TextStyle(
                  color: darkText,
                  fontSize: 13.5,
                ),
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(
                    color: greyText,
                    fontSize: 13,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 15,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (_) {
                  if (!_isSending) {
                    _sendMessage();
                  }
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _isSending ? null : _sendMessage,
            child: AnimatedContainer(
              duration: const Duration(
                milliseconds: 150,
              ),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: _isSending
                    ? purple.withOpacity(0.55)
                    : purple,
                shape: BoxShape.circle,
              ),
              child: _isSending
                  ? const Padding(
                padding: EdgeInsets.all(13),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}