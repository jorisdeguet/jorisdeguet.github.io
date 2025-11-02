import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/repartition.dart';
import '../models/groupe.dart';
import '../services/ci_calculator_service.dart';

/// Widget réutilisable pour afficher un résumé de répartition
class RepartitionSummaryCard extends StatelessWidget {
  final Repartition repartition;
  final List<Groupe> groupes;
  final bool isCompact;
  final VoidCallback? onTap;
  final Widget? trailing;

  const RepartitionSummaryCard({
    Key? key,
    required this.repartition,
    required this.groupes,
    this.isCompact = false,
    this.onTap,
    this.trailing,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final ciCalculator = CICalculatorService();

    // Calculer les infos
    final userGroupeIds = currentUser != null
        ? (repartition.allocations[currentUser.uid] ?? [])
        : <String>[];

    final userGroupes = groupes
        .where((g) => userGroupeIds.contains(g.id))
        .toList();

    // Cours de l'utilisateur
    final coursSet = userGroupes.map((g) => g.cours).toSet();
    String coursInfo = '';
    if (coursSet.isNotEmpty) {
      if (coursSet.length == 1) {
        coursInfo = '${coursSet.first} (${userGroupes.length} groupe${userGroupes.length > 1 ? 's' : ''})';
      } else {
        coursInfo = '${coursSet.length} cours (${userGroupes.length} groupes)';
      }
    }

    // CI moyenne
    double totalCI = 0;
    int enseignantCount = 0;
    for (var entry in repartition.allocations.entries) {
      final enseignantGroupes = groupes
          .where((g) => entry.value.contains(g.id))
          .toList();
      if (enseignantGroupes.isNotEmpty) {
        totalCI += ciCalculator.calculateCI(enseignantGroupes);
        enseignantCount++;
      }
    }
    final double avgCI = enseignantCount > 0 ? totalCI / enseignantCount : 0.0;

    // Groupes non attribués
    final unallocatedCount = repartition.groupesNonAlloues.length;

    if (isCompact) {
      return _buildCompactCard(context, coursInfo, avgCI, unallocatedCount);
    } else {
      return _buildFullCard(context, coursInfo, avgCI, unallocatedCount);
    }
  }

  Widget _buildCompactCard(BuildContext context, String coursInfo, double avgCI, int unallocatedCount) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: theme.dividerColor,
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    repartition.nom,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.school, size: 12, color: theme.textTheme.bodySmall?.color),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          coursInfo.isNotEmpty ? coursInfo : 'Aucun cours',
                          style: theme.textTheme.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.analytics, size: 12, color: theme.textTheme.bodySmall?.color),
                      const SizedBox(width: 4),
                      Text(
                        'CI moy: ${avgCI.toStringAsFixed(1)}',
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(width: 12),
                      if (unallocatedCount > 0) ...[
                        Icon(Icons.warning, size: 12, color: Colors.orange),
                        const SizedBox(width: 4),
                        Text(
                          '$unallocatedCount non attr.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.orange,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }

  Widget _buildFullCard(BuildContext context, String coursInfo, double avgCI, int unallocatedCount) {
    final theme = Theme.of(context);

    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    repartition.estAutomatique
                        ? Icons.auto_awesome
                        : repartition.estValide
                            ? Icons.check_circle
                            : Icons.warning,
                    color: repartition.estAutomatique
                        ? Colors.purple
                        : repartition.estValide
                            ? Colors.green
                            : Colors.orange,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      repartition.nom,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
              const SizedBox(height: 12),
              Divider(height: 1, color: theme.dividerColor),
              const SizedBox(height: 12),

              // Mes cours
              if (coursInfo.isNotEmpty) ...[
                _buildInfoRow(
                  context,
                  icon: Icons.school,
                  label: 'Mes cours',
                  value: coursInfo,
                  valueColor: Colors.blue,
                ),
                const SizedBox(height: 8),
              ],

              // CI moyenne
              _buildInfoRow(
                context,
                icon: Icons.analytics,
                label: 'CI moyenne',
                value: avgCI.toStringAsFixed(1),
                valueColor: _getCIColor(avgCI),
              ),
              const SizedBox(height: 8),

              // Groupes non attribués
              _buildInfoRow(
                context,
                icon: unallocatedCount > 0 ? Icons.warning : Icons.check_circle,
                label: 'Groupes non attribués',
                value: '$unallocatedCount',
                valueColor: unallocatedCount > 0 ? Colors.orange : Colors.green,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 16, color: theme.iconTheme.color ?? Colors.grey),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }

  Color _getCIColor(double ci) {
    // Supposons que la plage cible est autour de 38-46
    if (ci >= 38 && ci <= 46) {
      return Colors.green;
    } else if (ci >= 35 && ci <= 49) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}

