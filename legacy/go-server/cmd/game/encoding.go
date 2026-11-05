package main

import (
	"math"
	"strconv"
	"strings"
)

// Explicit q=0 overrides a wildcard, so clients never receive a refused encoding.
func encodingQuality(header, name string) float64 {
	wildcard := float64(0)
	for _, item := range strings.Split(header, ",") {
		parts := strings.Split(strings.TrimSpace(item), ";")
		token := strings.ToLower(strings.TrimSpace(parts[0]))
		q := float64(1)
		for _, parameter := range parts[1:] {
			parameter = strings.TrimSpace(parameter)
			if strings.HasPrefix(parameter, "q=") {
				value, err := strconv.ParseFloat(strings.TrimPrefix(parameter, "q="), 64)
				if err != nil || math.IsNaN(value) || value < 0 || value > 1 {
					q = 0
				} else {
					q = value
				}
			}
		}
		if token == name {
			return q
		}
		if token == "*" {
			wildcard = q
		}
	}
	return wildcard
}
