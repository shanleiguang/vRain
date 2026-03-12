# vRain - Chinese Ancient eBook Generator

[![Star](https://img.shields.io/github/stars/shanleiguang/vRain)](https://github.com/shanleiguang/vRain)
[![License](https://img.shields.io/github/license/shanleiguang/vRain)](https://github.com/shanleiguang/vRain)

**Create vertical-layout eBooks in traditional Chinese woodblock print style**

[中文](README.md) | [English](README_en.md)

---

## About

vRain is a Perl-based tool for creating vertical-layout eBooks that replicate the aesthetic of traditional Chinese woodblock-printed books.

The tool generates book page backgrounds, calculates character positions (right-to-left, top-to-bottom), and places text character by character onto the pages — just like traditional woodblock printing.

![Sample](https://github.com/shanleiguang/vRain/blob/main/images/010.png)

## Features

- 📚 Authentic ancient Chinese book aesthetics
- ✨ Annotations support (dual-column small text)
- 🎨 Fully customizable: fonts, colors, layouts, page styles
- 📜 Multiple background styles: aged paper (宣紙), bamboo scroll (竹簡), fish tail (魚尾)
- 🔤 Multi-font fallback for rare characters
- 📖 PDF output suitable for e-readers
- ⚡ Generate million-character books in minutes

## Quick Start

### Prerequisites

```bash
# Install Perl modules
CPAN - Image::Magick, PDF::Builder, etc
```

### Usage

```bash
# Generate a book (specify book ID from books/ directory)
perl vRain.pl -b 01 -f 1 -t 10 -c

# Test mode - generate first 10 pages only
perl vRain.pl -b 01 -f 1 -t 10 -z 10 -c

```

### Options

| Option | Description               |
|--------|---------------------------|
| `-h`   | Show help                 |
| `-v`   | Verbose output            |
| `-b`   | Book ID (required)        |
| `-f`   | Start text index          |
| `-t`   | End text index            |
| `-z`   | Test mode (limited pages) |
| `-c`   | Compress PDF              |

## Example Output

![001](https://github.com/shanleiguang/vRain/blob/main/images/001.png?raw=true) 
![002](https://github.com/shanleiguang/vRain/blob/main/images/002.png?raw=true) 
![003](https://github.com/shanleiguang/vRain/blob/main/images/003.png?raw=true)
![004](https://github.com/shanleiguang/vRain/blob/main/images/004.png?raw=true)
![010](https://github.com/shanleiguang/vRain/blob/main/images/010.png?raw=true)
![014](https://github.com/shanleiguang/vRain/blob/main/images/014.png?raw=true)

More examples: [vBooks Gallery](https://github.com/shanleiguang/vBooks)

## Documentation

- [Runtime Environment](https://github.com/shanleiguang/vRain/wiki/Runtime)
- [User Manual](https://github.com/shanleiguang/vRain/wiki)
- [Sample Gallery](https://github.com/shanleiguang/vBooks)

## Related Projects

- [vYinn](https://github.com/shanleiguang/vYinn) - Ancient Chinese seal generator
- [vQi](https://github.com/shanleiguang/vQi) - Go SGF to ancient style images
- [vModou](https://github.com/shanleiguang/vModou) - Ancient book scan correction
- [vRain-Python](https://github.com/msyloveldx/vRain-Python) - GUI version (Python)

## License

MIT License

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=shanleiguang/vRain)](https://star-history.com/#shanleiguang/vRain)
