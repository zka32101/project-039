// 太陽位置（方位角・高度角）の簡易計算（suncalc相当のロジックを自前実装）。
// アルゴリズム: NOAA Solar Position Calculator の簡易版（分単位の精度で十分）。
import { toRad, toDeg } from './geo.js';

const RAD = Math.PI / 180;

/**
 * @param {Date} date UTC日時
 * @param {number} lat 緯度
 * @param {number} lon 経度
 * @returns {{azimuthDeg:number, altitudeDeg:number}} 方位角(北=0, 東回り), 高度角(地平線=0, 天頂=90)
 */
export function getSunPosition(date, lat, lon) {
  const dayMs = 1000 * 60 * 60 * 24;
  const J1970 = 2440588;
  const J2000 = 2451545;

  const toJulian = (d) => d.valueOf() / dayMs - 0.5 + J1970;
  const toDays = (d) => toJulian(d) - J2000;

  const d = toDays(date);

  const M = RAD * (357.5291 + 0.98560028 * d); // 平均近点角
  const C = RAD * (1.9148 * Math.sin(M) + 0.02 * Math.sin(2 * M) + 0.0003 * Math.sin(3 * M));
  const P = RAD * 102.9372; // 近日点黄経
  const L = M + C + P + Math.PI; // 太陽黄経
  const e = RAD * 23.4397; // 地軸傾斜角

  const dec = Math.asin(Math.sin(e) * Math.sin(L)); // 赤緯
  const ra = Math.atan2(Math.sin(L) * Math.cos(e), Math.cos(L)); // 赤経

  const lw = RAD * -lon;
  const phi = RAD * lat;
  const theta = RAD * (280.16 + 360.9856235 * d) - lw; // 恒星時
  const H = theta - ra; // 時角

  const altitude = Math.asin(
    Math.sin(phi) * Math.sin(dec) + Math.cos(phi) * Math.cos(dec) * Math.cos(H),
  );
  const azimuth = Math.atan2(
    Math.sin(H),
    Math.cos(H) * Math.sin(phi) - Math.tan(dec) * Math.cos(phi),
  );

  // azimuth: 南=0のライブラリ由来定義を、北=0・東回り(コンパス方位)に変換
  const azimuthCompassDeg = (toDeg(azimuth) + 180) % 360;

  return { azimuthDeg: azimuthCompassDeg, altitudeDeg: toDeg(altitude) };
}
