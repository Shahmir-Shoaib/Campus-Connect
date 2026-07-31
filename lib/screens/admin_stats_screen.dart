import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class AdminStatsScreen extends StatefulWidget {
  const AdminStatsScreen({super.key});

  @override
  State<AdminStatsScreen> createState() => _AdminStatsScreenState();
}

class _AdminStatsScreenState extends State<AdminStatsScreen> {
  late final Future<_AdminStatsData> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = _loadAdminStats();
  }

  Future<_AdminStatsData> _loadAdminStats() async {
    final usersQuery = FirebaseFirestore.instance.collection('users').get();
    final postsQuery = FirebaseFirestore.instance.collection('posts').get();

    final results = await Future.wait([usersQuery, postsQuery]);
    final usersSnapshot = results[0] as QuerySnapshot;
    final postsSnapshot = results[1] as QuerySnapshot;

    final posts = postsSnapshot.docs
        .map((doc) => doc.data() as Map<String, dynamic>)
        .toList();

    final totalUsers = usersSnapshot.docs.length;
    final totalPosts = posts.length;
    final announcementCount = posts
        .where((post) => post['type'] == 'announcement')
        .length;
    final lostFoundCount = posts
        .where((post) => post['type'] == 'lost_found')
        .length;
    final resolvedLostFoundCount = posts
        .where(
          (post) =>
              post['type'] == 'lost_found' &&
              ((post['resolved'] as bool?) == true),
        )
        .length;
    final unresolvedLostFoundCount = posts
        .where(
          (post) =>
              post['type'] == 'lost_found' &&
              ((post['resolved'] as bool?) != true),
        )
        .length;

    final categories = <String, int>{
      'academic': 0,
      'event': 0,
      'general': 0,
      'lost': 0,
      'found': 0,
    };

    for (final post in posts) {
      final category = (post['category'] as String?)?.toLowerCase();
      if (category != null && categories.containsKey(category)) {
        categories[category] = categories[category]! + 1;
      }
    }

    return _AdminStatsData(
      totalUsers: totalUsers,
      totalPosts: totalPosts,
      announcementCount: announcementCount,
      lostFoundCount: lostFoundCount,
      resolvedLostFoundCount: resolvedLostFoundCount,
      unresolvedLostFoundCount: unresolvedLostFoundCount,
      categoryCounts: categories,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      body: FutureBuilder<_AdminStatsData>(
        future: _statsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading admin stats: ${snapshot.error}'),
            );
          }

          final stats = snapshot.data!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatCards(stats),
                const SizedBox(height: 24),
                _buildSectionHeader('Posts summary'),
                const SizedBox(height: 12),
                _buildSummaryRow('Announcements', stats.announcementCount),
                _buildSummaryRow('Lost & Found', stats.lostFoundCount),
                const SizedBox(height: 24),
                _buildSectionHeader('Lost & Found resolution'),
                const SizedBox(height: 16),
                _buildPieChart(stats),
                const SizedBox(height: 12),
                _buildPieLegend(stats),
                const SizedBox(height: 24),
                _buildSectionHeader('Posts by category'),
                const SizedBox(height: 16),
                _buildBarChart(stats.categoryCounts),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatCards(_AdminStatsData stats) {
    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: [
        _buildStatCard('Total Users', stats.totalUsers.toString()),
        _buildStatCard('Total Posts', stats.totalPosts.toString()),
      ],
    );
  }

  Widget _buildStatCard(String label, String value) {
    return SizedBox(
      width: 170,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
    );
  }

  Widget _buildSummaryRow(String title, int value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 16)),
          Text(
            value.toString(),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(_AdminStatsData stats) {
    final totalLostFound = stats.lostFoundCount;
    final resolved = stats.resolvedLostFoundCount;
    final unresolved = stats.unresolvedLostFoundCount;
    final hasData = totalLostFound > 0;

    final sections = <PieChartSectionData>[];
    if (!hasData) {
      sections.add(
        PieChartSectionData(
          value: 1,
          color: Colors.grey.shade400,
          title: 'No data',
          radius: 60,
          titleStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      );
    } else {
      if (resolved > 0) {
        sections.add(
          PieChartSectionData(
            value: resolved.toDouble(),
            color: Colors.green,
            title: '$resolved',
            radius: 60,
            titleStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        );
      }
      if (unresolved > 0) {
        sections.add(
          PieChartSectionData(
            value: unresolved.toDouble(),
            color: Colors.red,
            title: '$unresolved',
            radius: 60,
            titleStyle: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        );
      }
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          children: [
            SizedBox(
              height: 220,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 40,
                  sectionsSpace: 4,
                  startDegreeOffset: -90,
                  borderData: FlBorderData(show: false),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              hasData
                  ? 'Resolved vs Unresolved lost & found items'
                  : 'No lost & found posts available yet',
              style: const TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieLegend(_AdminStatsData stats) {
    final totalLostFound = stats.lostFoundCount;
    if (totalLostFound == 0) {
      return const SizedBox();
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildLegendItem(
          Colors.green,
          'Resolved',
          stats.resolvedLostFoundCount,
        ),
        _buildLegendItem(
          Colors.red,
          'Unresolved',
          stats.unresolvedLostFoundCount,
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label, int count) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text('$label: $count', style: const TextStyle(fontSize: 14)),
      ],
    );
  }

  Widget _buildBarChart(Map<String, int> categoryCounts) {
    final categories = ['academic', 'event', 'general', 'lost', 'found'];
    final maxValue = max(
      1,
      categoryCounts.values.fold<int>(0, max).toDouble(),
    ).toDouble();

    final barGroups = categories.asMap().entries.map((entry) {
      final index = entry.key;
      final category = entry.value;
      final value = categoryCounts[category]?.toDouble() ?? 0.0;
      return BarChartGroupData(
        x: index,
        barRods: [
          BarChartRodData(
            toY: value,
            color: _categoryColor(category),
            width: 18,
            borderRadius: BorderRadius.circular(6),
          ),
        ],
      );
    }).toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        child: SizedBox(
          height: 320,
          child: BarChart(
            BarChartData(
              maxY: maxValue + 1,
              barGroups: barGroups,
              titlesData: FlTitlesData(
                topTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: max(1, (maxValue / 5).ceilToDouble()),
                    reservedSize: 32,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toInt().toString(),
                        style: const TextStyle(fontSize: 10),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 58,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= categories.length) {
                        return const SizedBox.shrink();
                      }
                      return Text(
                        categories[index],
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 12),
                      );
                    },
                  ),
                ),
              ),
              gridData: FlGridData(
                show: true,
                horizontalInterval: max(1, (maxValue / 5).ceilToDouble()),
                drawVerticalLine: false,
              ),
              borderData: FlBorderData(show: false),
            ),
          ),
        ),
      ),
    );
  }

  Color _categoryColor(String category) {
    switch (category) {
      case 'academic':
        return Colors.blue;
      case 'event':
        return Colors.purple;
      case 'general':
        return Colors.grey;
      case 'lost':
        return Colors.orange;
      case 'found':
        return Colors.green;
      default:
        return Colors.blueGrey;
    }
  }
}

class _AdminStatsData {
  final int totalUsers;
  final int totalPosts;
  final int announcementCount;
  final int lostFoundCount;
  final int resolvedLostFoundCount;
  final int unresolvedLostFoundCount;
  final Map<String, int> categoryCounts;

  _AdminStatsData({
    required this.totalUsers,
    required this.totalPosts,
    required this.announcementCount,
    required this.lostFoundCount,
    required this.resolvedLostFoundCount,
    required this.unresolvedLostFoundCount,
    required this.categoryCounts,
  });
}
