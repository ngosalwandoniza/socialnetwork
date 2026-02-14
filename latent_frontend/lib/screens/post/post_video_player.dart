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

class _PostVideoPlayerState extends State<PostVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _isVisible = false;

  @override
  void initState() {
    super.initState();
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
        if (_isVisible) {
          _controller!.play();
        }
      }
    } catch (e) {
      debugPrint("Error initializing video: $e");
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
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
        onTap: () {
          if (_isInitialized) {
            setState(() {
              _controller!.value.isPlaying ? _controller!.pause() : _controller!.play();
            });
          }
        },
        child: Container(
          color: Colors.black,
          child: !_isInitialized
              ? const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : Stack(
                  alignment: Alignment.center,
                  children: [
                    AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: VideoPlayer(_controller!),
                    ),
                    if (_isInitialized && !_controller!.value.isPlaying)
                      Icon(
                        Icons.play_arrow,
                        size: 80,
                        color: Colors.white.withAlpha(127),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
