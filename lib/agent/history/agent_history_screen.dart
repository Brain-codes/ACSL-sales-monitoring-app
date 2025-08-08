// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:stove_transaction/agent/history/controller/agent_history_controller.dart';
import 'package:stove_transaction/agent/history/ui/activity_list_item.dart';
import 'package:stove_transaction/core/constants/app_colors.dart';
import 'package:stove_transaction/core/constants/text_theme.dart';
import 'package:stove_transaction/shared/widgets/base_app_bar.dart';
import 'package:stove_transaction/shared/widgets/page_header_tile.dart';

class AgentHistoryScreen extends StatelessWidget {
  const AgentHistoryScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final AgentHistoryController historyController =
        Get.put(AgentHistoryController());
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            historyController.refreshHistory();
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 30),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: PageHeaderTile(
                  title: 'Activity History',
                  subtitle: 'View your recent activities',
                  crossAxisAlignment: CrossAxisAlignment.start,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Obx(() {
                  if (historyController.isLoading.value) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  } else if (historyController.errorMessage.value.isNotEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          historyController.errorMessage.value,
                          style: TextThemes(context).getTextStyle(
                            fontSize: 16,
                            color: Colors.red,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  } else if (historyController.agentActivities.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, size: 48, color: Colors.grey),
                            const SizedBox(height: 16),
                            Text(
                              'No Activities Yet',
                              style: TextThemes(context).getTextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Start creating or updating sales to see your activity history here.',
                              textAlign: TextAlign.center,
                              style: TextThemes(context).getTextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  } else {
                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      itemCount: historyController.agentActivities.length,
                      itemBuilder: (context, index) {
                        final activity =
                            historyController.agentActivities[index];
                        return ActivityListItem(
                          history: activity,
                          onTap: () {
                            // TODO: Navigate to activity details if needed
                          },
                        );
                      },
                    );
                  }
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
