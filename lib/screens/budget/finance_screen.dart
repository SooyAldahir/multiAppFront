import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/models.dart';
import '../../services/repositories.dart';
import '../expenses/expense_form_sheet.dart';
import '../expenses/expenses_screen.dart';
import 'budget_settings_screen.dart';
import 'budget_tab.dart';
import 'funds_tab.dart';

/// Finanzas: Presupuesto, Gastos y Apartados en un solo lugar.
class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key, this.initialTab = 0});
  final int initialTab;

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this, initialIndex: widget.initialTab);
  final _budgetKey = GlobalKey<BudgetTabState>();
  final _fundsKey = GlobalKey<FundsTabState>();
  BudgetSettings _settings = const BudgetSettings();

  @override
  void initState() {
    super.initState();
    _tabs.addListener(() {
      if (!_tabs.indexIsChanging) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _openSettings() async {
    final saved = await Navigator.of(context).push<BudgetSettings>(
      MaterialPageRoute(builder: (_) => BudgetSettingsScreen(initial: _settings)),
    );
    if (saved != null && mounted) {
      setState(() => _settings = saved);
      context.read<DataRefresh>().changed();
    }
  }

  void _onFab() {
    switch (_tabs.index) {
      case 0:
        _budgetKey.currentState?.openPlan();
      case 1:
        showExpenseForm(context);
      case 2:
        _fundsKey.currentState?.openNew();
    }
  }

  @override
  Widget build(BuildContext context) {
    final fabIcon = switch (_tabs.index) {
      0 => Icons.tune_rounded,
      _ => Icons.add_rounded,
    };
    final fabLabel = switch (_tabs.index) {
      0 => 'Planear',
      1 => 'Gasto',
      _ => 'Apartado',
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finanzas'),
        actions: [
          IconButton(tooltip: 'Ajustes del presupuesto', onPressed: _openSettings, icon: const Icon(Icons.settings_outlined)),
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.muted,
          indicatorColor: AppColors.primary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700),
          tabs: const [Tab(text: 'Presupuesto'), Tab(text: 'Gastos'), Tab(text: 'Apartados')],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'finance-fab',
        backgroundColor: AppColors.fab,
        foregroundColor: Colors.white,
        onPressed: _onFab,
        icon: Icon(fabIcon),
        label: Text(fabLabel),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          BudgetTab(key: _budgetKey, onViewLoaded: (v) => _settings = v.settings),
          const ExpensesScreen(embedded: true),
          FundsTab(key: _fundsKey),
        ],
      ),
    );
  }
}
