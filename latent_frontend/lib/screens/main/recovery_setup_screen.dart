import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../../services/api_service.dart';
import '../../providers/auth_provider.dart';

class RecoverySetupScreen extends StatefulWidget {
  const RecoverySetupScreen({super.key});

  @override
  State<RecoverySetupScreen> createState() => _RecoverySetupScreenState();
}

class _RecoverySetupScreenState extends State<RecoverySetupScreen> {
  bool _isLoading = true;
  List<String> _recoveryCodes = [];
  List<dynamic> _guardians = [];
  List<dynamic> _pendingRequests = [];
  List<dynamic> _friends = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        ApiService.getGuardians(),
        ApiService.getPendingGuardianRequests(),
        ApiService.getConnections(), // To select new guardians
      ]);
      
      setState(() {
        _guardians = results[0];
        _pendingRequests = results[1];
        _friends = results[2];
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading recovery setup: $e')));
      }
      setState(() => _isLoading = false);
    }
  }

  void _generateCodes() async {
    try {
      final codes = await ApiService.generateRecoveryCodes();
      setState(() => _recoveryCodes = codes);
      if (mounted) {
        _showBackupCodesDialog(codes);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to generate codes: $e')));
      }
    }
  }

  void _showBackupCodesDialog(List<String> codes) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Your Backup Codes'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'SAVE THESE CODES! They are the only way to recover your account if you lose your password and don\'t have Guardians set up.',
                style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceGray.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: GridView.builder(
                  shrinkWrap: true,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 3,
                  ),
                  itemCount: codes.length,
                  itemBuilder: (context, i) => Center(child: Text(codes[i], style: const TextStyle(fontWeight: FontWeight.bold))),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('I HAVE SAVED THEM')),
        ],
      ),
    );
  }

  void _approveRequest(String token) async {
    try {
      await ApiService.approveRecovery(token);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recovery request approved!')));
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Approval failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundWhite,
      appBar: AppBar(title: const Text('Recovery & Security')),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('One-Time Backup Codes'),
                  const Text(
                    'Generate codes to recover your account if you forget your password. Each code can only be used once.',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _generateCodes,
                    icon: const FaIcon(FontAwesomeIcons.gears),
                    label: const Text('Generate New Codes'),
                  ),
                  
                  const SizedBox(height: 40),
                  _buildSectionHeader('Social Recovery (Guardians)'),
                  const Text(
                    'Designate trusted friends who can vouch for you to reset your password.',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  ..._guardians.map((g) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(child: FaIcon(FontAwesomeIcons.userShield, size: 16)),
                    title: Text(g['username']),
                    trailing: const Icon(Icons.check_circle, color: Colors.green),
                  )),
                  TextButton.icon(
                    onPressed: _showSelectGuardiansDialog,
                    icon: const Icon(Icons.edit),
                    label: const Text('Manage Guardians'),
                  ),

                  if (_pendingRequests.isNotEmpty) ...[
                    const SizedBox(height: 40),
                    _buildSectionHeader('Vouch for Friends'),
                    const Text('Your friends are requesting recovery help.', style: TextStyle(color: AppTheme.primaryViolet, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    ..._pendingRequests.map((r) => Card(
                      color: AppTheme.primaryViolet.withOpacity(0.05),
                      elevation: 0,
                      child: ListTile(
                        title: Text('Vouch for ${r['username']}?'),
                        subtitle: Text('Token: ${r['token']}'),
                        trailing: ElevatedButton(
                          onPressed: () => _approveRequest(r['token']),
                          style: ElevatedButton.styleFrom(minimumSize: const Size(60, 30)),
                          child: const Text('Vouch'),
                        ),
                      ),
                    )),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryViolet),
      ),
    );
  }

  void _showSelectGuardiansDialog() {
    // Basic multi-select for simplicity
    List<int> selectedIds = _guardians.map((g) => g['id'] as int).toList();
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Select Guardians'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _friends.length,
              itemBuilder: (context, i) {
                final friend = _friends[i];
                // Connection might be sender/receiver
                final authProvider = context.read<AuthProvider>();
                final myId = authProvider.currentUser?['id'];
                final partner = friend['sender'] == myId ? friend['receiver_name'] : friend['sender_name'];
                final partnerId = friend['sender'] == myId ? friend['receiver'] : friend['sender'];
                
                final isSelected = selectedIds.contains(partnerId);
                
                return CheckboxListTile(
                  title: Text(partner),
                  value: isSelected,
                  onChanged: (val) {
                    setDialogState(() {
                      if (val == true) {
                        selectedIds.add(partnerId);
                      } else {
                        selectedIds.remove(partnerId);
                      }
                    });
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                await ApiService.updateGuardians(selectedIds);
                Navigator.pop(context);
                _loadData();
              }, 
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
