class_name ImpactProfiles
extends RefCounted

const SURFACES := {
	"concrete": {
		"hole": 0.070, "cavity": Color(0.024, 0.024, 0.022), "lip": Color(0.38, 0.37, 0.34), "exit_scale": 1.25,
		"sound": "impact_concrete", "volume": 0.0,
		"dust": {"amount": 9, "color": Color(0.56, 0.55, 0.52, 0.60), "vel": [0.4, 1.6], "gravity": -2.0, "scale": [0.6, 2.4], "life": 0.85, "size": 0.050, "spread": 62.0},
		"debris": {"amount": 6, "color": Color(0.34, 0.33, 0.31, 0.95), "vel": [2.6, 6.5], "gravity": -13.0, "scale": [0.18, 0.50], "life": 0.50, "size": 0.018, "spread": 70.0},
	},
	"gypsum": {
		"hole": 0.064, "cavity": Color(0.085, 0.080, 0.072), "lip": Color(0.74, 0.71, 0.65), "exit_scale": 1.80,
		"sound": "impact_drywall", "volume": -5.0,
		"dust": {"amount": 18, "color": Color(0.78, 0.76, 0.71, 0.52), "vel": [0.5, 2.0], "gravity": -1.4, "scale": [1.0, 3.6], "life": 1.05, "size": 0.070, "spread": 74.0},
		"debris": {"amount": 4, "color": Color(0.72, 0.70, 0.64, 0.90), "vel": [1.8, 4.4], "gravity": -8.0, "scale": [0.30, 0.80], "life": 0.60, "size": 0.026, "spread": 66.0},
	},
	"pine": {
		"hole": 0.064, "cavity": Color(0.050, 0.031, 0.015), "lip": Color(0.46, 0.30, 0.14), "exit_scale": 1.50,
		"sound": "impact_wood", "volume": 0.0,
		"dust": {"amount": 7, "color": Color(0.46, 0.33, 0.18, 0.62), "vel": [0.5, 2.0], "gravity": -2.6, "scale": [0.5, 1.8], "life": 0.70, "size": 0.044, "spread": 60.0},
		"debris": {"amount": 8, "color": Color(0.35, 0.22, 0.10, 0.98), "vel": [3.4, 8.0], "gravity": -12.0, "scale": [0.30, 0.85], "life": 0.60, "size": 0.030, "spread": 52.0, "stretch": 4.0},
	},
	"steel": {
		"hole": 0.048, "cavity": Color(0.035, 0.038, 0.045), "lip": Color(0.24, 0.26, 0.30), "exit_scale": 1.10,
		"sound": "impact_metal", "volume": 0.0, "flash": true,
		"debris": {"amount": 22, "color": Color(1.0, 0.72, 0.26, 1.0), "vel": [3.4, 9.0], "gravity": -12.0, "scale": [0.30, 1.20], "life": 0.42, "size": 0.026, "spread": 56.0, "spark": true, "stretch": 5.5},
		"dust": {"amount": 3, "color": Color(0.38, 0.39, 0.42, 0.28), "vel": [0.3, 1.0], "gravity": -2.0, "scale": [0.35, 0.95], "life": 0.34, "size": 0.026, "spread": 48.0},
	},
	"aluminum": {
		"hole": 0.042, "cavity": Color(0.62, 0.63, 0.65), "lip": Color(0.78, 0.79, 0.81), "exit_scale": 1.25,
		"sound": "impact_aluminum", "volume": 0.0, "pitch_min": 0.96, "flash": true,
		"debris": {"amount": 4, "color": Color(1.0, 0.80, 0.40, 1.0), "vel": [2.0, 5.0], "gravity": -11.0, "scale": [0.30, 0.90], "life": 0.22, "size": 0.012, "spread": 50.0, "spark": true},
		"dust": {"amount": 3, "color": Color(0.70, 0.71, 0.72, 0.30), "vel": [0.3, 1.0], "gravity": -2.0, "scale": [0.30, 0.90], "life": 0.30, "size": 0.022, "spread": 44.0},
	},
	"paper": {
		"hole": 0.040, "cavity": Color(0.075, 0.066, 0.055), "lip": Color(0.70, 0.66, 0.56), "exit_scale": 1.60,
		"sound": "impact_wood", "volume": -10.0,
		"dust": {"amount": 4, "color": Color(0.84, 0.81, 0.74, 0.50), "vel": [0.2, 0.8], "gravity": -1.0, "scale": [0.30, 0.90], "life": 0.35, "size": 0.020, "spread": 44.0},
	},
	"ground": {
		"hole": 0.085, "cavity": Color(0.055, 0.046, 0.036), "lip": Color(0.34, 0.29, 0.22), "exit_scale": 1.15,
		"sound": "impact_wood", "volume": -6.0,
		"dust": {"amount": 12, "color": Color(0.44, 0.38, 0.31, 0.62), "vel": [0.3, 1.4], "gravity": -1.8, "scale": [0.9, 3.0], "life": 0.95, "size": 0.058, "spread": 68.0},
		"debris": {"amount": 5, "color": Color(0.30, 0.26, 0.21, 0.95), "vel": [1.6, 4.0], "gravity": -11.0, "scale": [0.20, 0.55], "life": 0.45, "size": 0.020, "spread": 58.0},
	},
}

const SMOKE := {
	"muzzle": {"pool": 8, "amount": 3, "life": 0.9, "burst": 0.45, "vel": Vector2(0.6, 1.3), "spread": 5.0,
		"damp": Vector2(2.5, 4.0), "rise": 0.05, "size": 0.5, "alpha": 0.7},
	"barrel": {"pool": 4, "amount": 1, "life": 1.6, "burst": 0.0, "vel": Vector2(0.04, 0.10), "spread": 12.0,
		"damp": Vector2(0.8, 1.4), "rise": 0.16, "size": 0.24, "alpha": 0.5},
	"ejection": {"pool": 4, "amount": 1, "life": 0.7, "burst": 0.0, "vel": Vector2(0.2, 0.5), "spread": 30.0,
		"damp": Vector2(2.5, 3.5), "rise": 0.16, "size": 0.2, "alpha": 0.45},
}
