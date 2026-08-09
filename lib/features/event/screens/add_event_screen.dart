import 'package:flutter/material.dart';
import '../../../config/app_color.dart';
import '../models/event_model.dart';
import '../widgets/event_form.dart';

class AddEventScreen extends StatelessWidget {
  final Function(EventModel event)? onAddEvent;

  const AddEventScreen({super.key, this.onAddEvent});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text(
          'Thêm sự kiện',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: EventForm(
        submitButtonText: 'Yêu cầu phê duyệt',
        onSubmit: (newEvent) {
          onAddEvent?.call(newEvent);
          Navigator.pop(context);
        },
      ),
    );
  }
}
