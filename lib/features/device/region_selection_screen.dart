import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme.dart';
import '../../providers/app_providers.dart';
import '../../generated/meshtastic/mesh.pbenum.dart';

/// Region data with display info
class RegionInfo {
  final RegionCode code;
  final String name;
  final String frequency;
  final String description;

  const RegionInfo({
    required this.code,
    required this.name,
    required this.frequency,
    required this.description,
  });
}

/// Available regions with their frequency bands
const List<RegionInfo> availableRegions = [
  RegionInfo(
    code: RegionCode.US,
    name: 'United States',
    frequency: '915 MHz',
    description: 'US, Canada, Mexico',
  ),
  RegionInfo(
    code: RegionCode.EU_868,
    name: 'Europe 868',
    frequency: '868 MHz',
    description: 'EU, UK, and most of Europe',
  ),
  RegionInfo(
    code: RegionCode.EU_433,
    name: 'Europe 433',
    frequency: '433 MHz',
    description: 'EU alternate frequency',
  ),
  RegionInfo(
    code: RegionCode.ANZ,
    name: 'Australia/NZ',
    frequency: '915 MHz',
    description: 'Australia and New Zealand',
  ),
  RegionInfo(
    code: RegionCode.CN,
    name: 'China',
    frequency: '470 MHz',
    description: 'China',
  ),
  RegionInfo(
    code: RegionCode.JP,
    name: 'Japan',
    frequency: '920 MHz',
    description: 'Japan',
  ),
  RegionInfo(
    code: RegionCode.KR,
    name: 'Korea',
    frequency: '920 MHz',
    description: 'South Korea',
  ),
  RegionInfo(
    code: RegionCode.TW,
    name: 'Taiwan',
    frequency: '923 MHz',
    description: 'Taiwan',
  ),
  RegionInfo(
    code: RegionCode.RU,
    name: 'Russia',
    frequency: '868 MHz',
    description: 'Russia',
  ),
  RegionInfo(
    code: RegionCode.IN,
    name: 'India',
    frequency: '865 MHz',
    description: 'India',
  ),
  RegionInfo(
    code: RegionCode.NZ_865,
    name: 'New Zealand 865',
    frequency: '865 MHz',
    description: 'New Zealand alternate',
  ),
  RegionInfo(
    code: RegionCode.TH,
    name: 'Thailand',
    frequency: '920 MHz',
    description: 'Thailand',
  ),
  RegionInfo(
    code: RegionCode.UA_433,
    name: 'Ukraine 433',
    frequency: '433 MHz',
    description: 'Ukraine',
  ),
  RegionInfo(
    code: RegionCode.UA_868,
    name: 'Ukraine 868',
    frequency: '868 MHz',
    description: 'Ukraine',
  ),
  RegionInfo(
    code: RegionCode.MY_433,
    name: 'Malaysia 433',
    frequency: '433 MHz',
    description: 'Malaysia',
  ),
  RegionInfo(
    code: RegionCode.MY_919,
    name: 'Malaysia 919',
    frequency: '919 MHz',
    description: 'Malaysia',
  ),
  RegionInfo(
    code: RegionCode.SG_923,
    name: 'Singapore',
    frequency: '923 MHz',
    description: 'Singapore',
  ),
  RegionInfo(
    code: RegionCode.LORA_24,
    name: '2.4 GHz',
    frequency: '2.4 GHz',
    description: 'Worldwide 2.4GHz band',
  ),
];

class RegionSelectionScreen extends ConsumerStatefulWidget {
  final bool isInitialSetup;

  const RegionSelectionScreen({super.key, this.isInitialSetup = false});

  @override
  ConsumerState<RegionSelectionScreen> createState() =>
      _RegionSelectionScreenState();
}

