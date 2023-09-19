---
title: "Note: CAJ to PDF"
date: 2023-07-05
permalink: note-caj-to-pdf
---

Just a simply note that shows how to convert CAJ files to PDF files (not guranteed that).

# 安装 mupdf (待会儿需要 mutool)
```bash
wget https://mupdf.com/downloads/archive/mupdf-1.22.2-source.tar.gz
tar xf mupdf-1.22.2-source.tar.gz
cd mupdf-1.22.2-source
sudo apt install libglu1-mesa-dev freeglut3-dev libx11-dev libxi-dev libxrandr-dev
make -j`nproc`
sudo make install
cd ..
```

# 安装 python 依赖
```bash
pip3 install -U pypdf2
```

# 下载 caj2pdf
```bash
git clone https://github.com/caj2pdf/caj2pdf
cd caj2pdf
./caj2pdf convert ./filename.caj -o output.pdf
```
