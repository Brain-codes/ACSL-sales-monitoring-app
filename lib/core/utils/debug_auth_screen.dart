import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/core/utils/debug_auth_utils.dart';
import 'package:stove_transaction/core/services/auth_service.dart';
import 'package:stove_transaction/core/services/session_manager.dart';

class DebugAuthScreen extends StatefulWidget {
  @override
  _DebugAuthScreenState createState() => _DebugAuthScreenState();
}

class _DebugAuthScreenState extends State<DebugAuthScreen> {
  String _debugOutput = 'Tap buttons to test auth functionality';
  final AuthService _authService = Get.find<AuthService>();
  final SessionManager _sessionManager = Get.find<SessionManager>();

  void _updateOutput(String message) {
    setState(() {
      _debugOutput += '\n\n$message';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Debug Auth Utils'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              margin: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SingleChildScrollView(
                child: Text(
                  _debugOutput,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          DebugAuthUtils.debugSessionState();
                          _updateOutput('Session state logged to console');
                        },
                        child: Text('Debug Session'),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final success =
                              await DebugAuthUtils.testRefreshToken();
                          _updateOutput(
                              'Refresh test: ${success ? 'SUCCESS' : 'FAILED'}');
                        },
                        child: Text('Test Refresh'),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final success = await _authService.refreshToken();
                          _updateOutput(
                              'Auth service refresh: ${success ? 'SUCCESS' : 'FAILED'}');
                        },
                        child: Text('Auth Refresh'),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          final info = DebugAuthUtils.getSessionExpiryInfo();
                          _updateOutput('Session info: $info');
                        },
                        child: Text('Session Info'),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red),
                        onPressed: () {
                          DebugAuthUtils.clearAllAuthData();
                          _updateOutput(
                              'All auth data cleared - will redirect to login');
                        },
                        child: Text('Clear Auth'),
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _debugOutput = 'Debug output cleared';
                          });
                        },
                        child: Text('Clear Output'),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),
                Text(
                  'Session Valid: ${_sessionManager.isSessionValid()}\n'
                  'Has Refresh Token: ${_sessionManager.hasValidRefreshToken()}\n'
                  'Is Authenticated: ${_sessionManager.isAuthenticated}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
