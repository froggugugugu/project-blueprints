# Ratio Reference Table

## Major Scale Ratios

| Ratio Name | Value | Alias |
|------------|-------|-------|
| Minor Second | 1.067 | Semitone |
| Major Second | 1.125 | Whole tone |
| Minor Third | 1.200 | — |
| **Major Third** | **1.250** | **Recommended for business UIs** |
| Perfect Fourth | 1.333 | — |
| Augmented Fourth | 1.414 | **Silver Ratio** |
| Perfect Fifth | 1.500 | — |
| Minor Sixth | 1.600 | — |
| **Golden Ratio** | **1.618** | **Golden Ratio** |
| Major Sixth | 1.667 | — |
| Minor Seventh | 1.778 | — |
| Major Seventh | 1.875 | — |
| Octave | 2.000 | — |

---

## Scale Expansion Table (base=14px)

| Step | ×1.250 | ×1.333 | ×1.414 (Silver) | ×1.618 (Golden) |
|------|--------|--------|-----------------|-----------------|
| base÷4 |  4px |  4px |  4px | 3px |
| base÷2 |  7px |  7px |  7px | 5px |
| base | 14px | 14px | 14px | 14px |
| ×1 | 18px | 19px | 20px | 23px |
| ×2 | 22px | 25px | 28px | 37px |
| ×3 | 27px | 33px | 40px | 60px |
| ×4 | 34px | 44px | 56px | 97px |

---

## Spacing Expansion Table (base=8px)

| Step | ×1.250 | ×1.333 | ×1.414 (Silver) | ×1.618 (Golden) |
|------|--------|--------|-----------------|-----------------|
| base÷2 |  4px |  4px |  4px | 5px |
| base |  8px |  8px |  8px | 8px |
| ×1 | 10px | 11px | 11px | 13px |
| ×2 | 13px | 14px | 16px | 21px |
| ×3 | 16px | 19px | 23px | 34px |
| ×4 | 20px | 25px | 32px | 55px |
| ×5 | 25px | 33px | 45px | 89px |

---

## Golden Ratio Properties

- φ = (1 + √5) / 2 ≈ **1.618**
- Property: `φ² = φ + 1` → self-similarity
- A rectangle where the ratio of long to short sides equals φ is a "golden rectangle"
- Creates a natural rhythm in margin-to-margin ratios and font size steps

## Silver Ratio Properties

- √2 ≈ **1.414**
- Aspect ratio of paper sizes like A4 and B5
- Strong affinity with Japanese traditional aesthetics
- Smaller steps mean less visual pressure even in high-density UIs

---

## Practical Tips

1. **Don't apply ratios too strictly**: When calculated values are awkward (e.g., 13.1px), round to the nearest integer
2. **Combine with 8px grid**: Snap ratio-scaled values to the nearest multiple of 8 for easier implementation
3. **Document exceptions**: When using off-token values, leave a comment explaining why
4. **Vary base size by screen size**: Change the base value like mobile base=14px / desktop base=16px while maintaining the same ratio
