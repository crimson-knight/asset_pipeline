# Browser Noise compositing references

`noise.svg` and each HTML page reproduce the web Noise overlay: the SVG 1.1
`fractalNoise` filter keeps all four generated channels, and a CSS layer applies
`opacity: 0.07` over a flat panel.

There are two filter color spaces:

- `noise.svg` (`light.html`, `dark.html`) sets
  `color-interpolation-filters="sRGB"`. The native spec renders it with
  `UI::ColorInterpolationFilters::SRGB`.
- `noise-linear-rgb.svg` (`light-linear-rgb.html`, `dark-linear-rgb.html`) is
  identical except that it leaves the attribute unset, so the filter uses the
  SVG default, `linearRGB`. The native spec renders it with the
  `UI::TextureOverlay` default, `UI::ColorInterpolationFilters::LinearRGB`. The viewport is 128 CSS pixels square at a
device scale factor of 2, yielding a 256 by 256 PNG like the native 128-point
tile on a 2x display.

Capture the references from the repository root with the headless Chrome
DevTools probe:

```sh
CHROME_BIN='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' crystal-alpha run scripts/cdp_probes/screenshot_probe.cr -- --page spec/native_macos/fixtures/noise-composite/light.html --width 128 --height 128 --scale 2 --out spec/native_macos/fixtures/noise-composite/light-reference.png
CHROME_BIN='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' crystal-alpha run scripts/cdp_probes/screenshot_probe.cr -- --page spec/native_macos/fixtures/noise-composite/dark.html --width 128 --height 128 --scale 2 --out spec/native_macos/fixtures/noise-composite/dark-reference.png
CHROME_BIN='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' crystal-alpha run scripts/cdp_probes/screenshot_probe.cr -- --page spec/native_macos/fixtures/noise-composite/light-linear-rgb.html --width 128 --height 128 --scale 2 --out spec/native_macos/fixtures/noise-composite/light-linear-rgb-reference.png
CHROME_BIN='/Applications/Google Chrome.app/Contents/MacOS/Google Chrome' crystal-alpha run scripts/cdp_probes/screenshot_probe.cr -- --page spec/native_macos/fixtures/noise-composite/dark-linear-rgb.html --width 128 --height 128 --scale 2 --out spec/native_macos/fixtures/noise-composite/dark-linear-rgb-reference.png
```

Renderer: Google Chrome `153.0.8010.53`, executable SHA-256
`af09314952c541583cc380057318e0a812a2dd1d7627327d564fc2e991736345`.
Capture command tool: `crystal-alpha` / Crystal `1.21.0`, executable SHA-256
`9d290608fb7b4e36d8e468d526a45d46bb7a7744ea30cce38408232c3df48ba3`.

PNG SHA-256 values:

- `light-reference.png`: `6f4d83c6851f98b97fc306aed9dac787d4158a9630f6a4abb02f63ee0187a2f0`
- `dark-reference.png`: `285bf58fe50b6efda255086c38fca22693dd795d59c56523c6365e1587b85703`
- `light-linear-rgb-reference.png`: `ada4f44b1a4887b74209476074a14648726f4dc8177c11ad6746a013dd6b6c0d`
- `dark-linear-rgb-reference.png`: `deb127d0725fc29bbe467776b26f6cd6d16f2a0dbb7f4dacc3649e843ba909c0`

Each capture was repeated and reproduced these hashes byte for byte.

Luma is computed from the screenshot's 8-bit sRGB channels as
`0.2126 R + 0.7152 G + 0.0722 B`. Before the fix, the native tile used the red
channel as opaque grayscale. The native results were:

| Fill | Native before mean | Browser mean | Native before standard deviation | Browser standard deviation |
| --- | ---: | ---: | ---: | ---: |
| `#FBF8F2` | 239.2771 | 243.6989 | 2.1507 | 1.4821 |
| `#2B3245` | 55.0243 | 52.3550 | 2.1507 | 1.1278 |

After keeping the SVG filter's independent RGBA channels and premultiplying RGB
by generated alpha, the native results are:

| Fill | Native after mean | Browser mean | Native after standard deviation | Browser standard deviation |
| --- | ---: | ---: | ---: | ---: |
| `#FBF8F2` | 243.7340 | 243.6989 | 1.4373 | 1.4821 |
| `#2B3245` | 52.5812 | 52.3550 | 1.0893 | 1.1278 |

The specs allow a mean difference of 1 level for 8-bit compositor rounding and
a standard-deviation difference of `0.15` to guard the grain strength. Before
the fix, the extra effective opacity from treating turbulence alpha as opaque
made light fills too dark and roughly doubled grain variation. The texture
layer's `0.07` opacity was already applied once; preserving and compositing the
generated SVG alpha corrected the result.

## linearRGB references

The tables above are the sRGB references. For the linearRGB references, the
native tile treats each generated color channel as linear light and encodes it
with the sRGB transfer function (`12.92 c` up to `0.0031308`, else
`1.055 c^(1/2.4) - 0.055`) before premultiplying by the generated alpha, which
is left as generated. Chrome does the same when it converts a linearRGB filter
result to sRGB. Mid-gray turbulence (`0.5`) encodes to about `0.735`, so the
grain darkens light fills less and lightens dark fills more.

Before the change, the native tile stored the generated values as sRGB for
every texture, so the default texture missed the linearRGB references (the
spec failed at the light case's mean, `2.1433` levels apart):

| Fill | Native before mean | Browser mean | Native before standard deviation | Browser standard deviation |
| --- | ---: | ---: | ---: | ---: |
| `#FBF8F2` | 243.7340 | 245.8772 | 1.4373 | 0.9153 |
| `#2B3245` | 52.5812 | 54.5270 | 1.0893 | 1.3958 |

After the change, with the default `LinearRGB`:

| Fill | Native after mean | Browser mean | Native after standard deviation | Browser standard deviation |
| --- | ---: | ---: | ---: | ---: |
| `#FBF8F2` | 245.7946 | 245.8772 | 0.9013 | 0.9153 |
| `#2B3245` | 54.6418 | 54.5270 | 1.3283 | 1.3958 |

The sRGB spec, now with an explicit `SRGB`, still measures the sRGB "Native
after" values above (`243.7340` / `1.4373` and `52.5812` / `1.0893`). Both specs
use the same bounds: 1 level of mean and `0.15` of standard deviation.
