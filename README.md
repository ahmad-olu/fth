#FTH

## 🧩 Flutter Widget Converter CLI [HTML,TSX,LUSTER,JASPER]

**Flutter Widget Converter** is a powerful command-line tool that converts Flutter widget trees into other formats such as **HTML**, with future support for **JSX**, **Luster**, and **Jasper** templates.

This tool is built for developers who want to reuse Flutter UI definitions across multiple platforms or frameworks — without rewriting everything from scratch.

---

## 🚀 Features

- 🔍 Parse Flutter widget trees directly from Dart source files
- 🧱 Output clean, structured **HTML**
- 🪄 Auto-detect widget properties (e.g., `Text("hello") → <p>hello</p>`)
- 🌲 Analyze nested widget hierarchies
- 🧭 CLI support for analyzing whole directories or single files
- ⚙️ Extensible architecture for custom output formats (JSX, Luster, Jasper coming soon)

---

## 🧰 Installation

Clone the repository and build the executable:

```bash
git clone https://github.com/ahmad-olu/fth.git
cd fth
dart pub get
dart compile exe bin/fth.dart -o fth
