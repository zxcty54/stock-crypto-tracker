import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateChartPostSheet extends StatefulWidget {
  final VoidCallback onPostCreated;
  final File? initialImage; // Gallery se direct aayi hui image

  const CreateChartPostSheet({
    super.key,
    required this.onPostCreated,
    this.initialImage,
  });

  @override
  State<CreateChartPostSheet> createState() => _CreateChartPostSheetState();
}

class _CreateChartPostSheetState extends State<CreateChartPostSheet> {
  final _noteController = TextEditingController();
  final _assetController = TextEditingController(text: 'NIFTY');
  File? _selectedImage;
  String _selectedTimeframe = '5m';
  String _selectedBias = 'BULLISH';
  bool _isProcessing = false;
  String _statusMessage = '';

  final List<String> _timeframes = ['1m', '5m', '15m', '1h', '1D'];

  @override
  void initState() {
    super.initState();
    if (widget.initialImage != null) {
      _selectedImage = widget.initialImage;
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    _assetController.dispose();
    super.dispose();
  }

  // 🖼️ Gallery Picker
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100, // Original quality pick karein, compression niche custom method handle karega
    );
    if (picked != null) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  // ⚡ Non-blocking Native Compression
  Future<File> _compressImage(File originalFile) async {
    final tempDir = await getTemporaryDirectory();
    final targetPath = '${tempDir.path}/compressed_${DateTime.now().millisecondsSinceEpoch}.jpg';

    final XFile? compressedXFile = await FlutterImageCompress.compressAndGetFile(
      originalFile.absolute.path,
      targetPath,
      minWidth: 1280,
      minHeight: 1280,
      quality: 70, // 5-8 MB screenshot ko ~150-200 KB me convert karta hai
      format: CompressFormat.jpeg,
    );

    if (compressedXFile != null) {
      return File(compressedXFile.path);
    }
    return originalFile;
  }

  // 🚀 Publish Setup
  Future<void> _submitPost() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in or create a handle first!')),
      );
      return;
    }

    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please attach a chart screenshot!')),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Optimizing chart image...';
    });

    try {
      // 1. Background Compression (Smooth & lag-free)
      final File uploadReadyFile = await _compressImage(_selectedImage!);

      if (mounted) {
        setState(() => _statusMessage = 'Uploading to terminal wire...');
      }

      // 2. Supabase Storage Upload
      final supabase = Supabase.instance.client;
      final fileExt = uploadReadyFile.path.split('.').last;
      final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      await supabase.storage.from('charts').upload(
            fileName,
            uploadReadyFile,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      final imageUrl = supabase.storage.from('charts').getPublicUrl(fileName);

      // 3. Database Post Insert
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
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = '';
        });
      }
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
      child: Stack(
        children: [
          SingleChildScrollView(
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
                        letterSpacing: 0.8,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Image Picker / Preview Container
                InkWell(
                  onTap: _isProcessing ? null : _pickImage,
                  child: Container(
                    height: 165,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF141C2B),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF25334A)),
                    ),
                    child: _selectedImage != null
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(_selectedImage!, fit: BoxFit.cover),
                              ),
                              Positioned(
                                top: 8,
                                right: 8,
                                child: InkWell(
                                  onTap: () => setState(() => _selectedImage = null),
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: const BoxDecoration(
                                      color: Colors.black87,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, color: Colors.white, size: 14),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined, color: Color(0xFF00E5FF), size: 30),
                              SizedBox(height: 8),
                              Text(
                                'Select or Drop TradingView Screenshot',
                                style: TextStyle(color: Colors.white54, fontSize: 11),
                              ),
                            ],
                          ),
                  ),
                ),

                const SizedBox(height: 12),

                // Asset Symbol & Timeframe
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _assetController,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        textCapitalization: TextCapitalization.characters,
                        decoration: InputDecoration(
                          labelText: 'Symbol',
                          labelStyle: const TextStyle(color: Colors.white54, fontSize: 11),
                          filled: true,
                          fillColor: const Color(0xFF141C2B),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF141C2B),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedTimeframe,
                          dropdownColor: const Color(0xFF141C2B),
                          style: const TextStyle(color: Color(0xFF00E5FF), fontWeight: FontWeight.bold, fontSize: 12),
                          items: _timeframes.map((tf) => DropdownMenuItem(value: tf, child: Text(tf))).toList(),
                          onChanged: (v) => setState(() => _selectedTimeframe = v!),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Bias Selector (Bullish, Bearish, Neutral)
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
                    hintText: 'Add reasoning (e.g. Breakout retest with heavy volume)...',
                    hintStyle: const TextStyle(color: Colors.white24, fontSize: 11),
                    filled: true,
                    fillColor: const Color(0xFF141C2B),
                    contentPadding: const EdgeInsets.all(12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                  ),
                ),

                const SizedBox(height: 14),

                // Publish Button
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _submitPost,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00E5FF),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(
                      'PUBLISH SETUP',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 🔄 Smooth Loading Overlay (Jab compress & upload chal raha ho)
          if (_isProcessing)
            Positioned.fill(
              child: Container(
                color: const Color(0xFF0F1726).withOpacity(0.85),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Color(0xFF00E5FF),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _statusMessage,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
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
            border: Border.all(color: isSelected ? color : Colors.transparent),
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
