import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../../services/api_service.dart';

class PostVideoPlayer extends StatefulWidget {
  final String videoUrl;
  const PostVideoPlayer({super.key, required this.videoUrl});

  @override
  State<PostVideoPlayer> createState() => _PostVideoPlayerState();
}

class _PostVideoPlayerState extends State<PostVideoPlayer> with SingleTickerProviderStateMixin {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isVisible = false;
  bool _showControls = false;
  late AnimationController _iconAnimController;
  late Animation<double> _iconAnimation;

  @override
  void initState() {
    super.initState();
    _iconAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _iconAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _iconAnimController, curve: Curves.easeOut),
    );
    _initializeController();
  }

  Future<void> _initializeController() async {
    _controller = VideoPlayerController.networkUrl(Uri.parse(ApiService.getMediaUrl(widget.videoUrl)!));
    try {
      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
        _controller!.setLooping(true);
        _controller!.addListener(_onVideoProgress);
        if (_isVisible) {
          _controller!.play();
        }
      }
    } catch (e) {
      debugPrint("Error initializing video: $e");
    }
  }

  void _onVideoProgress() {
    if (mounted) setState(() {});
  }

  void _togglePlayPause() {
    if (!_isInitialized || _controller == null) return;
    setState(() {
      if (_controller!.value.isPlaying) {
        _controller!.pause();
        _showControls = true;
      } else {
        _controller!.play();
        _showControls = true;
        // Fade out the play icon after a short delay
        _iconAnimController.forward(from: 0.0);
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted && _controller!.value.isPlaying) {
            setState(() => _showControls = false);
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _controller?.removeListener(_onVideoProgress);
    _controller?.dispose();
    _iconAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key(widget.videoUrl),
      onVisibilityChanged: (visibilityInfo) {
        final visiblePercentage = visibilityInfo.visibleFraction * 100;
        if (visiblePercentage > 50) {
          if (!_isVisible) {
            _isVisible = true;
            if (_isInitialized) _controller?.play();
          }
        } else {
          if (_isVisible) {
            _isVisible = false;
            if (_isInitialized) _controller?.pause();
          }
        }
      },
      child: GestureDetector(
        onTap: _togglePlayPause,
        child: Container(
          color: Colors.black,
          child: !_isInitialized
              ? const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Stack(
                  children: [
                    // Fill the screen — crop to cover
                    SizedBox.expand(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _controller!.value.size.width,
                          height: _controller!.value.size.height,
                          child: VideoPlayer(_controller!),
                        ),
                      ),
                    ),

                    // Animated play/pause icon overlay
                    if (_showControls || !_controller!.value.isPlaying)
                      Center(
                        child: _controller!.value.isPlaying
                            ? FadeTransition(
                                opacity: _iconAnimation,
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withAlpha(80),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.play_arrow_rounded, size: 64, color: Colors.white),
                                ),
                              )
                            : Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.black.withAlpha(80),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.pause_rounded, size: 64, color: Colors.white),
                              ),
                      ),

                    // Thin progress bar at the bottom
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: VideoProgressIndicator(
                        _controller!,
                        allowScrubbing: true,
                        colors: const VideoProgressColors(
                          playedColor: Colors.white,
                          bufferedColor: Colors.white24,
                          backgroundColor: Colors.white10,
                        ),
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
