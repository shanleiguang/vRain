
![image](https://github.com/shanleiguang/vRain/blob/main/cover.png)

[**運行環境**](https://github.com/shanleiguang/vRain/wiki/Runtime)  [**使用手冊**](https://github.com/shanleiguang/vRain/wiki)   [**更多樣例**](https://github.com/shanleiguang/vBooks)  [**私庫介紹**](https://github.com/shanleiguang/vRain/wiki/Private)

## 中文古籍数字复刻计划 
## Digital Reproduction Project of Chinese Ancient Books

- 古籍刻本掃描影像通常存在掃描變形、頁面瑕疵、文件巨大等問題，且圖像無法選中其文字從而不能查詢生字生詞，因而不便閱讀。
- 該計劃目的是參照古籍刻本之原貌，復刻出文字版的電子書，支持圈註、查閱，方便存入電子閱讀器隨時閱讀。通過古籍刻本古樸形式所帶來的沉浸優雅之閱讀體驗，也許將吸引更多讀者愛上古籍閱讀。
- Scanned images of ancient books often suffer from issues such as scanning distortion, page defects, and large file sizes, making it difficult to read since the text cannot be selected for searching dictionary.
- The goal of this project is to create ebook in text format that replicates the original appearance of the ancient books, supporting annotations and queries, making it convenient to store in ebook-readers for reading anytime. The elegant and immersive reading experience brought by the primitive form of ancient books may attract more readers to enjoy reading ancient literature.

## vRain is  

- vRain是该復刻計劃的主要工具，此外還有古籍印章製作工具 [vYinn殷人](https://github.com/shanleiguang/vYinn) 、古棋譜製作工具 [vQi](https://github.com/shanleiguang/vQi) 、古籍掃描圖像變形糾正工具[vModou墨斗](https://github.com/shanleiguang/vModouPreview)、農曆日曆製作工具、古籍風格日記本電子書製作工具等等。
- vRain是一款面向讀者的中文古籍刻本風格直排電子書製作工具。
- 參考中文古籍雕版刻本製作過程，首先生成書葉背景圖，根據行數、每行字數形成一個自右向左、自上而下的位置數組，然後把文本逐字打印到對應位置，打滿一頁、新建一頁，直到所有文字處理完。
- 文本編輯準備和自動排版生成分離，使用者將主要精力用在文本編輯準備。
- 一個背景圖對應一個配置文件。一本書對應一個配置文件。
- 百萬字書籍十幾分鐘生成。
- 採用Perl語言開發，需安裝Image::Magick和PDF::Builder等模塊。
- 作者小紅書主頁：兀雨書屋。

## Example

![image](https://github.com/shanleiguang/vBooks/blob/main/002.png)

![image](https://github.com/shanleiguang/vRain/blob/main/images/010.png)

## 基本功能  

- 書葉背景圖的書房名、尺寸、列數、框線粗細及顏色均可配置。支持單雙、順對、黑白魚尾。
- 支持生成宣紙做舊風格、竹簡風格的背景圖。
- 支持批注文字小字雙排。正文、批注文字的字體、大小、顏色、位置可配置。
- 正文文字、批注文字、標點符號的上、下、左、右位置均可微調以達到最佳呈現效果。
- 一主多輔字體，主字體不支持時自動採用輔字體補字。某字符主字體不支持時，可嘗試簡繁轉換以改善支持情況，但可能產生與語境不符問題。
- 標點符號替換規則、過濾規則可配置。標點符號可歸一化為句號，僅用於句讀。常用標點符號可設置為不佔字符位置，頁面文字更緊湊，貼近古籍刻本風格。
- 書名號、單雙引號直排旋轉九十度。書名號可調整為側邊線。
- 根據文本序號自動生成PDF目錄，如第x回、卷x。
- 保留字符：'@'代表空格，'【】'內代表雙排批注文字，'%'代表換葉符，'$'代表換頁符（半葉），'&'代表下行文字居葉末，文本行首'S+數字'代表整段縮幾個字符（需indentxt腳本做預處理）。

## 赞助支持 Sponsorship
 [**私庫介紹**](https://github.com/shanleiguang/vRain/wiki/Private)  
如果您覺得本工具對您的工作或生活有些微幫助，請給予必要的支持，我也有動力繼續完善更新，謝謝！   
贊助後我將邀請您訪問vRainPro私有庫項目，一個月後續訂可通過Sponsor按鈕或該私有項目頁面提示。較Pbulic項目Private項目有以下不同：
>>微信或郵件諮詢答疑，包括運行環境調試、使用協助、代碼解讀、二次開發合作等相關問題；  
>>代碼持續更新，註釋更詳細；  
>>更多古籍排版實用標籤，如正文字體二次縮放、文字添加底框（圓角方框/圓形框）、文本預處理工具等；  
>>更多模擬背景圖，如甲骨、碑拓、竹簡、做舊、手機壁紙等；  
>>更多高質量樣例，如何vRain+vYinn結合應用案例；  
>>**訂購作者自製高質量古籍數字復刻全套成書**；  
![image width=>"600"](https://github.com/shanleiguang/vRain/blob/main/sponsor_new.png)  

## 更新紀錄

- 2025/7，更新至v1.3版本，打包發布Intel Macos版本，版心頁碼改為居中，更新樣書，添加使用說明。
- 2025/3，新增宣纸做旧风格背景图生成脚本；新增竹简风格背景图生成脚本；新增原始文本字符字体支持情况检测及替换脚本；新增批量插图脚本；新增用于整段缩进排版的文本预处理脚本；新增生成PDF压缩代码，压缩比约30倍。
