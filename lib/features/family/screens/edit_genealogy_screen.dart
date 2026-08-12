import 'package:flutter/material.dart';
import 'package:gentree/features/family/widgets/genealogy_form.dart';

class EditGenealogyScreen extends StatelessWidget {
  const EditGenealogyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GenealogyForm(
      title: 'Chỉnh sửa gia phả',
      initialName: 'Dòng họ Nguyễn Văn',
      initialDescription: 'Tổ tiên dòng họ Nguyễn Văn tại Hà Nội',
      initialAddress: 'Hà nội, Việt Nam',
      initialNote: 'Gia phả chi tiết các thế hệ dòng họ Nguyễn Văn.',
      initialEstablishedDate: DateTime(2026, 1, 27),
      initialUpdatedDate: DateTime(2026, 3, 24),
      onSave: () {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã cập nhật thông tin gia phả!'),
            backgroundColor: Color(0xFF603813),
          ),
        );
      },
    );
  }
}
