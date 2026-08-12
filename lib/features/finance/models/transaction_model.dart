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
  final bool requiresApproval;

  TransactionModel({
    required this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.personName,
    required this.category,
    required this.date,
    this.note,
    this.requiresApproval = false,
  });
}
