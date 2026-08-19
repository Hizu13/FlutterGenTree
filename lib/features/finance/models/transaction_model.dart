import 'package:flutter/material.dart';
import '../../../../config/app_color.dart';

enum TransactionType { all, income, expense, merit }

class TransactionModel {
  final String id;
  final String title;
  final double amount;
  final TransactionType type;
  final String personName;
  final String category;
  final DateTime date;
  final String? note;
  final String status; // 'approved', 'pending', 'rejected'
  final bool requiresApproval;
  final int? familyId;
  final int? memberId;
  final int? createdById;

  TransactionModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.personName,
    required this.category,
    required this.date,
    this.note,
    this.status = 'approved',
    this.requiresApproval = false,
    this.familyId,
    this.memberId,
    this.createdById,
  });

  bool get isApproved => status == 'approved' && !requiresApproval;
  bool get isPending => status == 'pending' || requiresApproval;
  bool get isRejected => status == 'rejected';

  String get typeString {
    switch (type) {
      case TransactionType.income:
        return 'income';
      case TransactionType.expense:
        return 'expense';
      case TransactionType.merit:
        return 'merit';
      case TransactionType.all:
        return 'all';
    }
  }

  String get typeLabel {
    switch (type) {
      case TransactionType.income:
        return 'Khoản thu';
      case TransactionType.expense:
        return 'Khoản chi';
      case TransactionType.merit:
        return 'Công đức';
      case TransactionType.all:
        return 'Tất cả';
    }
  }

  Color get typeColor {
    switch (type) {
      case TransactionType.income:
        return AppColors.success;
      case TransactionType.expense:
        return AppColors.badgeRed;
      case TransactionType.merit:
        return AppColors.primaryGold;
      case TransactionType.all:
        return AppColors.primary;
    }
  }

  String get formattedAmount {
    final absAmount = amount.abs().toInt();
    final buffer = StringBuffer();
    final str = absAmount.toString();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }
    final prefix = type == TransactionType.expense ? '-' : '+';
    return '$prefix${buffer.toString()} đ';
  }

  factory TransactionModel.fromJson(Map<String, dynamic> json) {
    TransactionType parseType(String? val) {
      final t = (val ?? '').toLowerCase();
      if (t == 'expense') return TransactionType.expense;
      if (t == 'merit') return TransactionType.merit;
      return TransactionType.income;
    }

    DateTime parseDate(dynamic d) {
      if (d == null) return DateTime.now();
      if (d is DateTime) return d;
      try {
        return DateTime.parse(d.toString());
      } catch (_) {
        return DateTime.now();
      }
    }

    return TransactionModel(
      id: (json['id'] ?? '').toString(),
      title: json['title'] ?? '',
      amount: (json['amount'] is num) ? (json['amount'] as num).toDouble() : 0.0,
      type: parseType(json['type']),
      personName: json['personName'] ?? json['person_name'] ?? 'Thành viên',
      category: json['category'] ?? '',
      date: parseDate(json['date']),
      note: json['note'],
      status: json['status'] ?? 'approved',
      requiresApproval: json['requiresApproval'] ?? json['requires_approval'] ?? false,
      familyId: json['familyId'] ?? json['family_id'],
      memberId: json['memberId'] ?? json['member_id'],
      createdById: json['createdById'] ?? json['created_by_user_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'type': typeString,
      'personName': personName,
      'category': category,
      'date': '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'note': note,
      'status': status,
      'requiresApproval': requiresApproval,
      'familyId': familyId,
      'memberId': memberId,
    };
  }
}

class FinanceSummaryModel {
  final double totalBalance;
  final double totalIncome;
  final double totalExpense;
  final double totalMerit;
  final int transactionCount;

  FinanceSummaryModel({
    required this.totalBalance,
    required this.totalIncome,
    required this.totalExpense,
    required this.totalMerit,
    required this.transactionCount,
  });

  factory FinanceSummaryModel.empty() {
    return FinanceSummaryModel(
      totalBalance: 0,
      totalIncome: 0,
      totalExpense: 0,
      totalMerit: 0,
      transactionCount: 0,
    );
  }

  factory FinanceSummaryModel.fromJson(Map<String, dynamic> json) {
    return FinanceSummaryModel(
      totalBalance: (json['totalBalance'] ?? json['total_balance'] ?? 0).toDouble(),
      totalIncome: (json['totalIncome'] ?? json['total_income'] ?? 0).toDouble(),
      totalExpense: (json['totalExpense'] ?? json['total_expense'] ?? 0).toDouble(),
      totalMerit: (json['totalMerit'] ?? json['total_merit'] ?? 0).toDouble(),
      transactionCount: json['transactionCount'] ?? json['transaction_count'] ?? 0,
    );
  }

  String formatCurrency(double value) {
    final absVal = value.abs().toInt();
    final buffer = StringBuffer();
    final str = absVal.toString();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write('.');
      }
      buffer.write(str[i]);
    }
    final sign = value < 0 ? '-' : '';
    return '$sign${buffer.toString()} đ';
  }
}
