import 'dart:async';

import 'package:flutter/painting.dart';

/// An image that always fails to load, like a dead link or an offline device.
class FailingImageProvider extends ImageProvider<FailingImageProvider> {
  const FailingImageProvider();

  @override
  Future<FailingImageProvider> obtainKey(ImageConfiguration configuration) =>
      Future.value(this);

  @override
  ImageStreamCompleter loadImage(
    FailingImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(
      Future<ImageInfo>.error(Exception('image could not be loaded')),
    );
  }
}

/// An image that is still loading and never finishes.
class PendingImageProvider extends ImageProvider<PendingImageProvider> {
  const PendingImageProvider();

  @override
  Future<PendingImageProvider> obtainKey(ImageConfiguration configuration) =>
      Future.value(this);

  @override
  ImageStreamCompleter loadImage(
    PendingImageProvider key,
    ImageDecoderCallback decode,
  ) {
    return OneFrameImageStreamCompleter(Completer<ImageInfo>().future);
  }
}
