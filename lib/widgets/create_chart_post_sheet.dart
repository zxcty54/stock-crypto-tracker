import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CreateChartPostSheet extends StatefulWidget {
  final VoidCallback onPostCreated;
  final File? initialImage;

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
  final _entryController = TextEditingController();
  final _slController = TextEditingController();
  final _targetController = TextEditingController();

  File? _selectedImage;
  String _selectedTimeframe = '5m';
  String _selectedBias = 'BULLISH';
  bool _enableLevels = true;
  bool _isProcessing = false;
  String _statusMessage = '';

  final List<String> _quickTickers = ['NIFTY', 'BANKNIFTY', 'FINNIFTY', 'RELIANCE', 'CRUDEOIL', 'BTCUSD'];
  final List<String> _timeframes = ['1m', '3m', '5m', '15m', '1h', '4h', '1D', '1W'];

  // Terminal Theme Constants
  static const Color bgSheet = Color(0xFF090D16);
  static const Color surfaceCard = Color(0xFF131B2A);
  static const Color innerCard = Color(0xFF0F172A);
  static const Color borderSubtle = Color(0xFF202C42);
  static const Color accentCyan = Color(0xFF00E5FF);
  static const Color accentNeon = Color(0xFF00E676);
  static const Color accentRose = Color(0xFFFF5252);
  static const Color accentGold = Color(0xFFFFB300);
  static const Color textMuted = Color(0xFF94A3B8);

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
    _entryController.dispose();
    _slController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    HapticFeedback.selectionClick();
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 100);
    if (picked != null && mounted) {
      setState(() => _selectedImage = File(picked.path));
    }
  }

  Future<File> _compressImage(File originalFile) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final targetPath = '${tempDir.path}/chart_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final XFile? compressedXFile = await FlutterImageCompress.compressAndGetFile(
        originalFile.absolute.path,
        targetPath,
        minWidth: 1440,
        minHeight: 1440,
        quality: 72,
        format: CompressFormat.jpeg,
      );

      if (compressedXFile != null) {
        return File(compressedXFile.path);
      }
    } catch (_) {}
    return originalFile;
  }

  // 🎯 Live Risk:Reward Ratio Calculation
  String _calculateRiskReward() {
    final entry = double.tryParse(_entryController.text.trim()) ?? 0.0;
    final sl = double.tryParse(_slController.text.trim()) ?? 0.0;
    final tp = double.tryParse(_targetController.text.trim()) ?? 0.0;

    if (entry == 0.0 || sl == 0.0 || tp == 0.0) return 'Set levels';
    final risk = (entry - sl).abs();
    final reward = (tp - entry).abs();
    if (risk == 0) return 'Invalid SL';

    final ratio = reward / risk;
    return '1 : ${ratio.toStringAsFixed(2)} R:R';
  }

  Future<bool> _verifyTraderProfile(String userId) async {
    final supabase = Supabase.instance.client;
    try {
      final profile = await supabase
          .from('profiles')
          .select('username')
          .eq('id', userId)
          .maybeSingle();

      if (profile == null || (profile['username'] ?? '').toString().isEmpty) {
        if (!mounted) return false;
        return await _showProfileSetupPrompt(userId);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _showProfileSetupPrompt(String userId) async {
    final nameCtrl = TextEditingController();
    final handleCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: innerCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: borderSubtle),
        ),
        title: Text(
          'CREATE TRADER PROFILE',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Full Name',
                labelStyle: const TextStyle(color: textMuted, fontSize: 11),
                filled: true,
                fillColor: surfaceCard,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: borderSubtle),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: accentCyan),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: handleCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'Trader Handle (e.g. rohit_trader)',
                labelStyle: const TextStyle(color: textMuted, fontSize: 11),
                filled: true,
                fillColor: surfaceCard,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: borderSubtle),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: const BorderSide(color: accentCyan),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accentCyan,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              final name = nameCtrl.text.trim();
              final handle = handleCtrl.text.trim();
              if (name.isEmpty || handle.isEmpty) return;

              await Supabase.instance.client.from('profiles').upsert({
                'id': userId,
                'full_name': name,
                'username': handle.replaceAll('@', ''),
              });
              if (ctx.mounted) Navigator.pop(ctx, true);
            },
            child: const Text('Save Profile', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> _submitPost() async {
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in first to share your chart setup!')),
      );
      return;
    }

    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please attach a chart screenshot!')),
      );
      return;
    }

    final hasProfile = await _verifyTraderProfile(user.id);
    if (!hasProfile) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = 'Optimizing chart image...';
    });

    try {
      final File uploadReadyFile = await _compressImage(_selectedImage!);

      if (mounted) setState(() => _statusMessage = 'Uploading to terminal wire...');

      final fileExt = uploadReadyFile.path.split('.').last;
      final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      await supabase.storage.from('charts').upload(
            fileName,
            uploadReadyFile,
            fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
          );

      final imageUrl = supabase.storage.from('charts').getPublicUrl(fileName);

      // Safe Map Payload: 'tags' completely removed to prevent DB schema mismatch
      final Map<String, dynamic> payload = {
        'user_id': user.id,
        'chart_url': imageUrl,
        'asset_symbol': _assetController.text.trim().toUpperCase(),
        'timeframe': _selectedTimeframe,
        'bias': _selectedBias,
        'analysis_note': _noteController.text.trim(),
      };

      if (_enableLevels && _entryController.text.isNotEmpty) {
        payload['entry_price'] = double.tryParse(_entryController.text.trim());
      }
      if (_enableLevels && _slController.text.isNotEmpty) {
        payload['stop_loss'] = double.tryParse(_slController.text.trim());
      }
      if (_enableLevels && _targetController.text.isNotEmpty) {
        payload['target_price'] = double.tryParse(_targetController.text.trim());
      }

      await supabase.from('trader_posts').insert(payload);

      if (mounted) {
        Navigator.pop(context);
        widget.onPostCreated();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
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
        top: 10,
        left: 16,
        right: 16,
      ),
      decoration: const BoxDecoration(
        color: bgSheet,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(top: BorderSide(color: borderSubtle, width: 1.2)),
      ),
      child: Stack(
        children: [
          SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Terminal Drag Handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // 2. Header Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: accentCyan.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.add_chart_rounded, color: accentCyan, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'SHARE CHART SETUP',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: textMuted, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // 3. Quick Ticker Selector Ribbon
                SizedBox(
                  height: 30,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _quickTickers.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 6),
                    itemBuilder: (ctx, i) {
                      final t = _quickTickers[i];
                      final isSelected = _assetController.text.toUpperCase() == t;
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _assetController.text = t);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isSelected ? accentCyan.withOpacity(0.2) : surfaceCard,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: isSelected ? accentCyan : borderSubtle),
                          ),
                          child: Text(
                            t,
                            style: TextStyle(
                              color: isSelected ? accentCyan : Colors.white70,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 10),

                // 4. Uncropped Viewport (BoxFit.contain preserves price ladder)
                InkWell(
                  onTap: _isProcessing ? null : _pickImage,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 160,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: const Color(0xFF070B12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _selectedImage != null ? accentCyan.withOpacity(0.5) : borderSubtle,
                      ),
                    ),
                    child: _selectedImage != null
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(_selectedImage!, fit: BoxFit.contain),
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
                              Icon(Icons.add_photo_alternate_outlined, color: accentCyan, size: 28),
                              SizedBox(height: 6),
                              Text(
                                'Select or Drop TradingView Screenshot',
                                style: TextStyle(color: textMuted, fontSize: 11, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 12),

                // 5. Symbol & Timeframe Row
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: surfaceCard,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderSubtle),
                        ),
                        child: TextField(
                          controller: _assetController,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.tag_rounded, color: accentCyan, size: 16),
                            hintText: 'SYMBOL',
                            hintStyle: TextStyle(color: Colors.white24, fontSize: 12),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: surfaceCard,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: borderSubtle),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedTimeframe,
                            dropdownColor: surfaceCard,
                            icon: const Icon(Icons.expand_more_rounded, color: textMuted, size: 18),
                            style: const TextStyle(color: accentCyan, fontWeight: FontWeight.bold, fontSize: 12),
                            items: _timeframes.map((tf) => DropdownMenuItem(value: tf, child: Text(tf))).toList(),
                            onChanged: (v) => setState(() => _selectedTimeframe = v!),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // 6. Bias Selector (Bullish, Bearish, Neutral)
                Row(
                  children: [
                    _biasOption('BULLISH', accentNeon),
                    const SizedBox(width: 8),
                    _biasOption('BEARISH', accentRose),
                    const SizedBox(width: 8),
                    _biasOption('NEUTRAL', accentGold),
                  ],
                ),
                const SizedBox(height: 10),

                // 7. Actionable Execution Levels (Entry, SL, Target with Live R:R)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: innerCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: borderSubtle),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => setState(() => _enableLevels = !_enableLevels),
                                child: Icon(
                                  _enableLevels ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                  color: _enableLevels ? accentCyan : textMuted,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'EXECUTION LEVELS',
                                style: TextStyle(color: Colors.white70, fontSize: 10.5, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: accentCyan.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _calculateRiskReward(),
                              style: const TextStyle(color: accentCyan, fontSize: 10.5, fontWeight: FontWeight.w900),
                            ),
                          ),
                        ],
                      ),
                      if (_enableLevels) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(child: _levelField(_entryController, 'Entry Price', Colors.white, Colors.white24)),
                            const SizedBox(width: 6),
                            Expanded(child: _levelField(_slController, 'Stop Loss', accentRose, accentRose.withOpacity(0.3))),
                            const SizedBox(width: 6),
                            Expanded(child: _levelField(_targetController, 'Target', accentNeon, accentNeon.withOpacity(0.3))),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // 8. Analysis Note Field
                Container(
                  decoration: BoxDecoration(
                    color: surfaceCard,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: borderSubtle),
                  ),
                  child: TextField(
                    controller: _noteController,
                    maxLines: 2,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                    decoration: const InputDecoration(
                      hintText: 'Add triggers: e.g. Retest of demand zone, RSI divergence...',
                      hintStyle: TextStyle(color: Colors.white24, fontSize: 11),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(10),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // 9. Publish CTA Button
                SizedBox(
                  width: double.infinity,
                  height: 44,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _submitPost,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentCyan,
                      disabledBackgroundColor: accentCyan.withOpacity(0.3),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      elevation: 0,
                    ),
                    child: Text(
                      'PUBLISH WIRE SETUP',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.black,
                        fontWeight: FontWeight.w900,
                        fontSize: 12,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Integrated Progress Overlay
          if (_isProcessing)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: bgSheet.withOpacity(0.92),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(strokeWidth: 2.5, color: accentCyan),
                      const SizedBox(height: 12),
                      Text(
                        _statusMessage,
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
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

  Widget _levelField(TextEditingController ctrl, String label, Color textColor, Color borderCol) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: surfaceCard,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: borderCol),
      ),
      child: TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        style: TextStyle(color: textColor, fontSize: 11, fontWeight: FontWeight.bold),
        decoration: InputDecoration(
          hintText: label,
          hintStyle: const TextStyle(color: Colors.white30, fontSize: 10),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _biasOption(String bias, Color color) {
    final isSelected = _selectedBias == bias;
    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedBias = bias);
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.18) : surfaceCard,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: isSelected ? color : borderSubtle),
          ),
          alignment: Alignment.center,
          child: Text(
            bias,
            style: TextStyle(
              color: isSelected ? color : textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