class _RegionSelectionScreenState extends ConsumerState<RegionSelectionScreen> {
  RegionCode? _selectedRegion;
  RegionCode? _currentRegion;
  bool _isSaving = false;
  String _searchQuery = '';
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    // Load current region after build
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCurrentRegion());
  }

  void _loadCurrentRegion() {
    if (_initialized) return;
    final protocol = ref.read(protocolServiceProvider);
    final region = protocol.currentRegion;
    if (region != null && region != RegionCode.UNSET_REGION) {
      setState(() {
        _currentRegion = region;
        // Pre-select current region when editing (not initial setup)
        if (!widget.isInitialSetup) {
          _selectedRegion = region;
        }
        _initialized = true;
      });
    }
  }

  List<RegionInfo> get _filteredRegions {
    if (_searchQuery.isEmpty) return availableRegions;
    final query = _searchQuery.toLowerCase();
    return availableRegions.where((r) {
      return r.name.toLowerCase().contains(query) ||
          r.description.toLowerCase().contains(query) ||
          r.frequency.toLowerCase().contains(query);
    }).toList();
  }

  Future<void> _saveRegion() async {
    if (_selectedRegion == null) return;

    setState(() => _isSaving = true);

    try {
      final protocol = ref.read(protocolServiceProvider);
      await protocol.setRegion(_selectedRegion!);

      if (mounted) {
        if (widget.isInitialSetup) {
          // Navigate to main app after initial setup
          Navigator.of(context).pushReplacementNamed('/main');
        } else {
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to set region: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        leading: widget.isInitialSetup
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
        title: Text(
          widget.isInitialSetup ? 'Select Your Region' : 'Change Region',
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            
          ),
        ),
      ),
      body: Column(
        children: [
          if (widget.isInitialSetup)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: context.accentColor.withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: context.accentColor,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Important: Select Your Region',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Choose the correct frequency for your location to comply with local regulations.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.8),
                              fontSize: 12,
                              
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.darkCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.darkBorder),
              ),
              child: TextField(
                style: const TextStyle(
                  color: Colors.white,
                  
                ),
                decoration: InputDecoration(
                  hintText: 'Search regions...',
                  hintStyle: const TextStyle(
                    color: AppTheme.textTertiary,
                    
                  ),
                  prefixIcon: const Icon(
                    Icons.search,
                    color: AppTheme.textTertiary,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Region list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _filteredRegions.length,
              itemBuilder: (context, index) {
                final region = _filteredRegions[index];
                final isSelected = _selectedRegion == region.code;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? context.accentColor.withValues(alpha: 0.15)
                        : AppTheme.darkCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? context.accentColor
                          : AppTheme.darkBorder,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () =>
                          setState(() => _selectedRegion = region.code),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? context.accentColor.withValues(
                                        alpha: 0.2,
                                      )
                                    : AppTheme.darkBackground,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Center(
                                child: Icon(
                                  Icons.cell_tower,
                                  color: isSelected
                                      ? context.accentColor
                                      : AppTheme.textTertiary,
                                  size: 24,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    region.name,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: isSelected
                                          ? Colors.white
                                          : AppTheme.textSecondary,
                                      
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    region.description,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textTertiary,
                                      
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? context.accentColor
                                    : AppTheme.darkBackground,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                region.frequency,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? Colors.white
                                      : AppTheme.textTertiary,
                                  
                                ),
                              ),
                            ),
                            // Show "Current" badge for the device's current region
                            if (_currentRegion == region.code &&
                                !isSelected) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.graphBlue.withValues(
                                    alpha: 0.2,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: const Text(
                                  'CURRENT',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.graphBlue,
                                    
                                  ),
                                ),
                              ),
                            ],
                            if (isSelected) ...[
                              SizedBox(width: 12),
                              Icon(
                                Icons.check_circle,
                                color: context.accentColor,
                                size: 24,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // Save button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _selectedRegion != null && !_isSaving
                      ? _saveRegion
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: context.accentColor,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: AppTheme.darkCard,
                    disabledForegroundColor: AppTheme.textTertiary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Text(
                          widget.isInitialSetup ? 'Continue' : 'Save',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            
                          ),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
