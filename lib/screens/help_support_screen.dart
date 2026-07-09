import 'package:flutter/material.dart';

class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Help & Support', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
          const SizedBox(height: 20),
          const Center(
            child: Icon(Icons.help_center_outlined, size: 80, color: Colors.blue),
          ),
          const SizedBox(height: 16),
          const Text(
            'How can we help you?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 32),
          _buildHelpItem(
            Icons.article_outlined,
            'FAQs',
            'Find answers to common questions',
          ),
          _buildHelpItem(
            Icons.email_outlined,
            'Contact Us',
            'Get in touch with our support team',
          ),
          _buildHelpItem(
            Icons.chat_bubble_outline,
            'Live Chat',
            'Chat with a support representative',
          ),
          _buildHelpItem(
            Icons.description_outlined,
            'User Guide',
            'Learn how to use DocuOrganizer',
          ),
          const SizedBox(height: 40),
          const Text(
            'Frequently Asked Questions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildFAQItem('How do I upload a document?', 'Click the + button on the home screen and select "Upload File".'),
          _buildFAQItem('How do I move files to a folder?', 'Tap the three dots menu on a file and select "Move to Folder".'),
          _buildFAQItem('What file types are supported?', 'We support PDF, Images, Word documents, Excel sheets, and Text files.'),
        ],
      ),
      ),
    );
  }

  Widget _buildHelpItem(IconData icon, String title, String subtitle) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[200]!)),
      margin: const EdgeInsets.only(bottom: 16),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: Colors.blue),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {},
      ),
    );
  }

  Widget _buildFAQItem(String question, String answer) {
    return ExpansionTile(
      title: Text(question, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(answer, style: TextStyle(color: Colors.grey[600])),
        ),
      ],
    );
  }
}
