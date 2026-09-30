import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateChartPostSheet extends StatefulWidget {
  final VoidCallback onPostCreated;
  const CreateChartPostSheet({super.key, required this.onPostCreated});

  @override
  State<CreateChartPostSheet> createState() => _CreateChartPostSheetState();
}

class _CreateChartPostSheetState extends State<CreateChartPostSheet> {
  final _noteController = TextEditingController();
  final _assetController = TextEditingController(text: 'NIFTY');
  File? _pickedImage;
  String _selectedTimeframe = '5m';
  String _selectedBias = 'BULLISH';
  bool _isUploading = false;

  final List<String> _timeframes = ['1m', '5m', '15m', '1h', '1D'];

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      setState(() => _pickedImage = File(picked.path));
    }
  }

  Future<void> _submitPost() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;
    if (_pickedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please attach a chart screenshot!')),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final supabase = Supabase.instance.client;
      final fileExt = _pickedImage!.path.split('.').last;
      final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      // 1. Upload to Supabase Storage 'charts' bucket
      await supabase.storage.from('charts').upload(fileName, _pickedImage!);
      final imageUrl = supabase.storage.from('charts').getPublicUrl(fileName);

      // 2. Insert record in trader_posts table
      await supabase.from('trader_posts').insert({
        'user_id': user.id,
        'chart_url': imageUrl,
        'asset_symbol': _assetController.text.trim().toUpperCase(),
        'timeframe': _selectedTimeframe,
        'bias': _selectedBias,
        'analysis_note': _noteController.text.trim(),
      });

      if (mounted) {
        Navigator.pop(context);
        widget.onPostCreated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        top: 20,
        left: 16,
        right: 16,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0F1726),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: Color(0xFF1E2B3E))),
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'SHARE CHART SETUP',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Image Picker Box
            InkWell(
              onTap: _pickImage,
              child: Container(
                height: 160,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFF141C2B),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF25334A), style: BorderStyle.solid),
                ),
                child: _pickedImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(_pickedImage!, fit: BoxFit.cover),
                      )
                    : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_photo_alternate_outlined, color: Color(0xFF00E5FF), size: 32),
                          SizedBox(height: 8),
                          Text('Attach TradingView / Chart Screenshot',
                              style: TextStyle(color: Colors.white54, fontSize: 11)),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 12),

            // Symbol + Timeframe
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _assetController,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      labelText: 'Symbol',
                      labelStyle: const TextStyle(color: Colors.white54, fontSize: 12),
                      filled: true,
                      fillColor: const Color(0xFF141C2B),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF141C2B),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF25334A)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedTimeframe,
                      dropdownColor: const Color(0xFF141C2B),
                      style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold),
                      items: _timeframes.map((tf) => DropdownMenuItem(value: tf, child: Text(tf))).toList(),
                      onChanged: (v) => setState(() => _selectedTimeframe = v!),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Bias Selector
            Row(
              children: [
                _biasOption('BULLISH', const Color(0xFF00F5A0)),
                const SizedBox(width: 8),
                _biasOption('BEARISH', const Color(0xFFFF2A6D)),
                const SizedBox(width: 8),
                _biasOption('NEUTRAL', const Color(0xFFFFD700)),
              ],
            ),

            const SizedBox(height: 12),

            // Note Field
            TextField(
              controller: _noteController,
              maxLines: 2,
              style: const TextStyle(color: Colors.white, fontSize: 12),
              decoration: InputDecoration(
                hintText: 'Add reasoning (e.g. Stop-loss hunt at support + OI divergence)...',
                hintStyle: const TextStyle(color: Colors.white24, fontSize: 11),
                filled: true,
                fillColor: const Color(0xFF141C2B),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),

            const SizedBox(height: 14),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _submitPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E5FF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isUploading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : Text(
                        'PUBLISH SETUP',
                        style: GoogleFonts.plusJakartaSans(color: Colors.black, fontWeight: FontWeight.w900),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _biasOption(String bias, Color color) {
    final isSelected = _selectedBias == bias;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedBias = bias),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.2) : const Color(0xFF141C2B),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? color : const Color(0xFF25334A)),
          ),
          alignment: Alignment.center,
          child: Text(
            bias,
            style: TextStyle(
              color: isSelected ? color : Colors.white54,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}
