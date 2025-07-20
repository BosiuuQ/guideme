// lib/features/profile/level_service.dart

class LevelService {
  static const Map<int, int> levelThresholds = {
    1: 0,
    2: 5,
    3: 25,
    4: 60,
    5: 140,
    6: 200,
    7: 270,
    8: 350,
    9: 440,
    10: 540,
    11: 650,
    12: 770,
    13: 900,
    14: 1040,
    15: 1190,
    16: 1350,
    17: 1520,
    18: 1700,
    19: 1890,
    20: 2090,
    21: 2300,
    22: 2520,
    23: 2750,
    24: 2990,
    25: 3240,
    26: 3500,
    27: 3770,
    28: 4050,
    29: 4340,
    30: 4640,
    31: 4950,
    32: 5270,
    33: 5600,
    34: 5940,
    35: 6290,
    36: 6650,
    37: 7020,
    38: 7400,
    39: 7790,
    40: 8190,
    41: 8600,
    42: 9020,
    43: 9450,
    44: 9890,
    45: 10340,
    46: 10800,
    47: 11270,
    48: 11750,
    49: 12240,
    50: 12740,
    51: 13250,
    52: 13770,
    53: 14300,
    54: 14840,
    55: 15390,
    56: 15950,
    57: 16520,
    58: 17100,
    59: 17690,
    60: 18290,
    61: 18900,
    62: 19520,
    63: 20150,
    64: 20790,
    65: 21440,
    66: 22100,
    67: 22770,
    68: 23450,
    69: 24140,
    70: 24840,
    71: 25550,
    72: 26270,
    73: 27000,
    74: 27740,
    75: 28490,
    76: 29250,
    77: 30020,
    78: 30800,
    79: 31590,
    80: 32390,
    81: 33200,
    82: 34020,
    83: 34850,
    84: 35690,
    85: 36540,
    86: 37400,
    87: 38270,
    88: 39150,
    89: 40040,
    90: 40940,
    91: 41850,
    92: 42770,
    93: 43700,
    94: 44640,
    95: 45590,
    96: 46550,
    97: 47520,
    98: 48500,
    99: 49490,
    100: 30000,
  };

  /// Zwraca procentowy progres w kierunku następnego poziomu
  static double getProgress(int currentLevel, double currentKm) {
    final currentThreshold = levelThresholds[currentLevel] ?? 0;
    final nextThreshold = levelThresholds[currentLevel + 1] ?? currentKm;

    final progress = ((currentKm - currentThreshold) / (nextThreshold - currentThreshold)).clamp(0.0, 1.0);
    return progress;
  }

  /// Zwraca poziom użytkownika na podstawie liczby km
  static int getLevelFromKm(double totalKm) {
    for (var entry in levelThresholds.entries.toList().reversed) {
      if (totalKm >= entry.value) {
        return entry.key;
      }
    }
    return 1;
  }
}
