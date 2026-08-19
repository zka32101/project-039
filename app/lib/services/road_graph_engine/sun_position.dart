import 'dart:math' as math;
import 'geo.dart';

/// prototype/src/sunPosition.js のDart移植。NOAA簡易アルゴリズムによる太陽位置計算。
class SunPosition {
  const SunPosition({required this.azimuthDeg, required this.altitudeDeg});

  final double azimuthDeg;
  final double altitudeDeg;
}

const double _rad = math.pi / 180;

SunPosition getSunPosition(DateTime utcDate, double lat, double lon) {
  const dayMs = 1000 * 60 * 60 * 24;
  const j1970 = 2440588;
  const j2000 = 2451545;

  final julian = utcDate.millisecondsSinceEpoch / dayMs - 0.5 + j1970;
  final d = julian - j2000;

  final m = _rad * (357.5291 + 0.98560028 * d);
  final c = _rad *
      (1.9148 * math.sin(m) + 0.02 * math.sin(2 * m) + 0.0003 * math.sin(3 * m));
  const p = _rad * 102.9372;
  final l = m + c + p + math.pi;
  const e = _rad * 23.4397;

  final dec = math.asin(math.sin(e) * math.sin(l));
  final ra = math.atan2(math.sin(l) * math.cos(e), math.cos(l));

  final lw = _rad * -lon;
  final phi = _rad * lat;
  final theta = _rad * (280.16 + 360.9856235 * d) - lw;
  final h = theta - ra;

  final altitude = math.asin(
    math.sin(phi) * math.sin(dec) + math.cos(phi) * math.cos(dec) * math.cos(h),
  );
  final azimuth = math.atan2(
    math.sin(h),
    math.cos(h) * math.sin(phi) - math.tan(dec) * math.cos(phi),
  );

  final azimuthCompassDeg = (toDeg(azimuth) + 180) % 360;

  return SunPosition(azimuthDeg: azimuthCompassDeg, altitudeDeg: toDeg(altitude));
}
