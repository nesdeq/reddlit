import 'package:material_ui/material_ui.dart';
import '../theme/app_theme.dart';
import '../constants/app_constants.dart';
import 'content_widgets.dart';

/// Swipeable post gallery with page arrows and a page counter.
class GalleryViewer extends StatefulWidget {
  final List<String> images;

  /// Feed cards use the fixed feed aspect ratio; the detail view uses flexible height.
  final bool constrainAspectRatio;

  const GalleryViewer({
    super.key,
    required this.images,
    this.constrainAspectRatio = true,
  });

  @override
  State<GalleryViewer> createState() => _GalleryViewerState();
}

class _GalleryViewerState extends State<GalleryViewer> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < widget.images.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.images.isEmpty) {
      return const SizedBox.shrink();
    }

    if (widget.images.length == 1) {
      return _wrapWithAspectRatio(
        ClipRRect(
          borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
          child: _buildImage(widget.images[0]),
        ),
      );
    }

    return _wrapWithAspectRatio(
      ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: widget.images.length,
              onPageChanged: (index) {
                setState(() {
                  _currentPage = index;
                });
              },
              itemBuilder: (context, index) {
                return _buildImage(widget.images[index]);
              },
            ),
            if (_currentPage > 0)
              _navArrow(
                left: AppTheme.spacing2,
                icon: Icons.chevron_left_rounded,
                onTap: _previousPage,
              ),
            if (_currentPage < widget.images.length - 1)
              _navArrow(
                right: AppTheme.spacing2,
                icon: Icons.chevron_right_rounded,
                onTap: _nextPage,
              ),
            Positioned(
              top: AppTheme.spacing3,
              right: AppTheme.spacing3,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spacing2,
                  vertical: AppTheme.spacing1,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: AppConstants.galleryIndicatorOpacity),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                ),
                child: Text(
                  '${_currentPage + 1}/${widget.images.length}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _navArrow({
    double? left,
    double? right,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Positioned(
      left: left,
      right: right,
      top: 0,
      bottom: 0,
      child: Center(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(AppTheme.spacing2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(
                alpha: AppConstants.overlayOpacity,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 32),
          ),
        ),
      ),
    );
  }

  Widget _wrapWithAspectRatio(Widget child) {
    if (widget.constrainAspectRatio) {
      return AspectRatio(
        aspectRatio: AppConstants.feedMediaAspectRatio,
        child: child,
      );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: AppConstants.detailMediaMinHeight,
        maxHeight: AppConstants.detailMediaMaxHeight,
      ),
      child: child,
    );
  }

  Widget _buildImage(String url) {
    // Cover fills the rounded corners cleanly.
    return InteractiveViewer(
      minScale: 1.0,
      maxScale: 4.0,
      clipBehavior: Clip.hardEdge,
      child: ContentWidgets.cachedImage(
        context: context,
        imageUrl: url,
        fit: BoxFit.cover,
      ),
    );
  }
}
