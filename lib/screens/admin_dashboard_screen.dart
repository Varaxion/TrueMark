import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int totalAttempts = 0;
  int successfulAttempts = 0;
  int failedAttempts = 0;
  Map<String, int> dailyLogins = {};

  @override
  void initState() {
    super.initState();
    fetchLoginStats();
  }

  Future<void> fetchLoginStats() async {
    final snapshot =
        await FirebaseFirestore.instance.collection('login_attempts').get();

    Map<String, int> tempDaily = {};
    int total = snapshot.docs.length;
    int success = 0;

    for (var doc in snapshot.docs) {
      final data = doc.data();
      if (data['success'] == true) {
        success++;
      }

      DateTime timestamp = (data['timestamp'] as Timestamp).toDate();
      String day = DateFormat('dd MMM').format(timestamp);

      if (!tempDaily.containsKey(day)) {
        tempDaily[day] = 1;
      } else {
        tempDaily[day] = tempDaily[day]! + 1;
      }
    }

    setState(() {
      totalAttempts = total;
      successfulAttempts = success;
      failedAttempts = total - success;
      dailyLogins = tempDaily;
    });
  }

  List<BarChartGroupData> buildChartData() {
    List<BarChartGroupData> bars = [];
    int index = 0;

    dailyLogins.forEach((date, count) {
      bars.add(
        BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: count.toDouble(),
              color: Colors.blueAccent,
              width: 18,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
              ),
            ),
          ],
          showingTooltipIndicators: [0],
        ),
      );
      index++;
    });

    return bars;
  }

  List<String> get chartLabels => dailyLogins.keys.toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: totalAttempts == 0
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Stats Summary
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildStatCard("Total", totalAttempts, Colors.blue),
                        _buildStatCard("Success", successfulAttempts, Colors.green),
                        _buildStatCard("Failed", failedAttempts, Colors.red),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      "Login Activity (Daily)",
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 250,
                      child: BarChart(
                        BarChartData(
                          borderData: FlBorderData(show: false),
                          titlesData: FlTitlesData(
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(showTitles: true),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  final labelIndex = value.toInt();
                                  return SideTitleWidget(
                                    axisSide: meta.axisSide,
                                    child: Text(
                                      labelIndex < chartLabels.length
                                          ? chartLabels[labelIndex]
                                          : '',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          barGroups: buildChartData(),
                          gridData: FlGridData(show: false),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatCard(String title, int value, Color color) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        width: 110,
        height: 100,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: color.withOpacity(0.12),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("$value",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 8),
            Text(title,
                style: TextStyle(
                    color: color, fontSize: 14, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}