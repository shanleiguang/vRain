
![image](https://github.com/shanleiguang/vRain/blob/main/cover.png)

[**使用手册**](https://github.com/shanleiguang/vRain/wiki)

# vRain is  

- vRain是一款面向读者的中文古籍刻本风格直排电子书制作工具。
- 参考中文古籍雕版刻本制作过程，首先生成书叶背景图，根据行数、每行字数形成一个自右向左、自上而下的位置数组，然后把文本逐字打印到对应位置，打满一页、新建一页，直到所有文字处理完。
- 文本编辑准备和自动排版生成分离，使用者将主要精力用在文本编辑准备。
- 一个背景图对应一个配置文件。一本书对应一个配置文件。
- 百万字书籍十几分钟生成。
- 采用Perl语言开发，需安装Image::Magick和PDF::Builder等模块。
- 小红书主页：兀雨书屋。

- vRain is a Chinese classical ancient text-style ebook production tool for readers.
- Referencing the production process of Chinese ancient books, it first generates a background image for the pages, and creates a position array that maps from right to left and top to bottom based on the number of lines and characters perline. Then, prints the text character by character to the corresponding positions, filling one page, creating a new page, until all text is processed.
- Text editing preparation is separated from automatic typesetting generation, allowing users to focus mainly on text editing preparation.
- One background image corresponds to one configuration file. One book corresponds to one configuration file.
- Books with millions of characters can be generated in just a few minutes.
- Developed using Perl language, it requires the installation of modules like Image::Magick and PDF::Builder.
- RedNote: 兀雨书屋.

# Example

![image](https://github.com/shanleiguang/vBooks/blob/main/002.png)

![image](https://github.com/shanleiguang/vRain/blob/main/images/010.png)

# 基本功能  

- 書葉背景圖的書房名、尺寸、列數、框線粗細及顏色均可配置。支持單雙、順對、黑白魚尾。
- 支持生成宣紙做舊風格、竹簡風格的背景圖。
- 支持批注文字小字雙排。
- 正文、批注文字的字體、大小、顏色、位置可配置。
- 正文文字、批注文字、標點符號的上、下、左、右位置均可微調以達到最佳呈現效果。
- 一主多輔字體，主字體不支持時自動採用輔字體補字。
- 某字符主字體不支持時，可嘗試簡繁轉換以改善支持情況，但可能產生與語境不符問題。
- 標點符號替換規則、過濾規則可配置。
- 標點符號可歸一化為句號，僅用於句讀。
- 常用標點符號可設置為不佔字符位置，頁面文字更緊湊，貼近古籍刻本風格。
- 書名號、單雙引號直排旋轉九十度。書名號可調整為側邊線。
- 根據文本序號自動生成PDF目錄，如第x回、卷x。
  
# 使用說明  

- 程序能夠實現中英文標點符號、數字替換，但仍建議首先編輯原始文本為中文數字和標點符號。
- 保持文本編碼和字體標準的一致性，如台標繁體文本採用台標繁體字體。
- 保留字符：'@'代表空格，'%'代表強制換頁符，'【】'內代表雙排的批注文字。

# ChangeLog

- 2025/3，新增宣纸做旧风格背景图生成脚本；新增竹简风格背景图生成脚本；新增原始文本字符字体支持情况检测及替换脚本；新增批量插图脚本；新增用于整段缩进排版的文本预处理脚本；新增生成PDF压缩代码，压缩比约30倍。
