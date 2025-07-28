import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/account_deletion_service.dart';
import '../utils.dart';

class DeleteAccountDialog extends StatefulWidget {
  const DeleteAccountDialog({super.key});

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  final TextEditingController _passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _showPassword = false;
  bool _confirmDeletion = false;
  Map<String, dynamic>? _accountStatus;

  @override
  void initState() {
    super.initState();
    _checkAccountStatus();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkAccountStatus() async {
    final status = await AccountDeletionService.canDeleteAccount();
    setState(() {
      _accountStatus = status;
    });
  }

  Future<void> _deleteAccount() async {
    if (!_formKey.currentState!.validate() || !_confirmDeletion) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception('No user is currently signed in');
      }

      // Determine provider ID
      String? providerId;
      for (UserInfo userInfo in currentUser.providerData) {
        if (userInfo.providerId == 'google.com') {
          providerId = 'google.com';
          break;
        }
      }

      // Call the deletion service
      final result = await AccountDeletionService.deleteAccountCompletely(
        password: _passwordController.text,
        providerId: providerId,
      );

      if (result['success']) {
        if (mounted) {
          // Show success message
          AppUtils.showSuccessSnackBar(
            context,
            'Account deleted successfully. You have been signed out.',
          );
          
          // Close dialog and navigate to login
          Navigator.of(context).pop(true);
        }
      } else {
        if (mounted) {
          AppUtils.showErrorSnackBar(context, result['message']);
        }
      }
    } catch (e) {
      if (mounted) {
        AppUtils.showErrorSnackBar(
          context,
          'Failed to delete account: ${e.toString()}',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildWarningSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning, color: Colors.red.shade600, size: 20),
              const SizedBox(width: 8),
              Text(
                'Warning: This action cannot be undone',
                style: TextStyle(
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Deleting your account will permanently remove:',
            style: TextStyle(
              color: Colors.red.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _buildDeletedDataList(),
        ],
      ),
    );
  }

  Widget _buildDeletedDataList() {
    final items = [
      'Your profile and personal information',
      'All your messages and chat history',
      'Notices you have created',
      'Study materials you have uploaded',
      'Calendar events you have created',
      'Poll responses and created polls',
      'Your membership in all groups',
      'Profile pictures and uploaded files',
      'Your Firebase Authentication account',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '• ',
              style: TextStyle(color: Colors.red.shade600),
            ),
            Expanded(
              child: Text(
                item,
                style: TextStyle(
                  color: Colors.red.shade600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildGroupAdminWarning() {
    if (_accountStatus?['hasAdminGroups'] != true) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border.all(color: Colors.orange.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.admin_panel_settings, color: Colors.orange.shade600, size: 20),
              const SizedBox(width: 8),
              Text(
                'Group Administration Notice',
                style: TextStyle(
                  color: Colors.orange.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _accountStatus?['warning'] ?? '',
            style: TextStyle(
              color: Colors.orange.shade700,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField() {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    final bool isGoogleUser = currentUser?.providerData
        .any((userInfo) => userInfo.providerId == 'google.com') ?? false;

    if (isGoogleUser) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          border: Border.all(color: Colors.blue.shade200),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(Icons.info, color: Colors.blue.shade600),
            const SizedBox(height: 8),
            Text(
              'Google Account Detected',
              style: TextStyle(
                color: Colors.blue.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Please sign out and sign back in with Google before deleting your account.',
              style: TextStyle(
                color: Colors.blue.shade600,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Form(
      key: _formKey,
      child: TextFormField(
        controller: _passwordController,
        obscureText: !_showPassword,
        decoration: InputDecoration(
          labelText: 'Enter your password to confirm',
          hintText: 'Password',
          prefixIcon: const Icon(Icons.lock),
          suffixIcon: IconButton(
            icon: Icon(_showPassword ? Icons.visibility : Icons.visibility_off),
            onPressed: () {
              setState(() {
                _showPassword = !_showPassword;
              });
            },
          ),
          border: const OutlineInputBorder(),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter your password';
          }
          if (value.length < 6) {
            return 'Password must be at least 6 characters';
          }
          return null;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final User? currentUser = FirebaseAuth.instance.currentUser;
    final bool isGoogleUser = currentUser?.providerData
        .any((userInfo) => userInfo.providerId == 'google.com') ?? false;

    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.delete_forever, color: Colors.red),
          SizedBox(width: 8),
          Text('Delete Account'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildWarningSection(),
            _buildGroupAdminWarning(),
            const SizedBox(height: 20),
            _buildPasswordField(),
            if (!isGoogleUser) ...[
              const SizedBox(height: 16),
              CheckboxListTile(
                value: _confirmDeletion,
                onChanged: (value) {
                  setState(() {
                    _confirmDeletion = value ?? false;
                  });
                },
                title: const Text(
                  'I understand that this action cannot be undone',
                  style: TextStyle(fontSize: 14),
                ),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: (_isLoading || isGoogleUser || (!_confirmDeletion && !isGoogleUser)) 
              ? null 
              : isGoogleUser 
                  ? () => Navigator.of(context).pop(false)
                  : _deleteAccount,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(isGoogleUser ? 'Sign Out First' : 'Delete Account'),
        ),
      ],
    );
  }
}

class DeleteAccountButton extends StatelessWidget {
  const DeleteAccountButton({super.key});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => _showDeleteAccountDialog(context),
      icon: const Icon(Icons.delete_forever),
      label: const Text('Delete Account'),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      ),
    );
  }

  Future<void> _showDeleteAccountDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const DeleteAccountDialog(),
    );

    if (result == true) {
      // Account was deleted successfully, navigate to login
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/auth', // Replace with your login route
        (route) => false,
      );
    }
  }
}
