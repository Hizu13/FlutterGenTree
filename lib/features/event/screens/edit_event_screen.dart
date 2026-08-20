import 'package:flutter/material.dart';
import '../../../config/app_color.dart';
import '../models/event_model.dart';
import '../widgets/event_form.dart';

class EditEventScreen extends StatelessWidget {
  final EventModel event;
  final Function(EventModel event)? onEditEvent;

  const EditEventScreen({super.key, required this.event, this.onEditEvent});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text(
          'Sửa sự kiện',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: EventForm(
        initialEvent: event,
        canManage: true,
        customSubmitText: 'Lưu thay đổi',
        onSubmit: (updatedEvent) {
          onEditEvent?.call(updatedEvent);
          Navigator.pop(context);
        },
      ),
    );
  }
}
