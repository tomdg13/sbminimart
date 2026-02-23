// lib/pages/user_management_page.dart
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class UserManagementPage extends StatefulWidget {
  final Map<String, dynamic> currentUser;

  const UserManagementPage({
    super.key,
    required this.currentUser,
  });

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> with TickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'all';
  late AnimationController _animationController;
  bool _showLogs = false;

  final List<Map<String, dynamic>> _users = [];

  // Activity logs
  final List<Map<String, dynamic>> _activityLogs = [];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _animationController.forward();
    _addLog('System', 'Page Loaded', 'User management page opened', 'info');
    _fetchUsers();
  }

  // Fetch users from API using ApiService (includes JWT token)
  Future<void> _fetchUsers() async {
    _addLog(
      'API Call - Fetch Users',
      'API Request',
      'Endpoint: GET ${ApiService.baseUrl}/users\nFetching all users from database',
      'info',
    );

    try {
      final users = await ApiService.getUsers();

      if (users.isNotEmpty) {
        setState(() {
          _users.clear();
          _users.addAll(users.map((user) => <String, dynamic>{
            'id': user['user_id'],
            'username': user['username'],
            'full_name': user['full_name'],
            'email': user['email'],
            'phone_number': user['phone_number'],
            'role': user['role'],
            'department': user['department'],
            'status': user['is_active'] == 1 ? 'active' : 'inactive',
            'account_locked': user['account_locked'],
            'failed_login_attempts': user['failed_login_attempts'],
            'last_login': user['last_login'] ?? 'Never',
            'created_date': user['created_date'],
            'created_by': user['created_by'],
          }).toList());
        });

        _addLog(
          'API Response',
          'API Success',
          'Fetched ${users.length} users successfully\n🔑 Token: ${ApiService.token != null ? "Present" : "None"}',
          'success',
        );
      } else {
        _addLog(
          'API Response',
          'API Warning',
          'No users returned - check token or server\n🔑 Token: ${ApiService.token != null ? "Present" : "None"}',
          'warning',
        );
      }
    } catch (e) {
      _addLog('API Exception', 'API Error', 'Exception occurred: $e', 'error');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }

  String _formatJsonForLog(Map<String, dynamic> json) {
    final buffer = StringBuffer();
    buffer.writeln('{');
    json.forEach((key, value) {
      if (key == 'password') {
        buffer.writeln('  "$key": "********",');
      } else {
        buffer.writeln('  "$key": ${value is String ? '"$value"' : value},');
      }
    });
    buffer.write('}');
    return buffer.toString();
  }

  void _addLog(String action, String category, String description, String type) {
    final log = {
      'timestamp': DateTime.now(),
      'user': widget.currentUser['username'],
      'action': action,
      'category': category,
      'description': description,
      'type': type,
    };

    setState(() {
      _activityLogs.insert(0, log);
    });

    print('[${_formatTime(log['timestamp'])}] ${log['user']} - ${log['action']}: ${log['description']}');
  }

  List<Map<String, dynamic>> get _filteredUsers {
    return _users.where((user) {
      final matchesSearch = _searchQuery.isEmpty ||
          user['full_name'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          user['username'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (user['email'] ?? '').toString().toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesFilter = _selectedFilter == 'all' ||
          user['status'] == _selectedFilter;

      return matchesSearch && matchesFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animationController,
      child: Container(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            _buildFiltersAndSearch(),
            const SizedBox(height: 24),
            _buildStatsCards(),
            const SizedBox(height: 24),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: _showLogs ? 2 : 1,
                    child: _buildUsersList(),
                  ),
                  if (_showLogs) ...[
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 1,
                      child: _buildActivityLog(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 4,
          height: 32,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFFF1F5F9), Color(0xFF94A3B8)],
                ).createShader(bounds),
                child: const Text(
                  'ຈັດການຜູ້ໃຊ້',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -1,
                  ),
                ),
              ),
              Text(
                'User Management',
                style: TextStyle(
                  fontSize: 14,
                  color: const Color(0xFF94A3B8).withOpacity(0.7),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        _buildLogToggleButton(),
        const SizedBox(width: 12),
        _buildAddUserButton(),
      ],
    );
  }

  Widget _buildLogToggleButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() => _showLogs = !_showLogs);
          _addLog(
            _showLogs ? 'Show Logs' : 'Hide Logs',
            'UI',
            'Activity log panel ${_showLogs ? "opened" : "closed"}',
            'info',
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            gradient: _showLogs
                ? const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)])
                : LinearGradient(colors: [
                    const Color(0xFF1E1B4B).withOpacity(0.5),
                    const Color(0xFF1A1F3A).withOpacity(0.3),
                  ]),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _showLogs
                  ? const Color(0xFF10B981).withOpacity(0.5)
                  : const Color(0xFF6366F1).withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                _showLogs ? Icons.receipt_long_rounded : Icons.receipt_long_outlined,
                color: _showLogs ? Colors.white : const Color(0xFF94A3B8),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _showLogs ? 'ເຊື່ອງ Log' : 'ສະແດງ Log',
                style: TextStyle(
                  color: _showLogs ? Colors.white : const Color(0xFF94A3B8),
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_activityLogs.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _showLogs
                        ? Colors.white.withOpacity(0.2)
                        : const Color(0xFF6366F1).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _activityLogs.length.toString(),
                    style: TextStyle(
                      color: _showLogs ? Colors.white : const Color(0xFF6366F1),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddUserButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _addLog('Button Click', 'UI', 'Add user button clicked', 'info');
          _showAddUserDialog();
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6366F1).withOpacity(0.4),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Row(
            children: [
              Icon(Icons.add_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text(
                'ເພີ່ມຜູ້ໃຊ້',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFiltersAndSearch() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                const Color(0xFF1E1B4B).withOpacity(0.5),
                const Color(0xFF1A1F3A).withOpacity(0.3),
              ]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.2), width: 1),
            ),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, color: Color(0xFF6366F1), size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                      if (value.isNotEmpty) {
                        _addLog('Search', 'Filter', 'Searching for: "$value"', 'info');
                      }
                    },
                    style: const TextStyle(color: Color(0xFFF1F5F9), fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'ຄົ້ນຫາຜູ້ໃຊ້...',
                      hintStyle: TextStyle(color: const Color(0xFF94A3B8).withOpacity(0.5), fontSize: 14),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        _buildFilterChip('all', 'ທັງໝົດ'),
        const SizedBox(width: 8),
        _buildFilterChip('active', 'ເປີດໃຊ້'),
        const SizedBox(width: 8),
        _buildFilterChip('inactive', 'ປິດໃຊ້'),
      ],
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() => _selectedFilter = value);
          _addLog('Filter Change', 'Filter', 'Filter changed to: $label', 'info');
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            gradient: isSelected
                ? const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)])
                : null,
            color: isSelected ? null : const Color(0xFF1E1B4B).withOpacity(0.3),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF6366F1).withOpacity(0.5)
                  : const Color(0xFF6366F1).withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF94A3B8),
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCards() {
    final totalUsers = _users.length;
    final activeUsers = _users.where((u) => u['status'] == 'active').length;
    final inactiveUsers = _users.where((u) => u['status'] == 'inactive').length;

    return Row(
      children: [
        Expanded(child: _buildStatCard('ທັງໝົດ', totalUsers.toString(), Icons.people_rounded, const Color(0xFF6366F1))),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard('ເປີດໃຊ້', activeUsers.toString(), Icons.check_circle_rounded, const Color(0xFF10B981))),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard('ປິດໃຊ້', inactiveUsers.toString(), Icons.cancel_rounded, const Color(0xFFEF4444))),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          const Color(0xFF1E1B4B).withOpacity(0.5),
          const Color(0xFF1A1F3A).withOpacity(0.3),
        ]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))],
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: const Color(0xFF94A3B8).withOpacity(0.8), fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              ShaderMask(
                shaderCallback: (bounds) => LinearGradient(colors: [color, color.withOpacity(0.7)]).createShader(bounds),
                child: Text(value, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActivityLog() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          const Color(0xFF1E1B4B).withOpacity(0.5),
          const Color(0xFF1A1F3A).withOpacity(0.3),
        ]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.2), width: 1),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                const Color(0xFF6366F1).withOpacity(0.1),
                const Color(0xFF8B5CF6).withOpacity(0.05),
              ]),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.history_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ບັນທຶກກິດຈະກຳ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFFF1F5F9))),
                      Text('Activity Log', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() => _activityLogs.clear());
                    _addLog('Clear Logs', 'System', 'Activity logs cleared', 'warning');
                  },
                  icon: const Icon(Icons.delete_sweep_rounded, color: Color(0xFFEF4444)),
                  tooltip: 'Clear logs',
                ),
              ],
            ),
          ),
          Expanded(
            child: _activityLogs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 48, color: const Color(0xFF94A3B8).withOpacity(0.3)),
                        const SizedBox(height: 12),
                        Text('ບໍ່ມີບັນທຶກກິດຈະກຳ', style: TextStyle(color: const Color(0xFF94A3B8).withOpacity(0.6), fontSize: 14)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _activityLogs.length,
                    itemBuilder: (context, index) => _buildLogEntry(_activityLogs[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogEntry(Map<String, dynamic> log) {
    Color typeColor;
    IconData typeIcon;

    switch (log['type']) {
      case 'success':
        typeColor = const Color(0xFF10B981);
        typeIcon = Icons.check_circle_rounded;
        break;
      case 'warning':
        typeColor = const Color(0xFFF59E0B);
        typeIcon = Icons.warning_rounded;
        break;
      case 'error':
        typeColor = const Color(0xFFEF4444);
        typeIcon = Icons.error_rounded;
        break;
      default:
        typeColor = const Color(0xFF6366F1);
        typeIcon = Icons.info_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          const Color(0xFF1E1B4B).withOpacity(0.3),
          const Color(0xFF1A1F3A).withOpacity(0.2),
        ]),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: typeColor.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(typeIcon, color: typeColor, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(log['action'], style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: typeColor))),
              Text(_formatTime(log['timestamp']), style: TextStyle(fontSize: 10, color: const Color(0xFF94A3B8).withOpacity(0.6), fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          Text(log['description'], style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.2), width: 1),
                ),
                child: Text(log['category'], style: const TextStyle(fontSize: 9, color: Color(0xFF6366F1), fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF94A3B8).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: const Color(0xFF94A3B8).withOpacity(0.2), width: 1),
                ),
                child: Text(log['user'], style: const TextStyle(fontSize: 9, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUsersList() {
    final users = _filteredUsers;

    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  const Color(0xFF6366F1).withOpacity(0.1),
                  const Color(0xFF8B5CF6).withOpacity(0.05),
                ]),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.person_search_rounded, size: 64, color: Color(0xFF6366F1)),
            ),
            const SizedBox(height: 16),
            const Text('ບໍ່ພົບຜູ້ໃຊ້', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFFF1F5F9))),
            const SizedBox(height: 8),
            Text('No users found matching your criteria', style: TextStyle(fontSize: 14, color: const Color(0xFF94A3B8).withOpacity(0.6))),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          const Color(0xFF1E1B4B).withOpacity(0.5),
          const Color(0xFF1A1F3A).withOpacity(0.3),
        ]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.2), width: 1),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                const Color(0xFF6366F1).withOpacity(0.1),
                const Color(0xFF8B5CF6).withOpacity(0.05),
              ]),
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(18), topRight: Radius.circular(18)),
            ),
            child: const Row(
              children: [
                Expanded(flex: 3, child: Text('ຜູ້ໃຊ້', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8), letterSpacing: 0.5))),
                Expanded(flex: 2, child: Text('ບົດບາດ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8), letterSpacing: 0.5))),
                Expanded(flex: 2, child: Text('ພະແນກ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8), letterSpacing: 0.5))),
                Expanded(flex: 2, child: Text('ສະຖານະ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF94A3B8), letterSpacing: 0.5))),
                SizedBox(width: 100),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: users.length,
              itemBuilder: (context, index) => _buildUserRow(users[index], index),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserRow(Map<String, dynamic> user, int index) {
    final isActive = user['status'] == 'active';

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 300 + (index * 50)),
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            const Color(0xFF1E1B4B).withOpacity(0.3),
            const Color(0xFF1A1F3A).withOpacity(0.2),
          ]),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.1), width: 1),
        ),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 2))],
                    ),
                    child: Center(
                      child: Text(
                        user['full_name'].toString().characters.first.toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user['full_name'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFFF1F5F9)), overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 2),
                        Text(user['email'] ?? '', style: TextStyle(fontSize: 12, color: const Color(0xFF94A3B8).withOpacity(0.7)), overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(flex: 2, child: Text(user['role'] ?? '', style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
            Expanded(flex: 2, child: Text(user['department'] ?? '', style: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: isActive
                      ? [const Color(0xFF10B981).withOpacity(0.2), const Color(0xFF059669).withOpacity(0.1)]
                      : [const Color(0xFFEF4444).withOpacity(0.2), const Color(0xFFDC2626).withOpacity(0.1)]),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isActive ? const Color(0xFF10B981).withOpacity(0.3) : const Color(0xFFEF4444).withOpacity(0.3), width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444), shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(isActive ? 'ເປີດໃຊ້' : 'ປິດໃຊ້', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444))),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: 100,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildActionButton(Icons.edit_rounded, const Color(0xFF6366F1), () {
                    _addLog('Edit User', 'User Action', 'Editing user: ${user['full_name']} (${user['username']})', 'info');
                    _showEditUserDialog(user);
                  }),
                  const SizedBox(width: 8),
                  _buildActionButton(Icons.delete_rounded, const Color(0xFFEF4444), () {
                    _addLog('Delete Attempt', 'User Action', 'Delete confirmation opened for: ${user['full_name']}', 'warning');
                    _showDeleteConfirmation(user);
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.2), width: 1),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
      ),
    );
  }

  // ==========================================
  // ADD USER DIALOG - using ApiService
  // ==========================================
  void _showAddUserDialog() {
    final formKey = GlobalKey<FormState>();
    final usernameController = TextEditingController();
    final fullNameController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    String selectedRole = 'Cashier';
    String selectedDepartment = 'Sales';
    bool isActive = true;
    bool obscurePassword = true;
    bool obscureConfirmPassword = true;

    final roles = ['Administrator', 'Manager', 'Cashier', 'Inventory Manager', 'Owner'];
    final departments = ['Management', 'Sales', 'Operations', 'Warehouse', 'IT'];

    _addLog('Dialog Open', 'UI', 'Add user dialog opened', 'info');

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 600,
            constraints: const BoxConstraints(maxHeight: 700),
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [
                const Color(0xFF1E1B4B).withOpacity(0.98),
                const Color(0xFF0F172A).withOpacity(0.98),
              ]),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3), width: 1),
              boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.2), blurRadius: 30, offset: const Offset(0, 10))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [const Color(0xFF6366F1).withOpacity(0.1), Colors.transparent]),
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.person_add_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ເພີ່ມຜູ້ໃຊ້ໃໝ່', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFFF1F5F9))),
                            Text('Add New User', style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          _addLog('Dialog Close', 'UI', 'Add user dialog closed (cancelled)', 'info');
                          Navigator.pop(context);
                        },
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                // Form
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFormField(label: 'ຊື່ຜູ້ໃຊ້ (Username)', controller: usernameController, icon: Icons.account_circle_rounded, validator: (v) => v == null || v.isEmpty ? 'ກະລຸນາປ້ອນຊື່ຜູ້ໃຊ້' : v.length < 4 ? 'ຊື່ຜູ້ໃຊ້ຕ້ອງມີຢ່າງໜ້ອຍ 4 ຕົວອັກສອນ' : null),
                          const SizedBox(height: 16),
                          _buildFormField(label: 'ຊື່ເຕັມ (Full Name)', controller: fullNameController, icon: Icons.person_rounded, validator: (v) => v == null || v.isEmpty ? 'ກະລຸນາປ້ອນຊື່ເຕັມ' : null),
                          const SizedBox(height: 16),
                          _buildFormField(label: 'ອີເມລ (Email)', controller: emailController, icon: Icons.email_rounded, keyboardType: TextInputType.emailAddress, validator: (v) => v == null || v.isEmpty ? 'ກະລຸນາປ້ອນອີເມລ' : !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v) ? 'ອີເມລບໍ່ຖືກຕ້ອງ' : null),
                          const SizedBox(height: 16),
                          _buildFormField(label: 'ເບີໂທ (Phone)', controller: phoneController, icon: Icons.phone_rounded, keyboardType: TextInputType.phone, validator: (v) => v == null || v.isEmpty ? 'ກະລຸນາປ້ອນເບີໂທ' : null),
                          const SizedBox(height: 16),
                          _buildDropdownField('ບົດບາດ (Role)', selectedRole, roles, (v) { setDialogState(() => selectedRole = v!); }),
                          const SizedBox(height: 16),
                          _buildDropdownField('ພະແນກ (Department)', selectedDepartment, departments, (v) { setDialogState(() => selectedDepartment = v!); }),
                          const SizedBox(height: 16),
                          _buildPasswordField('ລະຫັດຜ່ານ (Password)', passwordController, obscurePassword, () { setDialogState(() => obscurePassword = !obscurePassword); }, (v) => v == null || v.isEmpty ? 'ກະລຸນາປ້ອນລະຫັດຜ່ານ' : v.length < 6 ? 'ລະຫັດຜ່ານຕ້ອງມີຢ່າງໜ້ອຍ 6 ຕົວອັກສອນ' : null),
                          const SizedBox(height: 16),
                          _buildPasswordField('ຢືນຢັນລະຫັດຜ່ານ (Confirm Password)', confirmPasswordController, obscureConfirmPassword, () { setDialogState(() => obscureConfirmPassword = !obscureConfirmPassword); }, (v) => v == null || v.isEmpty ? 'ກະລຸນາຢືນຢັນລະຫັດຜ່ານ' : v != passwordController.text ? 'ລະຫັດຜ່ານບໍ່ກົງກັນ' : null),
                          const SizedBox(height: 16),
                          _buildStatusToggle(isActive, (v) { setDialogState(() => isActive = v); }),
                        ],
                      ),
                    ),
                  ),
                ),
                // Footer
                _buildDialogFooter(
                  onCancel: () {
                    _addLog('Dialog Close', 'UI', 'Add user dialog cancelled', 'info');
                    Navigator.pop(context);
                  },
                  onSave: () async {
                    if (formKey.currentState!.validate()) {
                      final newUser = {
                        'username': usernameController.text,
                        'full_name': fullNameController.text,
                        'email': emailController.text,
                        'phone_number': phoneController.text,
                        'password': passwordController.text,
                        'role': selectedRole,
                        'department': selectedDepartment,
                        'is_active': isActive ? 1 : 0,
                      };

                      _addLog('API Call - Create User', 'API Request', 'Endpoint: POST ${ApiService.baseUrl}/users\nBody: ${_formatJsonForLog(newUser)}', 'info');

                      try {
                        final response = await ApiService.createUser(newUser);

                        if (response['responseCode'] == '00') {
                          _addLog('API Response', 'API Success', 'User created: ${fullNameController.text}', 'success');
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ເພີ່ມຜູ້ໃຊ້ ${fullNameController.text} ສຳເລັດ'), backgroundColor: const Color(0xFF10B981)));
                          _fetchUsers();
                        } else {
                          _addLog('API Response', 'API Error', 'Code: ${response['responseCode']}\nMessage: ${response['message']}', 'error');
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response['message'] ?? 'ເກີດຂໍ້ຜິດພາດ'), backgroundColor: const Color(0xFFEF4444)));
                        }
                      } catch (e) {
                        _addLog('API Exception', 'API Error', 'Exception: $e', 'error');
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ເກີດຂໍ້ຜິດພາດໃນການເຊື່ອມຕໍ່'), backgroundColor: Color(0xFFEF4444)));
                      }
                    }
                  },
                  saveLabel: 'ບັນທຶກ',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // EDIT USER DIALOG - using ApiService
  // ==========================================
  void _showEditUserDialog(Map<String, dynamic> user) {
    _addLog('Dialog Open', 'UI', 'Edit user dialog opened for: ${user['full_name']}', 'info');

    final formKey = GlobalKey<FormState>();
    final usernameController = TextEditingController(text: user['username']);
    final fullNameController = TextEditingController(text: user['full_name']);
    final emailController = TextEditingController(text: user['email']);
    final phoneController = TextEditingController(text: user['phone_number']);
    final passwordController = TextEditingController();
    String selectedRole = user['role'];
    String selectedDepartment = user['department'];
    bool isActive = user['status'] == 'active';
    bool obscurePassword = true;
    bool changePassword = false;

    final roles = ['Owner', 'Manager', 'Cashier', 'Stock', 'Sale', 'Administrator', 'Trainee', 'Support'];
    final departments = ['Management', 'Sales', 'Operations', 'Warehouse', 'IT', 'POS'];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 600,
            constraints: const BoxConstraints(maxHeight: 700),
            decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [
                const Color(0xFF1E1B4B).withOpacity(0.98),
                const Color(0xFF0F172A).withOpacity(0.98),
              ]),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.3), width: 1),
              boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withOpacity(0.2), blurRadius: 30, offset: const Offset(0, 10))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [const Color(0xFF6366F1).withOpacity(0.1), Colors.transparent]),
                    borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]), borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.edit_rounded, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ແກ້ໄຂຜູ້ໃຊ້: ${user['full_name']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFFF1F5F9))),
                            Text('Edit User', style: TextStyle(fontSize: 12, color: const Color(0xFF94A3B8).withOpacity(0.7))),
                          ],
                        ),
                      ),
                      IconButton(onPressed: () { _addLog('Dialog Close', 'UI', 'Edit user dialog cancelled', 'info'); Navigator.pop(context); }, icon: const Icon(Icons.close_rounded, color: Color(0xFF94A3B8))),
                    ],
                  ),
                ),
                // Form
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Form(
                      key: formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildFormField(label: 'ຊື່ຜູ້ໃຊ້ (Username)', controller: usernameController, icon: Icons.account_circle_rounded, enabled: false),
                          const SizedBox(height: 16),
                          _buildFormField(label: 'ຊື່ເຕັມ (Full Name)', controller: fullNameController, icon: Icons.person_rounded, validator: (v) => v == null || v.isEmpty ? 'ກະລຸນາປ້ອນຊື່ເຕັມ' : null),
                          const SizedBox(height: 16),
                          _buildFormField(label: 'ອີເມລ (Email)', controller: emailController, icon: Icons.email_rounded, keyboardType: TextInputType.emailAddress, validator: (v) => v == null || v.isEmpty ? 'ກະລຸນາປ້ອນອີເມລ' : !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v) ? 'ອີເມລບໍ່ຖືກຕ້ອງ' : null),
                          const SizedBox(height: 16),
                          _buildFormField(label: 'ເບີໂທ (Phone)', controller: phoneController, icon: Icons.phone_rounded, keyboardType: TextInputType.phone, validator: (v) => v == null || v.isEmpty ? 'ກະລຸນາປ້ອນເບີໂທ' : null),
                          const SizedBox(height: 16),
                          _buildDropdownField('ບົດບາດ (Role)', selectedRole, roles, (v) { setDialogState(() => selectedRole = v!); }),
                          const SizedBox(height: 16),
                          _buildDropdownField('ພະແນກ (Department)', selectedDepartment, departments, (v) { setDialogState(() => selectedDepartment = v!); }),
                          const SizedBox(height: 16),
                          // Change password checkbox
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [const Color(0xFF1E1B4B).withOpacity(0.5), const Color(0xFF1A1F3A).withOpacity(0.3)]),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.2), width: 1),
                            ),
                            child: Row(
                              children: [
                                Checkbox(value: changePassword, onChanged: (v) { setDialogState(() => changePassword = v ?? false); }, activeColor: const Color(0xFF6366F1)),
                                const SizedBox(width: 12),
                                const Expanded(child: Text('ປ່ຽນລະຫັດຜ່ານ (Change Password)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)))),
                              ],
                            ),
                          ),
                          if (changePassword) ...[
                            const SizedBox(height: 16),
                            _buildPasswordField('ລະຫັດຜ່ານໃໝ່ (New Password)', passwordController, obscurePassword, () { setDialogState(() => obscurePassword = !obscurePassword); }, (v) => changePassword && (v == null || v.isEmpty) ? 'ກະລຸນາປ້ອນລະຫັດຜ່ານໃໝ່' : changePassword && v!.length < 6 ? 'ລະຫັດຜ່ານຕ້ອງມີຢ່າງໜ້ອຍ 6 ຕົວອັກສອນ' : null),
                          ],
                          const SizedBox(height: 16),
                          _buildStatusToggle(isActive, (v) { setDialogState(() => isActive = v); }),
                        ],
                      ),
                    ),
                  ),
                ),
                // Footer
                _buildDialogFooter(
                  onCancel: () { _addLog('Dialog Close', 'UI', 'Edit user dialog cancelled', 'info'); Navigator.pop(context); },
                  onSave: () async {
                    if (formKey.currentState!.validate()) {
                      final updateData = <String, dynamic>{
                        'full_name': fullNameController.text,
                        'email': emailController.text,
                        'phone_number': phoneController.text,
                        'role': selectedRole,
                        'department': selectedDepartment,
                        'is_active': isActive ? 1 : 0,
                      };
                      if (changePassword && passwordController.text.isNotEmpty) {
                        updateData['password'] = passwordController.text;
                      }

                      _addLog('API Call - Update User', 'API Request', 'Endpoint: PUT ${ApiService.baseUrl}/users/${user['id']}\nBody: ${_formatJsonForLog(updateData)}', 'info');

                      try {
                        final response = await ApiService.updateUser(user['id'], updateData);

                        if (response['responseCode'] == '00') {
                          _addLog('API Response', 'API Success', 'User updated: ${fullNameController.text}', 'success');
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ອັບເດດ ${fullNameController.text} ສຳເລັດ'), backgroundColor: const Color(0xFF10B981)));
                          _fetchUsers();
                        } else {
                          _addLog('API Response', 'API Error', 'Code: ${response['responseCode']}\nMessage: ${response['message']}', 'error');
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response['message'] ?? 'ເກີດຂໍ້ຜິດພາດ'), backgroundColor: const Color(0xFFEF4444)));
                        }
                      } catch (e) {
                        _addLog('API Exception', 'API Error', 'Exception: $e', 'error');
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ເກີດຂໍ້ຜິດພາດໃນການເຊື່ອມຕໍ່'), backgroundColor: Color(0xFFEF4444)));
                      }
                    }
                  },
                  saveLabel: 'ບັນທຶກການປ່ຽນແປງ',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // DELETE CONFIRMATION - using ApiService
  // ==========================================
  void _showDeleteConfirmation(Map<String, dynamic> user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E1B4B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: const Color(0xFFEF4444).withOpacity(0.3), width: 1),
        ),
        title: const Text('ລຶບຜູ້ໃຊ້', style: TextStyle(color: Color(0xFFF1F5F9), fontWeight: FontWeight.w800)),
        content: Text('ທ່ານຕ້ອງການລຶບ ${user['full_name']} ແທ້ບໍ່?\n\nການລຶບຈະບໍ່ສາມາດຍົກເລີກໄດ້.', style: const TextStyle(color: Color(0xFF94A3B8))),
        actions: [
          TextButton(
            onPressed: () { _addLog('Dialog Close', 'UI', 'Delete confirmation cancelled', 'info'); Navigator.pop(context); },
            child: const Text('ຍົກເລີກ'),
          ),
          ElevatedButton(
            onPressed: () async {
              _addLog('API Call - Delete User', 'API Request', 'Endpoint: DELETE ${ApiService.baseUrl}/users/${user['id']}\nUser: ${user['full_name']}', 'warning');

              try {
                final response = await ApiService.deleteUser(user['id']);

                if (response['responseCode'] == '00') {
                  _addLog('API Response', 'API Success', 'User deleted: ${user['full_name']}', 'success');
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('ລຶບ ${user['full_name']} ສຳເລັດ'), backgroundColor: const Color(0xFF10B981)));
                  _fetchUsers();
                } else {
                  _addLog('API Response', 'API Error', 'Code: ${response['responseCode']}\nMessage: ${response['message']}', 'error');
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response['message'] ?? 'ເກີດຂໍ້ຜິດພາດ'), backgroundColor: const Color(0xFFEF4444)));
                }
              } catch (e) {
                _addLog('API Exception', 'API Error', 'Exception: $e', 'error');
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ເກີດຂໍ້ຜິດພາດໃນການເຊື່ອມຕໍ່'), backgroundColor: Color(0xFFEF4444)));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('ລຶບ'),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // REUSABLE FORM WIDGETS
  // ==========================================
  Widget _buildFormField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              const Color(0xFF1E1B4B).withOpacity(enabled ? 0.5 : 0.3),
              const Color(0xFF1A1F3A).withOpacity(enabled ? 0.3 : 0.2),
            ]),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF6366F1).withOpacity(enabled ? 0.2 : 0.1), width: 1),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            enabled: enabled,
            style: TextStyle(color: enabled ? const Color(0xFFF1F5F9) : const Color(0xFF64748B)),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              prefixIcon: Icon(icon, color: enabled ? const Color(0xFF6366F1) : const Color(0xFF475569)),
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [const Color(0xFF1E1B4B).withOpacity(0.5), const Color(0xFF1A1F3A).withOpacity(0.3)]),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.2), width: 1),
          ),
          child: DropdownButtonFormField<String>(
            value: value,
            dropdownColor: const Color(0xFF1E1B4B),
            decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
            style: const TextStyle(color: Color(0xFFF1F5F9), fontSize: 14),
            icon: const Icon(Icons.arrow_drop_down, color: Color(0xFF6366F1)),
            items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField(String label, TextEditingController controller, bool obscure, VoidCallback toggleObscure, String? Function(String?)? validator) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8))),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [const Color(0xFF1E1B4B).withOpacity(0.5), const Color(0xFF1A1F3A).withOpacity(0.3)]),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.2), width: 1),
          ),
          child: TextFormField(
            controller: controller,
            obscureText: obscure,
            style: const TextStyle(color: Color(0xFFF1F5F9)),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              prefixIcon: const Icon(Icons.lock_rounded, color: Color(0xFF6366F1)),
              suffixIcon: IconButton(
                icon: Icon(obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: const Color(0xFF64748B)),
                onPressed: toggleObscure,
              ),
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusToggle(bool isActive, ValueChanged<bool> onChanged) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [const Color(0xFF1E1B4B).withOpacity(0.5), const Color(0xFF1A1F3A).withOpacity(0.3)]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF6366F1).withOpacity(0.2), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.toggle_on_rounded, color: Color(0xFF6366F1)),
          const SizedBox(width: 12),
          const Expanded(child: Text('ສະຖານະບັນຊີ (Account Status)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF94A3B8)))),
          Switch(value: isActive, onChanged: onChanged, activeColor: const Color(0xFF10B981)),
          Text(isActive ? 'ເປີດໃຊ້' : 'ປິດໃຊ້', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: isActive ? const Color(0xFF10B981) : const Color(0xFFEF4444))),
        ],
      ),
    );
  }

  Widget _buildDialogFooter({required VoidCallback onCancel, required VoidCallback onSave, required String saveLabel}) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: const Color(0xFF6366F1).withOpacity(0.1), width: 1))),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: onCancel,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: const Color(0xFF6366F1).withOpacity(0.3), width: 1),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('ຍົກເລີກ', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton(
                onPressed: onSave,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(saveLabel, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}