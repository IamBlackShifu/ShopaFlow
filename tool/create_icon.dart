import 'dart:io';

// Re-import the image library with a prefix to avoid conflicts
import 'package:image/image.dart' as img;

void main() {
  // Create an image
  final image = img.Image(width: 512, height: 512);

  // Fill it with a solid color (e.g., a nice blue for the background)
  img.fill(image, color: img.ColorRgb8(76, 175, 80)); // Green background

  // Draw the store building
  img.fillRect(image, x1: 100, y1: 250, x2: 412, y2: 450, color: img.ColorRgb8(255, 255, 255));

  // Draw the awning
  img.fillRect(image, x1: 90, y1: 200, x2: 422, y2: 250, color: img.ColorRgb8(255, 87, 34));

   // Draw "S" for ShopaFlow on the building
  img.drawString(
    image,
    'S',
    font: img.arial48,
    x: 230,
    y: 320,
    color: img.ColorRgb8(0, 0, 0),
  );


  // Save the image to a file
  final file = File('assets/icon/icon.png');
  file.writeAsBytesSync(img.encodePng(image));

  print('Icon created at assets/icon/icon.png');
}
