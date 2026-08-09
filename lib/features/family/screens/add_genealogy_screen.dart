import 'package:flutter/material.dart';
import 'package:gentree/features/family/widgets/genealogy_form.dart';

class AddGenealogyScreen extends StatelessWidget {
  const AddGenealogyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GenealogyForm(
      title: 'Thêm gia phả mới',
      // Thêm gợi ý/dữ liệu mặc định để màn hình Thêm trông đầy đặn & đẹp mắt hơn
      initialName: '',
      initialDescription: '',
      initialAddress: 'Hà Nội, Việt Nam', // Mặc định địa chỉ tổ tiên
      initialNote: '',
      initialEstablishedDate: DateTime.now(), // Mặc định hôm nay
      initialUpdatedDate: DateTime.now(),
      onSave: () {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thêm gia phả mới thành công!'),
            backgroundColor: Color(0xFF603813),
          ),
        );
      },
    );
  }
}
