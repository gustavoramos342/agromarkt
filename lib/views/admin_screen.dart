import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../adapters/api_service.dart';
import '../controllers/auth_controller.dart';
import '../utils/app_feedback.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  final Set<int> _updatingUsers = {};
  final TextEditingController _searchController = TextEditingController();

  String _roleFilter = 'todos';
  String _statusFilter = 'todos';
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadUsers());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    final token = context.read<AuthController>().user?.token;

    if (token == null || token.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'Token não encontrado. Faça login novamente.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final result = await context.read<ApiService>().getAdminUsers(
        token: token,
      );

      if (!mounted) return;
      setState(() {
        _users = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = AppFeedback.friendlyError(
          e,
          fallback: 'Não foi possível carregar os usuários. Tente novamente.',
        );
      });
    }
  }

  bool _isActive(dynamic value) =>
      value == true ||
      value.toString().toLowerCase() == 't' ||
      value.toString().toLowerCase() == 'true' ||
      value.toString() == '1';

  String _roleName(dynamic role) {
    switch (role?.toString().toLowerCase()) {
      case 'produtor':
        return 'Produtor';
      case 'fornecedor':
        return 'Fornecedor';
      case 'admin':
        return 'Administrador';
      default:
        return 'Não identificado';
    }
  }

  String _formatDate(dynamic value) {
    if (value == null) return 'Não informado';
    final date = DateTime.tryParse(value.toString());
    if (date == null) return value.toString();
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}';
  }

  List<Map<String, dynamic>> get _filteredUsers {
    final query = _searchController.text.trim().toLowerCase();

    return _users.where((user) {
      final name = (user['name'] ?? '').toString().toLowerCase();
      final email = (user['email'] ?? '').toString().toLowerCase();
      final role = (user['role'] ?? '').toString().toLowerCase();
      final active = _isActive(user['is_active']);

      final matchesSearch =
          query.isEmpty || name.contains(query) || email.contains(query);

      final matchesRole = _roleFilter == 'todos' || role == _roleFilter;

      final matchesStatus =
          _statusFilter == 'todos' ||
          (_statusFilter == 'ativos' && active) ||
          (_statusFilter == 'inativos' && !active);

      return matchesSearch && matchesRole && matchesStatus;
    }).toList();
  }

  Future<void> _changeUserStatus(Map<String, dynamic> user) async {
    final auth = context.read<AuthController>();
    final token = auth.user?.token;
    final userId = int.tryParse('${user['id']}') ?? 0;
    final currentStatus = _isActive(user['is_active']);
    final newStatus = !currentStatus;

    if (token == null || token.isEmpty || userId <= 0) return;

    if (userId == auth.user?.id && !newStatus) {
      _showMessage('Você não pode desativar sua própria conta.', warning: true);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(newStatus ? 'Ativar usuário?' : 'Desativar usuário?'),
        content: Text(
          newStatus
              ? 'Deseja ativar a conta de ${user['name']}?'
              : 'O usuário ${user['name']} perderá o acesso ao AgroMarkt.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(newStatus ? 'Ativar' : 'Desativar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _updatingUsers.add(userId));

    try {
      final updated = await context.read<ApiService>().updateAdminUserStatus(
        token: token,
        id: userId,
        isActive: newStatus,
      );

      if (!mounted) return;

      setState(() {
        _replaceUser(userId, updated);
      });

      _showMessage(
        newStatus
            ? 'Usuário ativado com sucesso.'
            : 'Usuário desativado com sucesso.',
      );
    } catch (e) {
      if (mounted) {
        _showMessage(
          AppFeedback.friendlyError(
            e,
            fallback: 'Não foi possível atualizar a situação do usuário.',
          ),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _updatingUsers.remove(userId));
    }
  }

  Future<void> _changeUserRole(Map<String, dynamic> user) async {
    final auth = context.read<AuthController>();
    final token = auth.user?.token;
    final userId = int.tryParse('${user['id']}') ?? 0;
    final currentRole = user['role']?.toString();

    if (token == null || token.isEmpty || userId <= 0) return;

    if (currentRole == 'admin' || userId == auth.user?.id) {
      _showMessage(
        'Contas administrativas não podem ser alteradas aqui.',
        warning: true,
      );
      return;
    }

    final newRole = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Alterar perfil'),
        content: Text('Escolha o novo perfil para ${user['name']}.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          if (currentRole != 'produtor')
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'produtor'),
              child: const Text('Produtor'),
            ),
          if (currentRole != 'fornecedor')
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, 'fornecedor'),
              child: const Text('Fornecedor'),
            ),
        ],
      ),
    );

    if (newRole == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmar alteração?'),
        content: Text(
          'O perfil de ${user['name']} será alterado para '
          '${_roleName(newRole)}.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _updatingUsers.add(userId));

    try {
      final updated = await context.read<ApiService>().updateAdminUserRole(
        token: token,
        id: userId,
        role: newRole,
      );

      if (!mounted) return;

      setState(() => _replaceUser(userId, updated));
      _showMessage('Perfil atualizado com sucesso.');
    } catch (e) {
      if (mounted) {
        _showMessage(
          AppFeedback.friendlyError(
            e,
            fallback: 'Não foi possível alterar o perfil do usuário.',
          ),
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _updatingUsers.remove(userId));
    }
  }

  void _replaceUser(int userId, Map<String, dynamic> updated) {
    _users = _users.map((item) {
      final id = int.tryParse('${item['id']}') ?? 0;
      return id == userId ? {...item, ...updated} : item;
    }).toList();
  }

  void _showMessage(
    String message, {
    bool error = false,
    bool warning = false,
  }) {
    if (!mounted) return;

    if (error) {
      AppFeedback.error(context, message);
    } else if (warning) {
      AppFeedback.warning(context, message);
    } else {
      AppFeedback.success(context, message);
    }
  }

  void _showUserDetails(Map<String, dynamic> user) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Detalhes do usuário'),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detail('ID', '${user['id'] ?? '-'}'),
              _detail('Nome', '${user['name'] ?? '-'}'),
              _detail('E-mail', '${user['email'] ?? '-'}'),
              _detail('Perfil', _roleName(user['role'])),
              _detail(
                'Situação',
                _isActive(user['is_active']) ? 'Ativo' : 'Inativo',
              ),
              _detail('Cadastro', _formatDate(user['created_at'])),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 95,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }

  Widget _statCard(String title, int value, IconData icon, Color color) {
    return _StatCard(
      title: title,
      value: value.toString(),
      icon: icon,
      color: color,
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AuthController>().user;
    final total = _users.length;
    final active = _users.where((u) => _isActive(u['is_active'])).length;
    final inactive = total - active;
    final producers = _users.where((u) => u['role'] == 'produtor').length;
    final suppliers = _users.where((u) => u['role'] == 'fornecedor').length;
    final admins = _users.where((u) => u['role'] == 'admin').length;
    final visibleUsers = _filteredUsers;

    return Scaffold(
      appBar: AppBar(
        title: const Text('AgroMarkt - Administração'),
        actions: [
          IconButton(
            tooltip: 'Atualizar usuários',
            onPressed: _loading ? null : _loadUsers,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Sair',
            onPressed: () async {
              await context.read<AuthController>().logout();
            },
            icon: const Icon(Icons.logout),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadUsers,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Painel administrativo',
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Bem-vindo, ${currentUser?.name ?? 'Administrador'}. '
              'Gerencie os usuários cadastrados no AgroMarkt.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),

            if (_loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 42,
                      ),
                      const SizedBox(height: 12),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        onPressed: _loadUsers,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Tentar novamente'),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              LayoutBuilder(
                builder: (context, constraints) {
                  final columns = constraints.maxWidth >= 900
                      ? 4
                      : constraints.maxWidth >= 550
                      ? 2
                      : 1;

                  return GridView.count(
                    crossAxisCount: columns,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: columns == 1 ? 3.0 : 1.8,
                    children: [
                      _statCard(
                        'Total de usuários',
                        total,
                        Icons.people,
                        Colors.blue,
                      ),
                      _statCard(
                        'Usuários ativos',
                        active,
                        Icons.check_circle,
                        Colors.green,
                      ),
                      _statCard(
                        'Usuários inativos',
                        inactive,
                        Icons.block,
                        Colors.orange,
                      ),
                      _statCard(
                        'Administradores',
                        admins,
                        Icons.admin_panel_settings,
                        Colors.deepPurple,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              Text(
                'Usuários por perfil',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _RoleChip(
                    label: 'Produtores: $producers',
                    icon: Icons.agriculture,
                  ),
                  _RoleChip(
                    label: 'Fornecedores: $suppliers',
                    icon: Icons.store,
                  ),
                  _RoleChip(
                    label: 'Administradores: $admins',
                    icon: Icons.admin_panel_settings,
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(
                'Gerenciar usuários',
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  labelText: 'Pesquisar por nome ou e-mail',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: IconButton(
                    tooltip: 'Limpar pesquisa',
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                    icon: const Icon(Icons.clear),
                  ),
                  border: const OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 600;
                  final role = DropdownButtonFormField<String>(
                    initialValue: _roleFilter,
                    decoration: const InputDecoration(
                      labelText: 'Filtrar por perfil',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'todos',
                        child: Text('Todos os perfis'),
                      ),
                      DropdownMenuItem(
                        value: 'produtor',
                        child: Text('Produtor'),
                      ),
                      DropdownMenuItem(
                        value: 'fornecedor',
                        child: Text('Fornecedor'),
                      ),
                      DropdownMenuItem(
                        value: 'admin',
                        child: Text('Administrador'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _roleFilter = value ?? 'todos'),
                  );
                  final status = DropdownButtonFormField<String>(
                    initialValue: _statusFilter,
                    decoration: const InputDecoration(
                      labelText: 'Filtrar por situação',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'todos',
                        child: Text('Todas as situações'),
                      ),
                      DropdownMenuItem(value: 'ativos', child: Text('Ativos')),
                      DropdownMenuItem(
                        value: 'inativos',
                        child: Text('Inativos'),
                      ),
                    ],
                    onChanged: (value) =>
                        setState(() => _statusFilter = value ?? 'todos'),
                  );

                  if (wide) {
                    return Row(
                      children: [
                        Expanded(child: role),
                        const SizedBox(width: 12),
                        Expanded(child: status),
                      ],
                    );
                  }
                  return Column(
                    children: [role, const SizedBox(height: 12), status],
                  );
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${visibleUsers.length} de $total usuário(s)',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _roleFilter = 'todos';
                        _statusFilter = 'todos';
                      });
                    },
                    icon: const Icon(Icons.filter_alt_off),
                    label: const Text('Limpar filtros'),
                  ),
                ],
              ),
              if (visibleUsers.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text('Nenhum usuário corresponde aos filtros.'),
                    ),
                  ),
                )
              else
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('ID')),
                        DataColumn(label: Text('Nome')),
                        DataColumn(label: Text('E-mail')),
                        DataColumn(label: Text('Perfil')),
                        DataColumn(label: Text('Situação')),
                        DataColumn(label: Text('Cadastro')),
                        DataColumn(label: Text('Ações')),
                      ],
                      rows: visibleUsers.map((user) {
                        final isActive = _isActive(user['is_active']);
                        final id = int.tryParse('${user['id']}') ?? 0;
                        final isAdmin = user['role'] == 'admin';
                        final isSelf = id == currentUser?.id;
                        final updating = _updatingUsers.contains(id);

                        return DataRow(
                          cells: [
                            DataCell(Text('$id')),
                            DataCell(Text('${user['name'] ?? '-'}')),
                            DataCell(Text('${user['email'] ?? '-'}')),
                            DataCell(Text(_roleName(user['role']))),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    isActive
                                        ? Icons.check_circle
                                        : Icons.cancel,
                                    size: 16,
                                    color: isActive ? Colors.green : Colors.red,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(isActive ? 'Ativo' : 'Inativo'),
                                  if (isSelf) const Text(' (Você)'),
                                ],
                              ),
                            ),
                            DataCell(Text(_formatDate(user['created_at']))),
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: 'Ver detalhes',
                                    onPressed: () => _showUserDetails(user),
                                    icon: const Icon(Icons.visibility_outlined),
                                  ),
                                  if (!isAdmin && !isSelf)
                                    IconButton(
                                      tooltip: 'Alterar perfil',
                                      onPressed: updating
                                          ? null
                                          : () => _changeUserRole(user),
                                      icon: const Icon(Icons.swap_horiz),
                                    ),
                                  if (!isSelf)
                                    TextButton(
                                      onPressed: updating
                                          ? null
                                          : () => _changeUserStatus(user),
                                      child: updating
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : Text(
                                              isActive ? 'Desativar' : 'Ativar',
                                            ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 24),
            Text(
              'AgroMarkt • Área restrita de desenvolvimento',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: color, size: 34),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: Theme.of(context).textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  final String label;
  final IconData icon;

  const _RoleChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Chip(avatar: Icon(icon, size: 18), label: Text(label));
  }
}
