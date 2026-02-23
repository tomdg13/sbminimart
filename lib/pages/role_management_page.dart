// lib/pages/role_management_page.dart
import 'package:flutter/material.dart';
import '../services/api_service.dart';

class RoleManagementPage extends StatefulWidget {
  final Map<String, dynamic> currentUser;

  const RoleManagementPage({
    super.key,
    required this.currentUser,
  });

  @override
  State<RoleManagementPage> createState() => _RoleManagementPageState();
}

class _RoleManagementPageState extends State<RoleManagementPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _roles = [];
  List<Map<String, dynamic>> _menus = [];
  Map<int, Map<String, bool>> _mappings = {}; // menu_id -> {can_view, can_create, can_edit, can_delete}
  int? _selectedRoleId;
  bool _isLoading = true;
  bool _isSavingMapping = false;
  bool _showLogs = false;
  
  // Activity logs
  final List<Map<String, dynamic>> _activityLogs = [];

  // Colors
  static const _bg = Color(0xFF0F172A);
  static const _surface = Color(0xFF1E293B);
  static const _surfaceLight = Color(0xFF334155);
  static const _accent = Color(0xFF3B82F6);
  static const _green = Color(0xFF10B981);
  static const _red = Color(0xFFEF4444);
  static const _amber = Color(0xFFF59E0B);
  static const _purple = Color(0xFF8B5CF6);
  static const _textPrimary = Color(0xFFF1F5F9);
  static const _textSecondary = Color(0xFF94A3B8);
  static const _border = Color(0xFF334155);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _addLog('System', 'Page Loaded', 'Role management page opened', 'info');
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // Format time helper
  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}';
  }

  // Add log entry
  void _addLog(String action, String category, String description, String type) {
    final log = {
      'timestamp': DateTime.now(),
      'user': widget.currentUser['username'] ?? 'unknown',
      'action': action,
      'category': category,
      'description': description,
      'type': type, // info, success, warning, error
    };
    
    setState(() {
      _activityLogs.insert(0, log);
    });
    
    // Print to console
    print('[${_formatTime(log['timestamp'])}] ${log['user']} - ${log['action']}: ${log['description']}');
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    _addLog(
      'API Call - Fetch Data',
      'API Request',
      'Endpoint: GET http://localhost:2026/api/roles\nEndpoint: GET http://localhost:2026/api/roles/menus/all\nFetching roles and menus',
      'info',
    );
    
    try {
      final results = await Future.wait([
        ApiService.getRoles(),
        ApiService.getMenus(),
      ]);
      setState(() {
        _roles = List<Map<String, dynamic>>.from(results[0]);
        _menus = List<Map<String, dynamic>>.from(results[1]);
        if (_roles.isNotEmpty && _selectedRoleId == null) {
          _selectedRoleId = _roles[0]['role_id'];
        }
        _isLoading = false;
      });
      
      _addLog(
        'API Response',
        'API Success',
        'Fetched ${_roles.length} roles and ${_menus.length} menus successfully',
        'success',
      );
      
      if (_selectedRoleId != null) {
        _loadMappings(_selectedRoleId!);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _addLog('API Exception', 'API Error', 'Exception occurred: $e', 'error');
      _snack('ໂຫລດຂໍ້ມູນບໍ່ສຳເລັດ | Failed to load data', isError: true);
    }
  }

  Future<void> _loadMappings(int roleId) async {
    final roleName = _roles.firstWhere((r) => r['role_id'] == roleId, orElse: () => {})['role_name'] ?? 'Unknown';
    
    _addLog(
      'API Call - Fetch Permissions',
      'API Request',
      'Endpoint: GET http://localhost:2026/api/roles/$roleId/menus\nFetching permissions for role: $roleName',
      'info',
    );
    
    try {
      final data = await ApiService.getRoleMenuMapping(roleId);
      final map = <int, Map<String, bool>>{};
      for (final item in data) {
        final menuId = item['menu_id'];
        if (menuId != null) {
          map[menuId] = {
            'can_view': item['can_view'] == 1 || item['can_view'] == true,
            'can_create': item['can_create'] == 1 || item['can_create'] == true,
            'can_edit': item['can_edit'] == 1 || item['can_edit'] == true,
            'can_delete': item['can_delete'] == 1 || item['can_delete'] == true,
          };
        }
      }
      setState(() => _mappings = map);
      
      _addLog(
        'API Response',
        'API Success',
        'Loaded permissions for ${map.length} menus for role: $roleName',
        'success',
      );
    } catch (e) {
      _addLog('API Exception', 'API Error', 'Failed to load permissions: $e', 'error');
      _snack('Failed to load permissions', isError: true);
    }
  }

  Future<void> _saveMappings() async {
    if (_selectedRoleId == null) return;
    setState(() => _isSavingMapping = true);

    final roleName = _roles.firstWhere((r) => r['role_id'] == _selectedRoleId, orElse: () => {})['role_name'] ?? 'Unknown';

    final mappingList = _mappings.entries.map((e) => {
          'menu_id': e.key,
          'can_view': (e.value['can_view'] ?? false) ? 1 : 0,
          'can_create': (e.value['can_create'] ?? false) ? 1 : 0,
          'can_edit': (e.value['can_edit'] ?? false) ? 1 : 0,
          'can_delete': (e.value['can_delete'] ?? false) ? 1 : 0,
        }).toList();

    _addLog(
      'API Call - Save Permissions',
      'API Request',
      'Endpoint: POST http://localhost:2026/api/roles/$_selectedRoleId/menus\nSaving ${mappingList.length} permission mappings for role: $roleName',
      'info',
    );

    final result = await ApiService.saveRoleMenuMapping(_selectedRoleId!, mappingList);
    setState(() => _isSavingMapping = false);

    if (result['responseCode'] == '00') {
      _addLog(
        'Save Permissions',
        'User Action',
        'Permissions saved successfully for role: $roleName (${mappingList.length} menus)',
        'success',
      );
      _addLog(
        'API Response',
        'API Success',
        'Response Code: ${result['responseCode']}',
        'success',
      );
      _snack('ບັນທຶກສິດສຳເລັດ | Permissions saved');
    } else {
      _addLog(
        'API Response',
        'API Error',
        'Failed to save permissions. Code: ${result['responseCode']}, Message: ${result['message']}',
        'error',
      );
      _snack(result['message'] ?? 'Failed', isError: true);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white, fontSize: 13)),
      backgroundColor: isError ? _red : _green,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    ));
  }

  // ==========================================
  // ROLE CRUD DIALOG
  // ==========================================
  void _showRoleDialog({Map<String, dynamic>? role}) {
    final isEdit = role != null;
    final nameCtrl = TextEditingController(text: role?['role_name'] ?? '');
    final descCtrl = TextEditingController(text: role?['role_description'] ?? '');
    bool isSaving = false;

    _addLog(
      'Dialog Open',
      'UI',
      isEdit ? 'Edit role dialog opened for: ${role['role_name']}' : 'Add role dialog opened',
      'info',
    );

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _purple.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isEdit ? Icons.edit_rounded : Icons.add_circle_outline_rounded,
                        color: _purple,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Text(
                      isEdit ? 'ແກ້ໄຂບົດບາດ | Edit Role' : 'ເພີ່ມບົດບາດ | Add Role',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _textPrimary),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () {
                        _addLog('Dialog Close', 'UI', '${isEdit ? "Edit" : "Add"} role dialog cancelled', 'info');
                        Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.close_rounded, color: _textSecondary, size: 20),
                      splashRadius: 18,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Role Name
                const Text('ຊື່ບົດບາດ | Role Name', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textSecondary)),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  style: const TextStyle(fontSize: 14, color: _textPrimary),
                  decoration: _inputDecor('e.g. Manager'),
                ),
                const SizedBox(height: 16),

                // Description
                const Text('ລາຍລະອຽດ | Description', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _textSecondary)),
                const SizedBox(height: 6),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 14, color: _textPrimary),
                  decoration: _inputDecor('Description...'),
                ),
                const SizedBox(height: 24),

                // Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () {
                        _addLog('Dialog Close', 'UI', '${isEdit ? "Edit" : "Add"} role dialog cancelled', 'info');
                        Navigator.pop(ctx);
                      },
                      child: const Text('ຍົກເລີກ', style: TextStyle(color: _textSecondary)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: isSaving
                          ? null
                          : () async {
                              if (nameCtrl.text.trim().isEmpty) {
                                _snack('ກະລຸນາປ້ອນຊື່ບົດບາດ | Role name required', isError: true);
                                return;
                              }
                              setDialogState(() => isSaving = true);

                              final body = {
                                'role_name': nameCtrl.text.trim(),
                                'role_description': descCtrl.text.trim(),
                              };

                              _addLog(
                                isEdit ? 'API Call - Update Role' : 'API Call - Create Role',
                                'API Request',
                                'Endpoint: ${isEdit ? "PUT" : "POST"} http://localhost:2026/api/roles${isEdit ? "/${role!['role_id']}" : ""}\nBody: $body',
                                'info',
                              );

                              Map<String, dynamic> result;
                              if (isEdit) {
                                result = await ApiService.updateRole(role!['role_id'], body);
                              } else {
                                result = await ApiService.createRole(body);
                              }

                              setDialogState(() => isSaving = false);

                              if (result['responseCode'] == '00') {
                                _addLog(
                                  isEdit ? 'Update Role' : 'Create Role',
                                  'User Action',
                                  '${isEdit ? "Updated" : "Created"} role: ${nameCtrl.text.trim()}',
                                  'success',
                                );
                                _addLog(
                                  'API Response',
                                  'API Success',
                                  'Response Code: ${result['responseCode']}',
                                  'success',
                                );
                                Navigator.pop(ctx);
                                _loadData();
                                _snack(isEdit ? 'ແກ້ໄຂສຳເລັດ | Role updated' : 'ເພີ່ມສຳເລັດ | Role created');
                              } else {
                                _addLog(
                                  'API Response',
                                  'API Error',
                                  'Code: ${result['responseCode']}, Message: ${result['message']}',
                                  'error',
                                );
                                _snack(result['message'] ?? 'Failed', isError: true);
                              }
                            },
                      icon: isSaving
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save_rounded, size: 16),
                      label: Text(isSaving ? 'ກຳລັງບັນທຶກ...' : 'ບັນທຶກ | Save',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _purple,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmDeleteRole(Map<String, dynamic> role) {
    _addLog(
      'Dialog Open',
      'UI',
      'Delete confirmation opened for role: ${role['role_name']}',
      'warning',
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: _red.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.delete_forever_rounded, color: _red, size: 20),
            ),
            const SizedBox(width: 12),
            const Text('ລົບບົດບາດ | Delete Role', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _textPrimary)),
          ],
        ),
        content: Text(
          'ຕ້ອງການລົບ "${role['role_name']}" ແທ້ບໍ?\nCannot delete if users are assigned.',
          style: const TextStyle(fontSize: 13, color: _textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _addLog('Dialog Close', 'UI', 'Delete confirmation cancelled', 'info');
              Navigator.pop(ctx);
            },
            child: const Text('ຍົກເລີກ', style: TextStyle(color: _textSecondary)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              
              _addLog(
                'API Call - Delete Role',
                'API Request',
                'Endpoint: DELETE http://localhost:2026/api/roles/${role['role_id']}\nDeleting role: ${role['role_name']}',
                'warning',
              );
              
              final result = await ApiService.deleteRole(role['role_id']);
              if (result['responseCode'] == '00') {
                _addLog(
                  'Delete Role',
                  'User Action',
                  'Deleted role: ${role['role_name']} (ID: ${role['role_id']})',
                  'success',
                );
                _addLog(
                  'API Response',
                  'API Success',
                  'Response Code: ${result['responseCode']}',
                  'success',
                );
                _loadData();
                _snack('ລົບສຳເລັດ | Role deleted');
              } else {
                _addLog(
                  'API Response',
                  'API Error',
                  'Code: ${result['responseCode']}, Message: ${result['message']}',
                  'error',
                );
                _snack(result['message'] ?? 'Failed (users may be assigned)', isError: true);
              }
            },
            icon: const Icon(Icons.delete_rounded, size: 16),
            label: const Text('ລົບ | Delete', style: TextStyle(fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _red, foregroundColor: Colors.white, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecor(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _textSecondary, fontSize: 13),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      filled: true,
      fillColor: _bg,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _accent, width: 1.5)),
    );
  }

  Widget _buildActivityLog() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _surface.withOpacity(0.8),
            _bg.withOpacity(0.5),
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _border.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _accent.withOpacity(0.1),
                  _purple.withOpacity(0.05),
                ],
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [_green, Color(0xFF059669)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.history_rounded,
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
                        'ບັນທຶກກິດຈະກຳ',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: _textPrimary,
                        ),
                      ),
                      Text(
                        'Activity Log',
                        style: TextStyle(
                          fontSize: 11,
                          color: _textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {
                    setState(() => _activityLogs.clear());
                    _addLog('Clear Logs', 'System', 'Activity logs cleared', 'warning');
                  },
                  icon: const Icon(Icons.delete_sweep_rounded, color: _red),
                  tooltip: 'Clear logs',
                ),
              ],
            ),
          ),

          // Logs List
          Expanded(
            child: _activityLogs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 48,
                          color: _textSecondary.withOpacity(0.3),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'ບໍ່ມີບັນທຶກກິດຈະກຳ',
                          style: TextStyle(
                            color: _textSecondary.withOpacity(0.6),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _activityLogs.length,
                    itemBuilder: (context, index) {
                      return _buildLogEntry(_activityLogs[index]);
                    },
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
        typeColor = _green;
        typeIcon = Icons.check_circle_rounded;
        break;
      case 'warning':
        typeColor = _amber;
        typeIcon = Icons.warning_rounded;
        break;
      case 'error':
        typeColor = _red;
        typeIcon = Icons.error_rounded;
        break;
      default:
        typeColor = _accent;
        typeIcon = Icons.info_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _surface.withOpacity(0.6),
            _bg.withOpacity(0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: typeColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(typeIcon, color: typeColor, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  log['action'],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: typeColor,
                  ),
                ),
              ),
              Text(
                _formatTime(log['timestamp']),
                style: TextStyle(
                  fontSize: 10,
                  color: _textSecondary.withOpacity(0.6),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            log['description'],
            style: const TextStyle(
              fontSize: 12,
              color: _textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _accent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: _accent.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Text(
                  log['category'],
                  style: const TextStyle(
                    fontSize: 9,
                    color: _accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _textSecondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: _textSecondary.withOpacity(0.2),
                    width: 1,
                  ),
                ),
                child: Text(
                  log['user'],
                  style: const TextStyle(
                    fontSize: 9,
                    color: _textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // BUILD
  // ==========================================
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          flex: _showLogs ? 2 : 1,
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                child: Row(
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ຈັດການບົດບາດ & ສິດ', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _textPrimary)),
                        SizedBox(height: 2),
                        Text('Role & Permission Management', style: TextStyle(fontSize: 13, color: _textSecondary)),
                      ],
                    ),
                    const Spacer(),
                    // Log Toggle Button
                    Material(
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
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            gradient: _showLogs
                                ? const LinearGradient(
                                    colors: [_green, Color(0xFF059669)],
                                  )
                                : LinearGradient(
                                    colors: [
                                      _surfaceLight.withOpacity(0.5),
                                      _surface.withOpacity(0.3),
                                    ],
                                  ),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _showLogs
                                  ? _green.withOpacity(0.5)
                                  : _border.withOpacity(0.5),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                _showLogs ? Icons.receipt_long_rounded : Icons.receipt_long_outlined,
                                color: _showLogs ? Colors.white : _textSecondary,
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _showLogs ? 'ເຊື່ອງ Log' : 'ສະແດງ Log',
                                style: TextStyle(
                                  color: _showLogs ? Colors.white : _textSecondary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (_activityLogs.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: _showLogs 
                                        ? Colors.white.withOpacity(0.2)
                                        : _accent.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    _activityLogs.length.toString(),
                                    style: TextStyle(
                                      color: _showLogs ? Colors.white : _accent,
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
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: () {
                        _addLog('Refresh', 'UI', 'Refresh button clicked', 'info');
                        _loadData();
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 20, color: _textSecondary),
                      splashRadius: 20,
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
              ),

              // Tab bar
              Container(
                margin: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border.withOpacity(0.5)),
                ),
                child: TabBar(
                  controller: _tabController,
                  onTap: (index) {
                    _addLog(
                      'Tab Change',
                      'UI',
                      'Switched to ${index == 0 ? "Roles" : "Menu Permissions"} tab',
                      'info',
                    );
                  },
                  indicator: BoxDecoration(
                    color: _accent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: _textSecondary,
                  labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  unselectedLabelStyle: const TextStyle(fontSize: 13),
                  padding: const EdgeInsets.all(4),
                  tabs: const [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.shield_outlined, size: 16),
                          SizedBox(width: 8),
                          Text('ບົດບາດ | Roles'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.checklist_rounded, size: 16),
                          SizedBox(width: 8),
                          Text('ສິດເຂົ້າເມນູ | Menu Permissions'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Tab content
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: _accent, strokeWidth: 2))
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildRolesTab(),
                          _buildMenuMappingTab(),
                        ],
                      ),
              ),
            ],
          ),
        ),
        if (_showLogs) ...[
          const SizedBox(width: 16),
          SizedBox(
            width: 400,
            child: Padding(
              padding: const EdgeInsets.only(top: 20, right: 24, bottom: 20),
              child: _buildActivityLog(),
            ),
          ),
        ],
      ],
    );
  }

  // Continue with the rest of the original code...
  // (I'll add the remaining widgets in the next part due to length)

  // ==========================================
  // ROLES TAB
  // ==========================================
  Widget _buildRolesTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Add button row
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: () => _showRoleDialog(),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('ເພີ່ມບົດບາດ | Add Role', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _purple,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Roles grid
          Expanded(
            child: _roles.isEmpty
                ? const Center(child: Text('ບໍ່ມີບົດບາດ | No roles', style: TextStyle(color: _textSecondary)))
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 340,
                      childAspectRatio: 2.2,
                      crossAxisSpacing: 14,
                      mainAxisSpacing: 14,
                    ),
                    itemCount: _roles.length,
                    itemBuilder: (ctx, i) {
                      final role = _roles[i];
                      final roleColors = [
                        const Color(0xFFE879F9), _accent, _purple,
                        const Color(0xFF06B6D4), _amber, _green, const Color(0xFFF97316),
                      ];
                      final c = roleColors[i % roleColors.length];

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: c.withOpacity(0.2)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: c.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(Icons.shield_rounded, size: 18, color: c),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        role['role_name'] ?? '',
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _textPrimary),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      Text(
                                        role['role_description'] ?? '',
                                        style: const TextStyle(fontSize: 11, color: _textSecondary),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                _miniBtn(Icons.edit_outlined, c, () => _showRoleDialog(role: role)),
                                const SizedBox(width: 8),
                                _miniBtn(Icons.delete_outline_rounded, _red, () => _confirmDeleteRole(role)),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _miniBtn(IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }

  // ==========================================
  // MENU MAPPING TAB
  // ==========================================
  Widget _buildMenuMappingTab() {
    final mainMenus = _menus.where((m) => m['parent_menu_id'] == null).toList();

    return Column(
      children: [
        // Role selector + Save
        Container(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
          child: Row(
            children: [
              const Text('ບົດບາດ: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _textSecondary)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: _selectedRoleId,
                    dropdownColor: _surface,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _textPrimary),
                    icon: const Icon(Icons.expand_more_rounded, color: _textSecondary, size: 20),
                    items: _roles.map((r) {
                      return DropdownMenuItem<int>(value: r['role_id'], child: Text(r['role_name']));
                    }).toList(),
                    onChanged: (v) {
                      if (v != null) {
                        final roleName = _roles.firstWhere((r) => r['role_id'] == v)['role_name'];
                        _addLog(
                          'Role Selection',
                          'UI',
                          'Changed selected role to: $roleName',
                          'info',
                        );
                        setState(() => _selectedRoleId = v);
                        _loadMappings(v);
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(width: 16),
              // Quick actions
              _quickPermBtn('Select All', Icons.check_box_outlined, () {
                _addLog('Quick Action', 'UI', 'Select All permissions clicked', 'info');
                setState(() {
                  for (final m in _menus) {
                    _mappings[m['menu_id']] = {'can_view': true, 'can_create': true, 'can_edit': true, 'can_delete': true};
                  }
                });
              }),
              const SizedBox(width: 8),
              _quickPermBtn('Clear All', Icons.check_box_outline_blank, () {
                _addLog('Quick Action', 'UI', 'Clear All permissions clicked', 'info');
                setState(() => _mappings.clear());
              }),
              const SizedBox(width: 8),
              _quickPermBtn('View Only', Icons.visibility_outlined, () {
                _addLog('Quick Action', 'UI', 'View Only permissions clicked', 'info');
                setState(() {
                  for (final m in _menus) {
                    _mappings[m['menu_id']] = {'can_view': true, 'can_create': false, 'can_edit': false, 'can_delete': false};
                  }
                });
              }),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _isSavingMapping ? null : _saveMappings,
                icon: _isSavingMapping
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded, size: 18),
                label: Text(
                  _isSavingMapping ? 'ກຳລັງບັນທຶກ...' : 'ບັນທຶກສິດ | Save Permissions',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _green,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),

        // Permission grid
        Expanded(
          child: Container(
            margin: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border.withOpacity(0.5)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    // Table header
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      color: _bg.withOpacity(0.6),
                      child: const Row(
                        children: [
                          SizedBox(width: 40),
                          Expanded(flex: 3, child: Text('MENU', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _textSecondary, letterSpacing: 0.5))),
                          Expanded(child: Center(child: Text('VIEW', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _textSecondary, letterSpacing: 0.5)))),
                          Expanded(child: Center(child: Text('CREATE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _textSecondary, letterSpacing: 0.5)))),
                          Expanded(child: Center(child: Text('EDIT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _textSecondary, letterSpacing: 0.5)))),
                          Expanded(child: Center(child: Text('DELETE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _textSecondary, letterSpacing: 0.5)))),
                        ],
                      ),
                    ),

                    // Menu rows grouped by parent
                    ...mainMenus.asMap().entries.map((entry) {
                      final mainMenu = entry.value;
                      final mainId = mainMenu['menu_id'];
                      final subMenus = _menus.where((m) => m['parent_menu_id'] == mainId).toList();

                      return Column(
                        children: [
                          // Parent menu row
                          _menuRow(
                            menu: mainMenu,
                            isParent: true,
                            bgColor: entry.key.isEven ? _bg.withOpacity(0.3) : Colors.transparent,
                          ),
                          // Sub menu rows
                          ...subMenus.map((sub) => _menuRow(
                                menu: sub,
                                isParent: false,
                                bgColor: entry.key.isEven ? _bg.withOpacity(0.15) : Colors.transparent,
                              )),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _menuRow({required Map<String, dynamic> menu, required bool isParent, Color bgColor = Colors.transparent}) {
    final menuId = menu['menu_id'] as int;
    final perms = _mappings[menuId] ?? {'can_view': false, 'can_create': false, 'can_edit': false, 'can_delete': false};
    final menuName = menu['menu_name'] ?? '';
    final menuNameLa = menu['menu_name_la'] ?? '';
    final icon = menu['menu_icon'] ?? 'circle';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      color: bgColor,
      child: Row(
        children: [
          // Indent for sub-menus
          SizedBox(width: isParent ? 0 : 28),
          // Icon
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: (isParent ? _accent : _surfaceLight).withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(
              _getMenuIcon(icon),
              size: isParent ? 16 : 14,
              color: isParent ? _accent : _textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          // Menu name
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  menuName,
                  style: TextStyle(
                    fontSize: isParent ? 13 : 12,
                    fontWeight: isParent ? FontWeight.w700 : FontWeight.w500,
                    color: isParent ? _textPrimary : _textPrimary.withOpacity(0.8),
                  ),
                ),
                if (menuNameLa.isNotEmpty)
                  Text(menuNameLa, style: const TextStyle(fontSize: 11, color: _textSecondary)),
              ],
            ),
          ),
          // Permission checkboxes
          _permCheckbox(menuId, 'can_view', perms['can_view'] ?? false, _accent),
          _permCheckbox(menuId, 'can_create', perms['can_create'] ?? false, _green),
          _permCheckbox(menuId, 'can_edit', perms['can_edit'] ?? false, _amber),
          _permCheckbox(menuId, 'can_delete', perms['can_delete'] ?? false, _red),
        ],
      ),
    );
  }

  Widget _permCheckbox(int menuId, String perm, bool value, Color color) {
    return Expanded(
      child: Center(
        child: InkWell(
          onTap: () {
            setState(() {
              final current = _mappings[menuId] ?? {'can_view': false, 'can_create': false, 'can_edit': false, 'can_delete': false};
              current[perm] = !value;
              // Auto-enable view if any other perm is enabled
              if (perm != 'can_view' && current[perm] == true) {
                current['can_view'] = true;
              }
              _mappings[menuId] = current;
            });
          },
          borderRadius: BorderRadius.circular(6),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: value ? color.withOpacity(0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: value ? color : _border,
                width: value ? 1.5 : 1,
              ),
            ),
            child: value
                ? Icon(Icons.check_rounded, size: 16, color: color)
                : null,
          ),
        ),
      ),
    );
  }

  Widget _quickPermBtn(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: _surfaceLight.withOpacity(0.3),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _border.withOpacity(0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: _textSecondary),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 11, color: _textSecondary, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  IconData _getMenuIcon(String iconName) {
    const iconMap = <String, IconData>{
      'dashboard': Icons.dashboard_rounded,
      'people': Icons.people_rounded,
      'person': Icons.person_rounded,
      'person_add': Icons.person_add_rounded,
      'shield': Icons.shield_rounded,
      'lock': Icons.lock_rounded,
      'settings': Icons.settings_rounded,
      'store': Icons.store_rounded,
      'inventory': Icons.inventory_2_rounded,
      'shopping_cart': Icons.shopping_cart_rounded,
      'receipt': Icons.receipt_long_rounded,
      'receipt_long': Icons.receipt_long_rounded,
      'point_of_sale': Icons.point_of_sale_rounded,
      'payment': Icons.payment_rounded,
      'money': Icons.attach_money_rounded,
      'attach_money': Icons.attach_money_rounded,
      'bar_chart': Icons.bar_chart_rounded,
      'analytics': Icons.analytics_rounded,
      'trending_up': Icons.trending_up_rounded,
      'assessment': Icons.assessment_rounded,
      'category': Icons.category_rounded,
      'local_offer': Icons.local_offer_rounded,
      'sell': Icons.sell_rounded,
      'qr_code': Icons.qr_code_rounded,
      'report': Icons.summarize_rounded,
      'summarize': Icons.summarize_rounded,
      'notifications': Icons.notifications_rounded,
      'history': Icons.history_rounded,
      'backup': Icons.backup_rounded,
      'cloud': Icons.cloud_rounded,
      'help': Icons.help_rounded,
      'info': Icons.info_rounded,
      'circle': Icons.circle_outlined,
      'list': Icons.list_rounded,
      'edit': Icons.edit_rounded,
      'add': Icons.add_rounded,
      'delete': Icons.delete_rounded,
      'search': Icons.search_rounded,
      'print': Icons.print_rounded,
      'download': Icons.download_rounded,
      'upload': Icons.upload_rounded,
      'swap_horiz': Icons.swap_horiz_rounded,
      'group': Icons.group_rounded,
      'groups': Icons.groups_rounded,
      'account_circle': Icons.account_circle_rounded,
      'manage_accounts': Icons.manage_accounts_rounded,
      'admin_panel_settings': Icons.admin_panel_settings_rounded,
      'security': Icons.security_rounded,
      'vpn_key': Icons.vpn_key_rounded,
      'key': Icons.key_rounded,
    };
    return iconMap[iconName] ?? Icons.circle_outlined;
  }
}