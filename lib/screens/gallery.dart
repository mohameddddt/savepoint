import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../theme.dart';
import '../widgets/common.dart';

class Gallery extends StatefulWidget {
  const Gallery({super.key, required this.images, this.initial = 0});
  final List<String> images;
  final int initial;
  @override
  State<Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<Gallery> {
  late final pc = PageController(initialPage: widget.initial);
  late int i = widget.initial;

  @override
  void dispose() {
    pc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: pc,
            itemCount: widget.images.length,
            onPageChanged: (v) => setState(() => i = v),
            itemBuilder: (_, k) => InteractiveViewer(
              maxScale: 4,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: img(widget.images[k], 't_1080p')!,
                  fit: BoxFit.contain,
                  memCacheWidth: (mq.size.width * mq.devicePixelRatio * 1.5).round(),
                  placeholder: (_, _) => CachedNetworkImage(imageUrl: img(widget.images[k], 't_screenshot_med')!, fit: BoxFit.contain),
                ),
              ),
            ),
          ),
          Positioned(
            top: mq.padding.top + 8,
            left: 12,
            right: 16,
            child: Row(
              children: [
                CircleBtn(Icons.close_rounded, bg: Colors.black54, onTap: () => Navigator.pop(context)),
                const Spacer(),
                Text('${i + 1} / ${widget.images.length}', style: T.label.copyWith(color: C.text)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
